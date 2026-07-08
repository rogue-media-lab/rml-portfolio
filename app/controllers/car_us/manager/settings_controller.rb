module CarUs
  module Manager
    class SettingsController < BaseController
      def edit
      end

      def update
        if current_shop.update_settings(cast_settings(settings_params))
          redirect_to manager_root_path, notice: "Shop settings updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def settings_params
        params.require(:settings).permit(
          :tax_rate, :max_bookings_per_slot,
          :supplies_fee_enabled, :supplies_fee,
          :travel_fee_enabled, :travel_fee, :travel_fee_label,
          :target_hours, :auto_update_parts,
          target_services: []
        )
      end

      # Cast checkbox strings to real booleans and numbers
      def cast_settings(raw)
        {
          tax_rate:              raw[:tax_rate].to_f,
          max_bookings_per_slot: raw[:max_bookings_per_slot].to_i,
          supplies_fee_enabled:  ActiveModel::Type::Boolean.new.cast(raw[:supplies_fee_enabled]),
          supplies_fee:          raw[:supplies_fee].to_f,
          travel_fee_enabled:    ActiveModel::Type::Boolean.new.cast(raw[:travel_fee_enabled]),
          travel_fee:            raw[:travel_fee].to_f,
          travel_fee_label:      raw[:travel_fee_label].to_s,
          target_hours:          raw[:target_hours].to_f,
          auto_update_parts:     ActiveModel::Type::Boolean.new.cast(raw[:auto_update_parts]),
          target_services:       Array(raw[:target_services]).reject(&:blank?)
        }
      end
    end
  end
end
