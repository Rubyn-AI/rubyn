# frozen_string_literal: true

RSpec.describe Rubyn::Context::CodebaseIndexer do
  let(:indexer) { described_class.new(sample_rails_project_path) }

  describe "#chunk_file" do
    it "extracts class chunks" do
      content = <<~RUBY
        class Order < ApplicationRecord
          belongs_to :user
          validates :total, presence: true
        end
      RUBY

      chunks = indexer.send(:chunk_file, "app/models/order.rb", content)
      expect(chunks.any? { |c| c[:chunk_type] == "class" && c[:chunk_name] == "Order" }).to be true
    end

    it "extracts module chunks" do
      content = <<~RUBY
        module Orders
          class CreateService
            def call
            end
          end
        end
      RUBY

      chunks = indexer.send(:chunk_file, "app/services/orders/create_service.rb", content)
      expect(chunks.any? { |c| c[:chunk_type] == "module" && c[:chunk_name] == "Orders" }).to be true
    end

    it "returns file-level chunk for files without classes/modules" do
      content = "puts 'hello world'\n"
      chunks = indexer.send(:chunk_file, "script.rb", content)
      expect(chunks.size).to eq(1)
      expect(chunks.first[:chunk_type]).to eq("file")
    end

    it "includes line numbers" do
      content = <<~RUBY
        class Order
          def total
            0
          end
        end
      RUBY

      chunks = indexer.send(:chunk_file, "order.rb", content)
      chunk = chunks.first
      expect(chunk[:line_start]).to be_a(Integer)
      expect(chunk[:line_end]).to be_a(Integer)
      expect(chunk[:line_start]).to be <= chunk[:line_end]
    end

    it "includes file path in chunks" do
      chunks = indexer.send(:chunk_file, "app/models/order.rb", "class Order; end")
      expect(chunks.all? { |c| c[:file_path] == "app/models/order.rb" }).to be true
    end
  end

  describe "#index" do
    let(:tmpdir) { Dir.mktmpdir }
    let(:indexer) { described_class.new(tmpdir) }

    before do
      stub_index_project
      FileUtils.mkdir_p(File.join(tmpdir, "lib"))
      File.write(File.join(tmpdir, "lib", "test.rb"), "class Test; end")
    end

    after do
      FileUtils.rm_rf(tmpdir)
    end

    it "returns indexing stats" do
      result = indexer.index(force: true)
      expect(result).to have_key(:indexed)
      expect(result).to have_key(:skipped)
      expect(result[:indexed]).to eq(1)
    end
  end
end
