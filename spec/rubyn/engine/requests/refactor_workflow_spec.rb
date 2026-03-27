# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Refactor workflow", type: :request do
  let(:original_file) { "app/models/order.rb" }

  let(:api_response_body) do
    <<~RESPONSE
      **Summary**

      Extracting validation into a concern and adding a scope.

      **Updated file: app/models/order.rb**

      ```ruby
      # frozen_string_literal: true

      class Order < ApplicationRecord
        include OrderValidations
        scope :recent, -> { where("created_at > ?", 7.days.ago) }
      end
      ```

      **New file: app/models/concerns/order_validations.rb**

      ```ruby
      # frozen_string_literal: true

      module OrderValidations
        extend ActiveSupport::Concern

        included do
          validates :total, presence: true
        end
      end
      ```

      **Updated file: app/models/post.rb**

      ```ruby
      # frozen_string_literal: true

      class Post < ApplicationRecord
        scope :published, -> { where(status: "published") }
      end
      ```

      **Why**

      - Extracted validations into a concern
      - Added scopes to both models
    RESPONSE
  end

  before do
    stub_request(:post, "https://api.rubyn.dev/api/v1/ai/refactor")
      .to_return(
        status: 200,
        body: { response: api_response_body, credits_used: 2, interaction_id: 1 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    @original_order = File.read(Rails.root.join("app/models/order.rb"))
    @original_post = File.read(Rails.root.join("app/models/post.rb"))
  end

  after do
    File.write(Rails.root.join("app/models/order.rb"), @original_order)
    File.write(Rails.root.join("app/models/post.rb"), @original_post)
    FileUtils.rm_f(Rails.root.join("app/models/concerns/order_validations.rb"))
    FileUtils.rm_rf(Rails.root.join("app/models/concerns")) if Dir.empty?(Rails.root.join("app/models/concerns")) rescue nil
  end

  describe "step 1: refactor request returns response" do
    it "returns a response containing Updated and New file headers" do
      post "/rubyn/refactor", params: { file: original_file }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["response"]).to include("**Updated file:")
      expect(json["response"]).to include("**New file:")
      expect(json["credits_used"]).to eq(2)
    end
  end

  describe "step 2: response is parsed with correct tags" do
    subject(:blocks) { Rubyn::Context::ResponseParser.extract_file_blocks(api_response_body) }

    it "extracts three file blocks" do
      expect(blocks.length).to eq(3)
    end

    it "tags the first file as updated" do
      expect(blocks[0][:path]).to eq("app/models/order.rb")
      expect(blocks[0][:tag]).to eq("updated")
    end

    it "tags the second file as new" do
      expect(blocks[1][:path]).to eq("app/models/concerns/order_validations.rb")
      expect(blocks[1][:tag]).to eq("new")
    end

    it "tags the third file as updated" do
      expect(blocks[2][:path]).to eq("app/models/post.rb")
      expect(blocks[2][:tag]).to eq("updated")
    end
  end

  describe "step 3: apply individual files" do
    it "updates an existing file and returns Updated" do
      patch "/rubyn/refactor",
            params: { file: "app/models/order.rb", code: "class Order\n  scope :recent, -> { all }\nend\n" },
            as: :json

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["message"]).to start_with("Updated")
      expect(File.read(Rails.root.join("app/models/order.rb"))).to include("scope :recent")
    end

    it "creates a new file and returns Created" do
      patch "/rubyn/refactor",
            params: { file: "app/models/concerns/order_validations.rb", code: "module OrderValidations\nend\n" },
            as: :json

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["message"]).to start_with("Created")
      expect(File.exist?(Rails.root.join("app/models/concerns/order_validations.rb"))).to be true
    end
  end

  describe "step 4: apply all files in sequence" do
    it "applies all parsed blocks and each reports correct Created/Updated" do
      blocks = Rubyn::Context::ResponseParser.extract_file_blocks(api_response_body)
      results = []

      blocks.each do |block|
        patch "/rubyn/refactor",
              params: { file: block[:path], code: block[:code] },
              as: :json

        json = JSON.parse(response.body)
        results << { path: block[:path], tag: block[:tag], success: json["success"], message: json["message"] }
      end

      # First file: order.rb exists -> Updated
      expect(results[0][:success]).to be true
      expect(results[0][:message]).to start_with("Updated")
      expect(results[0][:tag]).to eq("updated")

      # Second file: concern doesn't exist -> Created
      expect(results[1][:success]).to be true
      expect(results[1][:message]).to start_with("Created")
      expect(results[1][:tag]).to eq("new")

      # Third file: post.rb exists -> Updated
      expect(results[2][:success]).to be true
      expect(results[2][:message]).to start_with("Updated")
      expect(results[2][:tag]).to eq("updated")

      # Verify files on disk
      expect(File.read(Rails.root.join("app/models/order.rb"))).to include("OrderValidations")
      expect(File.read(Rails.root.join("app/models/concerns/order_validations.rb"))).to include("module OrderValidations")
      expect(File.read(Rails.root.join("app/models/post.rb"))).to include("scope :published")
    end
  end
end
