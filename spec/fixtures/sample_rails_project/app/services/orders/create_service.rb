module Orders
  class CreateService
    def initialize(params:, user:)
      @params = params
      @user = user
    end

    def call
      order = Order.new(@params.merge(user: @user))
      order.save ? order : nil
    end
  end
end
