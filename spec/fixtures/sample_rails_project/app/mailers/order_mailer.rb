class OrderMailer < ApplicationMailer
  def confirmation(order:, user:)
    @order = order
    @user = user
    mail(to: user.email, subject: "Order Confirmation ##{order.id}")
  end
end
