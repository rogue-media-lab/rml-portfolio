module CarUs
  module Manager
    class CrossReferencesController < BaseController
      def index
        @cross_refs = CarUs::PartCrossReference.order(:oem_number, :brand).limit(200)
        @count = CarUs::PartCrossReference.count
      end

      def create
        file = params[:file]
        if file.blank?
          redirect_to manager_cross_references_path, alert: "Please select a CSV file."
          return
        end

        unless file.content_type.in?(%w[text/csv application/csv text/plain])
          redirect_to manager_cross_references_path, alert: "File must be a CSV."
          return
        end

        rows = []
        CSV.foreach(file.path, headers: true) do |row|
          rows << {
            oem_number: row["oem_number"]&.strip,
            brand: row["brand"]&.strip,
            brand_number: row["brand_number"]&.strip,
            part_category: row["part_category"]&.strip
          }
        end

        CarUs::PartCrossReference.bulk_upsert(rows)
        imported = rows.size

        redirect_to manager_cross_references_path,
                    notice: "#{imported} cross-references imported. Total: #{CarUs::PartCrossReference.count}"
      rescue CSV::MalformedCSVError => e
        redirect_to manager_cross_references_path, alert: "CSV error: #{e.message}"
      end

      # Daily report: pair job parts with OEM numbers, flag missing cross-refs
      def report
        shop = current_shop
        date = params[:date] ? Date.parse(params[:date]) : Date.today

        @jobs = CarUs::ServiceJob
          .where(technician: shop.technicians)
          .where(created_at: date.all_day)
          .includes(:job_parts, :vehicle)
          .order(created_at: :desc)

        @pairs = []
        @jobs.each do |job|
          template = CarUs::VehicleTemplate.for_vehicle(job.vehicle).first
          next unless template

          job.job_parts.each do |part|
            oem = find_oem_for_part(part, template)
            next unless oem

            brand = guess_brand(part.name)
            existing = CarUs::PartCrossReference.find_by(
              oem_number: oem,
              brand: brand
            )

            @pairs << {
              job: job,
              part: part,
              oem: oem,
              brand: brand,
              has_ref: existing.present?
            }
          end
        end
      end

      # One-tap create from report
      def create_from_report
        CarUs::PartCrossReference.find_or_create_by!(
          oem_number: params[:oem_number],
          brand: params[:brand]
        ) do |ref|
          ref.brand_number = params[:brand_number]
          ref.part_category = params[:part_category]
        end

        redirect_to report_manager_cross_references_path,
                    notice: "Cross-reference created: #{params[:oem_number]} → #{params[:brand]} #{params[:brand_number]}"
      end

      private

      def find_oem_for_part(part, template)
        n = part.name.downcase
        return template.oil_filter_oem if n.match?(/oil.filter/i) && !n.match?(/cabin|air/i)
        return template.cabin_air_filter_oem if n.match?(/cabin/i)
        return template.engine_air_filter_oem if n.match?(/air.filter/i) && !n.match?(/cabin/i)
        return template.spark_plug_spec if n.match?(/spark.plug|plug/i)
        nil
      end

      def guess_brand(name)
        return "Mighty" if name.match?(/^[A-Z]\d{5}|^[A-Z]{2,3}\d+/i)
        "Unknown"
      end
    end
  end
end