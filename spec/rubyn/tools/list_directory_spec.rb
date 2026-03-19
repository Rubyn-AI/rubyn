# frozen_string_literal: true

RSpec.describe Rubyn::Tools::ListDirectory do
  let(:tmpdir) { Dir.mktmpdir }
  let(:tool) { described_class.new(tmpdir) }

  before do
    # Create a directory structure for testing
    FileUtils.mkdir_p(File.join(tmpdir, "app", "models"))
    FileUtils.mkdir_p(File.join(tmpdir, "app", "controllers"))
    FileUtils.mkdir_p(File.join(tmpdir, "lib"))
    FileUtils.mkdir_p(File.join(tmpdir, "spec"))
    FileUtils.mkdir_p(File.join(tmpdir, ".git"))
    FileUtils.mkdir_p(File.join(tmpdir, "node_modules", "some_package"))
    FileUtils.mkdir_p(File.join(tmpdir, "vendor", "bundle"))
    FileUtils.mkdir_p(File.join(tmpdir, "deep", "level1", "level2", "level3"))

    File.write(File.join(tmpdir, "Gemfile"), "source 'https://rubygems.org'")
    File.write(File.join(tmpdir, "app", "models", "user.rb"), "class User; end")
    File.write(File.join(tmpdir, "app", "models", "order.rb"), "class Order; end")
    File.write(File.join(tmpdir, "app", "controllers", "users_controller.rb"), "class UsersController; end")
    File.write(File.join(tmpdir, "lib", "helper.rb"), "module Helper; end")
    File.write(File.join(tmpdir, "deep", "level1", "level2", "level3", "deep_file.rb"), "# deep")
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#execute" do
    context "flat listing (non-recursive)" do
      it "lists top-level entries" do
        result = tool.call({})
        expect(result[:success]).to be true
        names = result[:entries].map { |e| e[:name] }
        expect(names).to include("app", "lib", "spec", "Gemfile")
      end

      it "marks directories as type directory" do
        result = tool.call({})
        app_entry = result[:entries].find { |e| e[:name] == "app" }
        expect(app_entry[:type]).to eq("directory")
        expect(app_entry[:size]).to eq(0)
      end

      it "marks files with type file and a size" do
        result = tool.call({})
        gemfile_entry = result[:entries].find { |e| e[:name] == "Gemfile" }
        expect(gemfile_entry[:type]).to eq("file")
        expect(gemfile_entry[:size]).to be > 0
      end

      it "lists a subdirectory" do
        result = tool.call("path" => "app/models")
        expect(result[:success]).to be true
        names = result[:entries].map { |e| e[:name] }
        expect(names).to include("user.rb", "order.rb")
      end

      it "returns error for non-existent directory" do
        result = tool.call("path" => "nonexistent")
        expect(result[:success]).to be false
        expect(result[:error]).to include("not found")
      end
    end

    context "excluded directories" do
      it "excludes .git directories" do
        result = tool.call({})
        names = result[:entries].map { |e| e[:name] }
        expect(names).not_to include(".git")
      end

      it "excludes node_modules directories" do
        result = tool.call({})
        names = result[:entries].map { |e| e[:name] }
        expect(names).not_to include("node_modules")
      end

      it "excludes vendor directory" do
        result = tool.call({})
        names = result[:entries].map { |e| e[:name] }
        expect(names).not_to include("vendor")
      end
    end

    context "recursive listing" do
      it "lists entries recursively" do
        result = tool.call("recursive" => true)
        expect(result[:success]).to be true
        names = result[:entries].map { |e| e[:name] }
        expect(names).to include("app/models/user.rb")
        expect(names).to include("app/controllers/users_controller.rb")
      end

      it "excludes .git entries when listing recursively" do
        result = tool.call("recursive" => true)
        names = result[:entries].map { |e| e[:name] }
        expect(names.none? { |n| n.include?(".git") }).to be true
      end

      it "includes deeply nested files" do
        result = tool.call("recursive" => true)
        names = result[:entries].map { |e| e[:name] }
        expect(names).to include("deep/level1/level2/level3/deep_file.rb")
      end
    end

    context "MAX_ENTRIES limit" do
      it "respects the max entries limit" do
        # Create more files than MAX_ENTRIES
        stub_const("Rubyn::Tools::ListDirectory::MAX_ENTRIES", 3)
        result = tool.call({})
        expect(result[:success]).to be true
        expect(result[:entries].size).to be <= 3
      end

      it "limits entries in recursive mode" do
        # The recursive listing returns early once MAX_ENTRIES is reached
        # at each recursion level, so the result is bounded
        result_full = tool.call("recursive" => true)
        full_count = result_full[:entries].size

        stub_const("Rubyn::Tools::ListDirectory::MAX_ENTRIES", 3)
        limited_tool = described_class.new(tmpdir)
        result_limited = limited_tool.call("recursive" => true)
        expect(result_limited[:success]).to be true
        expect(result_limited[:entries].size).to be < full_count
      end
    end

    context "path traversal prevention" do
      it "blocks access outside project root" do
        result = tool.call("path" => "../../etc")
        expect(result[:success]).to be false
        expect(result[:error]).to include("outside project")
      end
    end

    it "does not require confirmation" do
      expect(tool.requires_confirmation?).to be false
    end

    it "returns the relative path in the result" do
      result = tool.call("path" => "app/models")
      expect(result[:path]).to eq("app/models")
    end
  end
end
