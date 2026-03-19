# frozen_string_literal: true

require "open3"

RSpec.describe Rubyn::Tools::RailsMigrate do
  let(:tmpdir) { Dir.mktmpdir }
  let(:tool) { described_class.new(tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#execute" do
    it "runs db:migrate by default (direction up)" do
      status = instance_double(Process::Status, exitstatus: 0)
      allow(Open3).to receive(:capture3)
        .with("bundle exec rails db:migrate", chdir: tmpdir)
        .and_return(["Migrated", "", status])

      result = tool.call({})
      expect(result[:success]).to be true
      expect(result[:output]).to eq("Migrated")
    end

    it "runs db:migrate with explicit up direction" do
      status = instance_double(Process::Status, exitstatus: 0)
      allow(Open3).to receive(:capture3)
        .with("bundle exec rails db:migrate", chdir: tmpdir)
        .and_return(["Migrated", "", status])

      result = tool.call("direction" => "up")
      expect(result[:success]).to be true
    end

    it "runs db:rollback for down direction without version" do
      status = instance_double(Process::Status, exitstatus: 0)
      allow(Open3).to receive(:capture3)
        .with("bundle exec rails db:rollback", chdir: tmpdir)
        .and_return(["Rolled back", "", status])

      result = tool.call("direction" => "down")
      expect(result[:success]).to be true
      expect(result[:output]).to eq("Rolled back")
    end

    it "runs db:migrate:down with specific version" do
      status = instance_double(Process::Status, exitstatus: 0)
      allow(Open3).to receive(:capture3)
        .with("bundle exec rails db:migrate:down VERSION=20240101000000", chdir: tmpdir)
        .and_return(["Reverted", "", status])

      result = tool.call("direction" => "down", "version" => "20240101000000")
      expect(result[:success]).to be true
      expect(result[:output]).to eq("Reverted")
    end

    it "returns error for invalid direction" do
      result = tool.call("direction" => "sideways")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Invalid direction")
      expect(result[:error]).to include("sideways")
    end

    it "returns error when migration command fails" do
      status = instance_double(Process::Status, exitstatus: 1)
      allow(Open3).to receive(:capture3)
        .with("bundle exec rails db:migrate", chdir: tmpdir)
        .and_return(["", "ActiveRecord::StatementInvalid", status])

      result = tool.call("direction" => "up")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Migration failed")
    end

    it "handles Open3 exceptions" do
      allow(Open3).to receive(:capture3)
        .and_raise(Errno::ENOENT, "bundle not found")

      result = tool.call("direction" => "up")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Failed to run migration")
    end

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end
  end
end
