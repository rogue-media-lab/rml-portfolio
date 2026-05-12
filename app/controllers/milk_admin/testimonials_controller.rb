# Testimonials Controller for Milk Admin
class MilkAdmin::TestimonialsController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_restaurant
  before_action :set_testimonial, only: [ :edit, :update, :destroy ]

  def index
    @testimonials = @restaurant.testimonials.order(created_at: :desc)
  end

  def new
    @testimonial = @restaurant.testimonials.build
  end

  def create
    @testimonial = @restaurant.testimonials.build(testimonial_params)
    if @testimonial.save
      redirect_to milk_admin_restaurant_testimonials_path(@restaurant), notice: "Testimonial created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @testimonial.update(testimonial_params)
      redirect_to milk_admin_restaurant_testimonials_path(@restaurant), notice: "Testimonial updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @testimonial.destroy
    redirect_to milk_admin_restaurant_testimonials_path(@restaurant), notice: "Testimonial deleted."
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find_by!(slug: params[:restaurant_id])
  end

  def set_testimonial
    @testimonial = @restaurant.testimonials.find(params[:id])
  end

  def testimonial_params
    params.require(:testimonial).permit(:customer_name, :quote, :stars, :active, :featured)
  end
end
