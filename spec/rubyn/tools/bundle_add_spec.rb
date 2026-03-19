# frozen_string_literal: true

require "open3"

RSpec.describe Rubyn::Tools::BundleAdd do
  let(:tmpdir) { Dir.mktmpdir }
  let(:tool) { described_class.new(tmpdir) }
  let(:gemfile_path) { File.join(tmpdir, "Gemfile") }

  before do
    File.write(gemfile_path, <<~GEMFILE)
      source "https://rubygems.org"

      gem "rails"
    GEMFILE
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe "#execute" do
    it "requires gem_name parameter" do
      result = tool.call({})
      expect(result[:success]).to be false
      expect(result[:error]).to include("gem_name is required")
    end

    it "rejects empty gem_name" do
      result = tool.call("gem_name" => "  ")
      expect(result[:success]).to be false
      expect(result[:error]).to include("gem_name is required")
    end

    it "returns error when Gemfile is missing" do
      FileUtils.rm(gemfile_path)
      result = tool.call("gem_name" => "sidekiq")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Gemfile not found")
    end

    it "adds a gem line without version" do
      status = instance_double(Process::Status, exitstatus: 0)
      allow(Open3).to receive(:capture3)
        .with("bundle install", chdir: tmpdir)
        .and_return(["Installing sidekiq", "", status])

      result = tool.call("gem_name" => "sidekiq")
      expect(result[:success]).to be true
      expect(result[:gem_name]).to eq("sidekiq")

      content = File.read(gemfile_path)
      expect(content).to include('gem "sidekiq"')
    end

    it "adds a gem line with version constraint" do
      status = instance_double(Process::Status, exitstatus: 0)
      allow(Open3).to receive(:capture3)
        .with("bundle install", chdir: tmpdir)
        .and_return(["Installing sidekiq", "", status])

      tool.call("gem_name" => "sidekiq", "version" => "~> 7.0")

      content = File.read(gemfile_path)
      expect(content).to include('gem "sidekiq", "~> 7.0"')
    end

    it "inserts gem into an existing group" do
      File.write(gemfile_path, <<~GEMFILE)
        source "https://rubygems.org"

        gem "rails"

        group :development do
          gem "pry"
        end
      GEMFILE

      status = instance_double(Process::Status, exitstatus: 0)
      allow(Open3).to receive(:capture3)
        .with("bundle install", chdir: tmpdir)
        .and_return(["OK", "", status])

      tool.call("gem_name" => "rubocop", "group" => "development")

      content = File.read(gemfile_path)
      expect(content).to include('gem "rubocop"')
      expect(content).to match(/group :development do\n\s+gem "rubocop"/)
    end

    it "creates a new group block when group does not exist" do
      status = instance_double(Process::Status, exitstatus: 0)
      allow(Open3).to receive(:capture3)
        .with("bundle install", chdir: tmpdir)
        .and_return(["OK", "", status])

      tool.call("gem_name" => "rspec", "group" => "test")

      content = File.read(gemfile_path)
      expect(content).to include("group :test do")
      expect(content).to include('gem "rspec"')
    end

    it "returns error when bundle install fails" do
      status = instance_double(Process::Status, exitstatus: 1)
      allow(Open3).to receive(:capture3)
        .with("bundle install", chdir: tmpdir)
        .and_return(["", "Could not find gem", status])

      result = tool.call("gem_name" => "nonexistent_gem_xyz")
      expect(result[:success]).to be false
      expect(result[:error]).to include("bundle install failed")
    end

    it "handles bundle install exception" do
      allow(Open3).to receive(:capture3)
        .with("bundle install", chdir: tmpdir)
        .and_raise(Errno::ENOENT, "bundle not found")

      result = tool.call("gem_name" => "sidekiq")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Failed to run bundle install")
    end

    it "handles Gemfile write errors" do
      allow(File).to receive(:read).with(gemfile_path).and_raise(Errno::EACCES, "Permission denied")

      result = tool.call("gem_name" => "sidekiq")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Failed to update Gemfile")
    end

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end
  end
end
