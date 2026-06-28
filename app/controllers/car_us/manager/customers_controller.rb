module CarUs
  module Manager
    class CustomersController < BaseController
      def index
        @customers = current_shop.car_owners.order(created_at: :desc)
      end

      def search
        if params[:email].present?
          @customer = current_shop.car_owners.find_by("email LIKE ?", "%#{params[:email]}%")

          if @customer
            redirect_to manager_customers_path(customer_id: @customer.id)
          else
            flash[:alert] = "Customer not found: #{params[:email]}"
            redirect_to manager_customers_path
          end
        else
          redirect_to manager_customers_path
        end
      end
    end
  end
end
