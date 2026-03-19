# frozen_string_literal: true

RSpec.describe "Rails tools" do
  let(:tmpdir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe Rubyn::Tools::RailsRoutes do
    let(:tool) { described_class.new(tmpdir) }

    it "does not require confirmation" do
      expect(tool.requires_confirmation?).to be false
    end

    it "attempts to run rails routes" do
      result = tool.call({})
      # Will fail in non-Rails project but should return gracefully
      expect(result).to have_key(:success)
    end
  end

  describe Rubyn::Tools::RailsGenerate do
    let(:tool) { described_class.new(tmpdir) }

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end

    it "requires generator and args parameters" do
      result = tool.call("generator" => "model", "args" => "Post title:string")
      # Will fail in non-Rails project but should return gracefully
      expect(result).to have_key(:success)
    end
  end

  describe Rubyn::Tools::RailsMigrate do
    let(:tool) { described_class.new(tmpdir) }

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end

    it "attempts to run migrations" do
      result = tool.call({})
      expect(result).to have_key(:success)
    end
  end

  describe Rubyn::Tools::BundleAdd do
    let(:tool) { described_class.new(tmpdir) }

    before do
      File.write(File.join(tmpdir, "Gemfile"), "source 'https://rubygems.org'\n\ngem 'rails'\n")
    end

    it "requires confirmation" do
      expect(tool.requires_confirmation?).to be true
    end

    it "adds a gem line to the Gemfile" do
      tool.call("gem_name" => "sidekiq", "version" => "~> 7.0")
      # bundle install will fail but the Gemfile should be updated
      gemfile = File.read(File.join(tmpdir, "Gemfile"))
      expect(gemfile).to include("sidekiq")
    end
  end
end
