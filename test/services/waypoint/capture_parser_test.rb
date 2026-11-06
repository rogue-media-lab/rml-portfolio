require "test_helper"

# The parser reads however a technician actually says a job. The cases below are the
# ones that were actually wrong at some point, kept so they stay right.
module Waypoint
  class CaptureParserTest < ActiveSupport::TestCase
    def parse(text)
      CaptureParser.new(text).call
    end

    # ---- the sentence that started this --------------------------------------

    # Spoken on a phone and refused by the old parser, which required
    # YEAR MAKE MODEL SERVICE to be adjacent. Everything useful was in there.
    test "reads a rambling sentence with the fields out of order" do
      r = parse("2020 GMC Sierra with a 53 L and it's got an oil change all of 60 bucks filters 13 bucks")

      assert_equal "2020 gmc sierra", r[:vehicle][:label]
      assert_equal "oil change", r[:service]
      assert_equal 2020, r[:vehicle][:year]
      assert_equal "gmc", r[:vehicle][:make]
      assert_equal "sierra", r[:vehicle][:model]
    end

    # Two prices, not one total. Collapsing them would silently lose a line.
    test "keeps every amount it hears, in order" do
      r = parse("2020 GMC Sierra with a 53 L and it's got an oil change all of 60 bucks filters 13 bucks")

      assert_equal [ 60.0, 13.0 ], r[:amounts]
      assert_equal 13.0, r[:currency_amount]
    end

    # ---- the common shapes must keep working ---------------------------------

    test "reads the plain year-first form" do
      r = parse("2020 GMC Sierra oil change")
      assert_equal "2020 gmc sierra", r[:vehicle][:label]
      assert_equal "oil change", r[:service]
    end

    test "reads the service-first form" do
      r = parse("alternator on a 2021 ford escape 84k")
      assert_equal "2021 ford escape", r[:vehicle][:label]
      assert_equal "alternator", r[:service]
      assert_equal 84_000, r[:mileage]
    end

    test "reads mileage given in miles" do
      r = parse("brakes on a 2019 nissan rogue 62000 miles")
      assert_equal 62_000, r[:mileage]
    end

    # ---- absent is not zero --------------------------------------------------

    # "2018 civic" names no make. Inventing one would put a wrong vehicle on the record,
    # so the make stays empty and the card asks.
    test "does not invent a make that was not said" do
      r = parse("2018 civic oil change")
      assert_nil r[:vehicle][:make]
      assert_equal "civic", r[:vehicle][:model]
      assert_equal "2018 civic", r[:vehicle][:label]
    end

    test "does not put mileage into the model name" do
      r = parse("2018 civic oil change 84k")
      assert_equal "civic", r[:vehicle][:model]
      assert_equal 84_000, r[:mileage]
    end

    test "reports nothing it was not told" do
      r = parse("oil change on a 2024 mitsubishi outlander")
      assert_nil r[:mileage]
      assert_nil r[:vin]
      assert_nil r[:plate]
      assert_nil r[:color]
      assert_nil r[:customer]
      assert_nil r[:engine]
    end

    # ---- a question is not a job --------------------------------------------

    test "refuses a question rather than logging it" do
      assert_nil parse("what did I do on the civic last time?")
      assert_nil parse("who owes me money?")
      assert_nil parse("how much did I make today?")
    end

    # ---- VIN -----------------------------------------------------------------

    test "reads a VIN from anywhere in the sentence" do
      r = parse("2020 gmc sierra brake job 5.3 liter vin 1GTR1LEC6LZ123456")
      assert_equal "1GTR1LEC6LZ123456", r[:vin]
      assert_equal "2020 gmc sierra", r[:vehicle][:label]
    end

    # I, O and Q do not appear in real VINs, so a 17-character string containing one is
    # a part number that wandered into the wrong field.
    test "refuses a seventeen character string that cannot be a VIN" do
      r = parse("brake job on a 2020 gmc sierra part 1GTR1LECOLZ123457")
      assert_nil r[:vin]
    end

    # ---- plate ---------------------------------------------------------------

    test "reads a plate only when it is named as one" do
      r = parse("oil change on a 2019 toyota camry plate ABC1234")
      assert_equal "ABC1234", r[:plate]
    end

    test "ignores a bare code that was not called a plate" do
      r = parse("oil change on a 2019 toyota camry ABC1234")
      assert_nil r[:plate]
    end

    # ---- engine --------------------------------------------------------------

    test "reads engine displacement written with a decimal" do
      assert_equal "5.3L", parse("5.3L 2020 GMC Sierra brake job")[:engine]
      assert_equal "5.3L", parse("2020 gmc sierra brake job 5.3 liter")[:engine]
    end

    # Speech to text turns "5.3" into "53". Nothing on the road is fifty-three litres, so
    # a bare two-digit number before L can only be the decimal form. A derivation from
    # the domain, not a guess - and the raw sentence is kept either way.
    test "reads a run-together displacement as the decimal it must be" do
      assert_equal "5.3L", parse("2020 gmc sierra with a 53 L oil change")[:engine]
    end

    test "reads cylinders" do
      assert_equal "V6", parse("water pump on 2015 honda accord with a v6")[:engine]
      assert_equal "4 cylinder", parse("tune up on a 2017 ford escape 4 cylinder")[:engine]
    end

    # ---- colour --------------------------------------------------------------

    test "reads a colour named outright" do
      assert_equal "white", parse("oil change on a 2019 toyota camry, color is white")[:color]
    end

    test "reads a colour sitting against the year" do
      r = parse("brakes on a red 2013 chevy silverado")
      assert_equal "red", r[:color]
      assert_equal "2013 chevy silverado", r[:vehicle][:label]
    end

    # A colour word loose in the sentence might be a name or a street, so it is not taken.
    test "does not read a colour word loose in the sentence" do
      assert_nil parse("oil change on a 2019 toyota camry for Red Miller")[:color]
    end

    # ---- customer and address ------------------------------------------------

    test "reads a customer named with a keyword" do
      r = parse("oil change on a 2019 toyota camry, customer is Dave Miller")
      assert_equal "Dave Miller", r[:customer][:name]
    end

    test "reads a customer from 'for <first last>'" do
      r = parse("tune up on a 2017 ford escape 92k for Sarah Johnson")
      assert_equal "Sarah Johnson", r[:customer][:name]
    end

    test "reads a street address" do
      r = parse("tune up on a 2017 ford escape 92k, 412 Oak Street")
      assert_equal "412 Oak Street", r[:customer][:address]
    end

    # The address pattern used to swallow the car because the vehicle was read without
    # being consumed: "2013 chevy silverado at 1234 Elm St" came back as the street.
    test "does not let the address swallow the vehicle" do
      r = parse("brakes on a red 2013 chevy silverado at 1234 Elm St, Rock Hill SC 29730")

      assert_equal "2013 chevy silverado", r[:vehicle][:label]
      assert_equal "1234 Elm St, Rock Hill SC 29730", r[:customer][:address]
    end

    # ---- the whole thing at once --------------------------------------------

    test "reads every field from one realistic sentence" do
      r = parse("oil change on a white 2019 toyota camry, plate ABC1234, 62000 miles, customer is Dave Miller")

      assert_equal "2019 toyota camry", r[:vehicle][:label]
      assert_equal "oil change", r[:service]
      assert_equal "white", r[:color]
      assert_equal "ABC1234", r[:plate]
      assert_equal 62_000, r[:mileage]
      assert_equal "Dave Miller", r[:customer][:name]
    end

    test "keeps the raw sentence so nothing it read is unrecoverable" do
      text = "2020 GMC Sierra oil change"
      assert_equal text, parse(text)[:raw]
    end
  end
end
