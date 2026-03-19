module Orders
  class NotificationService
    def initialize(order:)
      @order = order
    end

    def call
      user = @order.user
      OrderMailer.confirmation(order: @order, user: user).deliver_later
      SlackNotifier.notify("New order ##{@order.id} from #{user.email}")
    end
  end
end
