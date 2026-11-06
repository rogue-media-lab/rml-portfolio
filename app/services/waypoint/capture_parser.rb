# frozen_string_literal: true

module Waypoint
  # Turns however a technician actually says a job into structured fields.
  #
  # ORDER-FREE BY DESIGN. "2020 GMC Sierra with a 53 L and it's got an oil change all
  # of 60 bucks" contains the vehicle, the engine and the service - just not in the
  # order a regex would like. Nothing here may depend on field order, because field
  # order is a convention of forms, and technicians do not talk in forms.
  #
  # It lives on the server rather than in the browser so that it can be tested, and so
  # that SMS can use the same parser as the app. One parser, many doors.
  #
  # ABSENT IS NOT ZERO. Anything genuinely ambiguous stays absent and is reported as a
  # gap. A wrong value is worse than a missing one, because a missing one gets asked
  # about and a wrong one gets believed.
  class CaptureParser
    MAKES = %w[
      acura audi bmw buick cadillac chevrolet chevy chrysler dodge fiat ford genesis gmc
      honda hummer hyundai infiniti isuzu jaguar jeep kia land-rover landrover lexus
      lincoln mazda mercedes mercedes-benz mercury mini mitsubishi nissan oldsmobile
      plymouth pontiac porsche ram rivian saturn scion subaru suzuki tesla toyota
      volkswagen volvo pontiac saab smart daewoo
    ].freeze

    # The work Mason actually does. Longest entries first so "serpentine belt" wins
    # over "belt" and "water pump" over "pump".
    SERVICES = [
      "serpentine belt", "timing belt", "power steering pump", "water pump", "fuel pump",
      "cabin air filter", "engine air filter", "air filter", "oil filter", "fuel filter",
      "spark plugs", "spark plug", "ignition coil", "glow plug",
      "brake pads", "brake pad", "brake rotors", "rotor", "brake fluid", "brake job",
      "brake line", "brake caliper", "caliper", "brakes", "brake",
      "oil change", "transmission fluid", "trans fluid", "coolant flush", "radiator flush",
      "brake flush", "transmission flush", "flush",
      "tune up", "tune-up", "tuneup",
      "battery", "alternator", "starter", "radiator", "thermostat", "hoses", "hose",
      "belts", "belt", "wipers", "wiper blades", "tires", "tire rotation", "tire",
      "alignment", "struts", "shocks", "suspension", "cv axle", "axle", "wheel bearing",
      "oxygen sensor", "o2 sensor", "mass air flow", "maf sensor", "catalytic converter",
      "diagnostic", "inspection", "state inspection", "ac service", "air conditioning",
      "freon", "compressor", "check engine light", "check engine"
    ].freeze

    COLORS = %w[
      black white silver gray grey red blue green gold beige tan brown maroon burgundy
      orange yellow purple bronze charcoal champagne pewter sand cream teal navy
      metallic pearl matte
    ].freeze

    # Words that end a model name. Without this "Sierra with a 53 L" swallows the lot.
    BOUNDARY = %w[
      with and got has have had that this its it's the a an for on at in to of
      needs need needed wants want doing do does all bucks dollars
      vin plate tag license licence customer client name address color colour paint
      mileage miles mile engine liter litre owner phone number
    ].freeze

    VIN_RE = /\b([A-HJ-NPR-Z0-9]{17})\b/i
    PLATE_RE = /\b(?:plate|tag|licen[cs]e)\s*(?:number|num|no\.?|#)?\s*[:#]?\s*([A-Z0-9][A-Z0-9\-]{2,7})\b/i
    STREET_RE = /\b(\d{1,6}\s+[A-Za-z0-9][A-Za-z0-9 .'\-]{2,40}?\s+(?:st|street|ave|avenue|rd|road|dr|drive|ln|lane|blvd|boulevard|way|ct|court|pl|place|hwy|highway|pkwy|parkway|cir|circle|ter|terrace))\b\.?/i
    CITY_RE = /\b([A-Za-z][A-Za-z .'\-]{2,30}),?\s+([A-Z]{2})\s+(\d{5})\b/

    # "5.3 L", "5.3L", "5.3 liter", "V8", "4 cylinder"
    ENGINE_DECIMAL_RE = /\b(\d\.\d)\s*(?:l\b|liter|litre|liters|litres)/i
    ENGINE_BARE_RE = /\b([1-9]\d)\s*l\b/i
    MONEY_RE = /\$?\s?(\d+(?:\.\d{1,2})?)\s*(?:dollars|bucks|\$)/i
    # Lookahead, so the year survives: only the colour word is consumed. Eating the
    # year here is what made "white 2019 toyota camry" come back with no vehicle.
    COLOR_BEFORE_YEAR_RE = /\b(#{COLORS.join("|")})\s+(?=(?:19|20)\d{2}\b)/i
    MILEAGE_K_RE = /\b(\d{1,3})\s*k\b/
    MILEAGE_MI_RE = /\b(\d{4,6})\s*(?:mi|mi\.|miles)\b/

    # Order matters: this text is consumed as fields are found, so what is already
    # accounted for cannot confuse a later match.
    def initialize(text)
      @raw = text.to_s
      @text = @raw.dup
    end

    # Returns a hash, or nil when there is no work in the sentence at all. A question
    # like "what did I do on the civic last time?" is not a job and must not be logged
    # as one.
    def call
      service = scan_service
      return nil if service.nil?

      # Extraction order is the design, not an accident. Each field consumes its span so
      # a later, looser pattern cannot re-read it - which is exactly how "2018 civic 84k"
      # used to become a car called "civic 84k". The vehicle goes LAST because it is the
      # greediest thing here: once mileage, plate, engine and money are gone, whatever is
      # left beside the year is the model.
      mileage
      vin
      plate
      plate_state
      engine
      color
      amounts
      vehicle
      customer

      {
        vehicle: @vehicle,
        service: service,
        mileage: @mileage,
        vin: @vin,
        plate: @plate,
        plate_state: @plate_state,
        engine: @engine,
        color: @color,
        customer: @customer,
        amounts: @amounts,
        currency_amount: (@amounts || []).last,
        raw: @raw
      }
    end

    private

    def scan_service
      down = @text.downcase
      found = SERVICES.find { |s| down.include?(s) }
      return nil if found.nil?

      consume(found)
      found
    end

    # A 17-character VIN cannot be mistaken for much else, so it is safe to take from
    # anywhere. I, O and Q are excluded from real VINs - if one appears this is a part
    # number, not a VIN, and it is left alone.
    def vin
      m = @text.match(VIN_RE)
      return if m.nil?

      @vin = m[1].upcase
      consume(m[0])
    end

    # A plate can look like anything, so it is only read when the tech names it.
    def plate
      m = @text.match(PLATE_RE)
      return if m.nil?

      @plate = m[1].upcase.gsub(/[^A-Z0-9]/, "")
      consume(m[0])
    end

    def plate_state
      m = @text.match(/\b(?:plate|tag|licen[cs]e)\s*(?:from|in)\s+([A-Za-z]{2})\b/i)
      return if m.nil?

      @plate_state = m[1].upcase
      consume(m[0])
    end

    def mileage
      m = @text.match(MILEAGE_K_RE) || @text.match(MILEAGE_MI_RE)
      return if m.nil?

      @mileage = m[1].length <= 3 ? m[1].to_i * 1000 : m[1].to_i
      consume(m[0])
    end

    # Engine displacement is between about 0.6 and 8.4 litres, so a bare two-digit
    # number followed by L can only be the decimal form: "53 L" is 5.3 litres, because
    # nothing on the road is fifty-three litres. That is a derivation from the domain,
    # not a guess - and the raw sentence is kept either way.
    def engine
      if (m = @text.match(ENGINE_DECIMAL_RE))
        @engine = "#{m[1]}L"
      elsif (m = @text.match(ENGINE_BARE_RE))
        @engine = "#{(m[1].to_i / 10.0).round(1).to_s.sub(/\.0$/, '')}L"
      elsif (m = @text.match(/\b[Vv]\s?-?([68])\b/))
        @engine = "V#{m[1]}"
      elsif (m = @text.match(/\b([468])\s*cyl(?:inder)?s?\b/i))
        @engine = "#{m[1]} cylinder"
      end

      consume(m[0]) unless m.nil?
    end

    def color
      if (m = @text.match(/\b(?:color|colour|paint)\s*(?:is)?\s*([a-z]+)\b/i))
        word = m[1].downcase
        if COLORS.include?(word)
          @color = word
          consume(m[0])
          return
        end
      end

      # "white 2019" - a colour sitting straight against the year is the paint. A colour
      # word loose in the sentence is not, because it might be a name or a street.
      m = @text.match(COLOR_BEFORE_YEAR_RE)
      return if m.nil?

      @color = m[1].downcase
      consume(m[1])
    end

    # Only with a keyword, or "for" followed by two capitalised words. Bare capitalised
    # words are far more likely to be a model or a street than a person.
    def customer
      name = nil
      address = nil

      if (m = @text.match(/\b(?:customer|client|name)\s*(?:is|named|:)?\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b/))
        name = m[1].strip
        consume(m[0])
      elsif (m = @text.match(/\bfor\s+([A-Z][a-z]+\s+[A-Z][a-z]+)\b/))
        name = m[1].strip
        consume(m[0])
      end

      # Street first, then city: the street number looks more like the house and the
      # city line looks more like the state, so consuming the street first stops the
      # city pattern from swallowing the whole thing.
      if (m = @text.match(STREET_RE))
        address = m[1].strip
        consume(m[0])
      end

      if (m = @text.match(CITY_RE))
        address = [ address, m[0].strip ].compact.join(", ").presence
        consume(m[0])
      end

      return if name.nil? && address.nil?

      @customer = { name: name, address: address }
    end

    # Every amount in the sentence, in order. "all of 60 bucks filters 13 bucks" is two
    # prices, not one total, and collapsing them would silently lose a line.
    def amounts
      @amounts = @text.scan(MONEY_RE).flatten.map(&:to_f)
      @text = @text.gsub(MONEY_RE, " ")
    end

    # Year + make, order-free. If the word after the year is not a known make it is the
    # model, not a make - "2018 civic" has no make in it, and inventing one would put a
    # wrong vehicle on the record.
    def vehicle
      m = @text.match(/\b((?:19|20)\d{2})\s+([a-z][a-z\-]*)\b/i)
      return if m.nil?

      year = m[1].to_i
      word = m[2].downcase

      make = MAKES.include?(word) ? word : nil
      rest = make ? @text[(m.end(0))..].to_s : @text[(m.begin(0) + m[1].length)..].to_s
      model = take_model(rest)

      @vehicle = {
        year: year,
        make: make,
        model: model,
        label: [ year, make, model ].compact.join(" ")
      }

      # Remove the vehicle from the working text. Reading it without consuming it is what
      # let the address pattern swallow the car: "2013 chevy silverado at 1234 Elm St"
      # came back as the street.
      [ m[1], m[2], *model.to_s.split(" ") ].each { |piece| @text = @text.sub(piece, " ") }
    end

    # Stop at the first word that cannot be part of a model name.
    def take_model(rest)
      words = []
      rest.to_s.strip.split(/[\s,]+/).each do |w|
        clean = w.gsub(/[^a-z0-9\/\-]/i, "").downcase

        # A gap in the middle ends the model name. A gap at the START is only where an
        # earlier field was consumed - those spans become spaces - so it is skipped.
        # Breaking on the first empty token is what made "2017 ford escape" report no
        # model at all, after which the vehicle step swallowed the street address.
        break if clean.empty? && words.any?
        next if clean.empty?

        break if BOUNDARY.include?(clean)
        break if SERVICES.include?(clean)
        break if COLORS.include?(clean)
        # A bare number is almost always the start of an address ("412 Oak Street") or a
        # mileage that escaped, so it ends the model. It is only part of one when it
        # follows a designation that is not a plain word - "c/k 1500", "f-150".
        if clean.match?(/\A\d+\z/)
          break unless words.any? && words.last.match?(/[^a-z0-9]/)
        end

        words << clean
        break if words.length >= 3
      end

      words.join(" ").presence
    end

    # Remove a matched span so it cannot be re-read by a later, looser pattern.
    def consume(fragment)
      return if fragment.nil? || fragment.empty?

      @text = @text.sub(fragment, " ")
    end
  end
end
