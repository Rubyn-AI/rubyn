class OrdersController < ApplicationController
  def index
    @orders = Order.all
  end

  def create
    @order = Order.new(order_params)
    if @order.save
      redirect_to @order
    else
      render :new
    end
  end

  private

  def order_params
    params.require(:order).permit(:product_id, :quantity, :total)
  end
end
