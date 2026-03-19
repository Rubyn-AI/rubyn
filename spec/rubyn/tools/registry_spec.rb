# frozen_string_literal: true

RSpec.describe Rubyn::Tools::Registry do
  describe ".all" do
    it "returns all registered tools" do
      tools = described_class.all
      expect(tools).to be_a(Hash)
      expect(tools.size).to be >= 21
    end
  end

  describe ".get" do
    it "returns a tool class by name" do
      expect(described_class.get("read_file")).to eq(Rubyn::Tools::ReadFile)
    end

    it "returns nil for unknown tools" do
      expect(described_class.get("nonexistent")).to be_nil
    end
  end

  describe ".tool_definitions" do
    it "returns definitions for all tools" do
      defs = described_class.tool_definitions
      expect(defs).to be_an(Array)
      expect(defs.first).to have_key(:name)
      expect(defs.first).to have_key(:description)
      expect(defs.first).to have_key(:parameters)
    end
  end

  describe "registered tools" do
    %w[
      read_file write_file create_file patch_file delete_file move_file
      list_directory find_files search_files find_references
      run_command run_tests
      rails_routes rails_generate rails_migrate bundle_add
      git_status git_diff git_log git_commit git_create_branch
    ].each do |tool_name|
      it "has #{tool_name} registered" do
        expect(described_class.get(tool_name)).not_to be_nil
      end
    end
  end
end
