# frozen_string_literal: true

RSpec.describe "Search tools" do
  let(:tmpdir) { Dir.mktmpdir }

  before do
    FileUtils.mkdir_p(File.join(tmpdir, "app/models"))
    FileUtils.mkdir_p(File.join(tmpdir, "app/services"))
    FileUtils.mkdir_p(File.join(tmpdir, "spec/models"))
    File.write(File.join(tmpdir, "app/models/order.rb"), "class Order < ApplicationRecord\n  belongs_to :user\nend\n")
    File.write(File.join(tmpdir, "app/models/user.rb"), "class User < ApplicationRecord\n  has_many :orders\nend\n")
    File.write(File.join(tmpdir, "app/services/order_service.rb"),
               "class OrderService\n  def create(user)\n    Order.new(user: user)\n  end\nend\n")
    File.write(File.join(tmpdir, "spec/models/order_spec.rb"), "RSpec.describe Order do\nend\n")
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe Rubyn::Tools::ListDirectory do
    let(:tool) { described_class.new(tmpdir) }

    it "lists top-level entries" do
      result = tool.call({})
      expect(result[:success]).to be true
      names = result[:entries].map { |e| e[:name] }
      expect(names).to include("app", "spec")
    end

    it "lists a subdirectory" do
      result = tool.call("path" => "app/models")
      expect(result[:success]).to be true
      names = result[:entries].map { |e| e[:name] }
      expect(names).to include("order.rb", "user.rb")
    end

    it "does not require confirmation" do
      expect(tool.requires_confirmation?).to be false
    end
  end

  describe Rubyn::Tools::FindFiles do
    let(:tool) { described_class.new(tmpdir) }

    it "finds files by glob pattern" do
      result = tool.call("pattern" => "**/*.rb")
      expect(result[:success]).to be true
      expect(result[:count]).to eq(4)
    end

    it "finds files in a specific directory" do
      result = tool.call("pattern" => "app/models/*.rb")
      expect(result[:success]).to be true
      expect(result[:count]).to eq(2)
    end
  end

  describe Rubyn::Tools::SearchFiles do
    let(:tool) { described_class.new(tmpdir) }

    it "searches for a pattern in files" do
      result = tool.call("pattern" => "belongs_to")
      expect(result[:success]).to be true
      expect(result[:matches].size).to be >= 1
      expect(result[:matches].first[:file]).to include("order.rb")
    end

    it "filters by file pattern" do
      result = tool.call("pattern" => "Order", "file_pattern" => "*.rb", "path" => "spec")
      expect(result[:success]).to be true
      expect(result[:matches].all? { |m| m[:file].include?("spec/") }).to be true
    end

    it "returns empty matches for no results" do
      result = tool.call("pattern" => "zzzznotfound")
      expect(result[:success]).to be true
      expect(result[:matches]).to be_empty
    end
  end

  describe Rubyn::Tools::FindReferences do
    let(:tool) { described_class.new(tmpdir) }

    it "finds references to a class" do
      result = tool.call("identifier" => "Order")
      expect(result[:success]).to be true
      expect(result[:references].size).to be >= 3
    end

    it "finds references to a method" do
      result = tool.call("identifier" => "create", "type" => "method")
      expect(result[:success]).to be true
      expect(result[:references].size).to be >= 1
    end

    it "returns empty for unused identifiers" do
      result = tool.call("identifier" => "Nonexistent")
      expect(result[:success]).to be true
      expect(result[:references]).to be_empty
    end
  end
end
