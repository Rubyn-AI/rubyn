class OrderPolicy
  attr_reader :user, :order

  def initialize(user, order)
    @user = user
    @order = order
  end

  def show?
    order.user == user
  end
end
