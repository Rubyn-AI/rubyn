# frozen_string_literal: true

RSpec.describe Rubyn::Context::ContextBuilder do
  let(:builder) { described_class.new(sample_rails_project_path) }

  describe "#build" do
    it "includes the target file content" do
      context = builder.build("app/models/order.rb")
      expect(context).to have_key("app/models/order.rb")
      expect(context["app/models/order.rb"]).to include("class Order")
    end

    it "includes related files" do
      context = builder.build("app/models/order.rb", ["db/schema.rb", "config/routes.rb"])
      expect(context).to have_key("db/schema.rb")
      expect(context).to have_key("config/routes.rb")
    end

    it "skips non-existent files" do
      context = builder.build("app/models/order.rb", ["nonexistent.rb"])
      expect(context).not_to have_key("nonexistent.rb")
    end

    it "respects max context size" do
      stub_const("Rubyn::Context::ContextBuilder::MAX_CONTEXT_BYTES", 100)
      context = builder.build("app/models/order.rb", [
                                "app/controllers/orders_controller.rb",
                                "db/schema.rb",
                                "config/routes.rb"
                              ])
      # Should not include all files due to size limit
      expect(context.size).to be < 5
    end

    it "deduplicates paths" do
      context = builder.build("app/models/order.rb", ["app/models/order.rb"])
      expect(context.size).to eq(1)
    end

    context "with custom max_bytes" do
      let(:large_builder) { described_class.new(sample_rails_project_path, max_bytes: 500_000) }

      it "allows more files with a larger limit" do
        all_files = %w[
          app/controllers/orders_controller.rb
          app/models/user.rb
          app/models/line_item.rb
          app/services/orders/create_service.rb
          app/services/orders/notification_service.rb
          app/mailers/order_mailer.rb
          app/policies/order_policy.rb
          db/schema.rb
          config/routes.rb
        ]

        context = large_builder.build("app/models/order.rb", all_files)
        expect(context.size).to be > 5
      end

      it "uses the agent constant for 500k" do
        expect(Rubyn::Context::ContextBuilder::AGENT_MAX_CONTEXT_BYTES).to eq(500_000)
      end
    end
  end
end
