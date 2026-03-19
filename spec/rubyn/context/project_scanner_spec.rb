# frozen_string_literal: true

RSpec.describe Rubyn::Context::ProjectScanner do
  describe "Rails project detection" do
    let(:scanner) { described_class.new(sample_rails_project_path) }

    it "detects Rails project type" do
      expect(scanner.scan[:project_type]).to eq("rails_app")
    end

    it "detects Ruby version from .ruby-version" do
      expect(scanner.scan[:ruby_version]).to eq("3.2.2")
    end

    it "detects test framework as rspec" do
      expect(scanner.scan[:test_framework]).to eq("rspec")
    end

    it "returns full scan metadata" do
      result = scanner.scan
      expect(result[:project_name]).to eq("sample_rails_project")
      expect(result[:project_type]).to eq("rails_app")
      expect(result[:ruby_version]).to eq("3.2.2")
      expect(result[:test_framework]).to eq("rspec")
    end

    it "scans directory structure" do
      result = scanner.scan
      expect(result[:directory_structure]["app"]).to be true
      expect(result[:directory_structure]["config"]).to be true
      expect(result[:directory_structure]["spec"]).to be true
    end
  end

  describe "Ruby gem detection" do
    let(:scanner) { described_class.new(sample_ruby_gem_path) }

    it "detects Ruby gem project type" do
      expect(scanner.scan[:project_type]).to eq("ruby_app")
    end

    it "returns nil for rails_version" do
      expect(scanner.scan[:rails_version]).to be_nil
    end
  end

  describe "other project type" do
    it "defaults to 'other_app' for unrecognized projects" do
      scanner = described_class.new("/tmp")
      expect(scanner.scan[:project_type]).to eq("other_app")
    end
  end

  describe "factory library detection" do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(tmpdir) }

    it "detects factory_bot from lockfile" do
      File.write(File.join(tmpdir, "Gemfile.lock"), <<~LOCK)
        GEM
          specs:
            factory_bot (6.2.1)
            rspec (3.12.0)
      LOCK
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:factory_library]).to eq("factory_bot")
    end

    it "detects fabrication from lockfile" do
      File.write(File.join(tmpdir, "Gemfile.lock"), <<~LOCK)
        GEM
          specs:
            fabrication (2.31.0)
            rspec (3.12.0)
      LOCK
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:factory_library]).to eq("fabrication")
    end

    it "returns no_factory when neither is present" do
      File.write(File.join(tmpdir, "Gemfile.lock"), <<~LOCK)
        GEM
          specs:
            rspec (3.12.0)
      LOCK
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:factory_library]).to eq("no_factory")
    end

    it "returns no_factory when no lockfile exists" do
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:factory_library]).to eq("no_factory")
    end
  end

  describe "auth library detection" do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(tmpdir) }

    it "detects devise from lockfile" do
      File.write(File.join(tmpdir, "Gemfile.lock"), <<~LOCK)
        GEM
          specs:
            devise (4.9.2)
      LOCK
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:auth_library]).to eq("devise")
    end

    it "detects clearance from lockfile" do
      File.write(File.join(tmpdir, "Gemfile.lock"), <<~LOCK)
        GEM
          specs:
            clearance (2.6.1)
      LOCK
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:auth_library]).to eq("clearance")
    end

    it "returns nil when no auth library is present" do
      File.write(File.join(tmpdir, "Gemfile.lock"), <<~LOCK)
        GEM
          specs:
            rspec (3.12.0)
      LOCK
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:auth_library]).to be_nil
    end

    it "returns nil when no lockfile exists" do
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:auth_library]).to be_nil
    end
  end

  describe "gem detection from lockfile" do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(tmpdir) }

    it "parses gems from lockfile specs section" do
      File.write(File.join(tmpdir, "Gemfile.lock"), <<~LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            rails (7.1.3)
            pg (1.5.4)
            rspec (3.12.0)

        PLATFORMS
          ruby
      LOCK
      scanner = described_class.new(tmpdir)
      gems = scanner.scan[:gems]
      expect(gems).to include({ name: "rails", version: "7.1.3" })
      expect(gems).to include({ name: "pg", version: "1.5.4" })
      expect(gems).to include({ name: "rspec", version: "3.12.0" })
      expect(gems.size).to eq(3)
    end

    it "returns empty array when no lockfile exists" do
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:gems]).to eq([])
    end

    it "returns empty array for an empty lockfile" do
      File.write(File.join(tmpdir, "Gemfile.lock"), "")
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:gems]).to eq([])
    end
  end

  describe "rails version detection from lockfile" do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(tmpdir) }

    it "extracts rails version from lockfile" do
      File.write(File.join(tmpdir, "Gemfile.lock"), <<~LOCK)
        GEM
          specs:
            rails (7.1.3)
      LOCK
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:rails_version]).to eq("7.1.3")
    end

    it "returns nil when rails is not in lockfile" do
      File.write(File.join(tmpdir, "Gemfile.lock"), <<~LOCK)
        GEM
          specs:
            rspec (3.12.0)
      LOCK
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:rails_version]).to be_nil
    end
  end

  describe "ruby version from .tool-versions" do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(tmpdir) }

    it "reads ruby version from .tool-versions when .ruby-version is absent" do
      File.write(File.join(tmpdir, ".tool-versions"), "ruby 3.3.0\nnodejs 20.0.0\n")
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:ruby_version]).to eq("3.3.0")
    end

    it "returns nil when neither version file exists" do
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:ruby_version]).to be_nil
    end

    it "returns nil when .tool-versions has no ruby entry" do
      File.write(File.join(tmpdir, ".tool-versions"), "nodejs 20.0.0\n")
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:ruby_version]).to be_nil
    end
  end

  describe "sinatra project detection" do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(tmpdir) }

    it "detects sinatra project type" do
      File.write(File.join(tmpdir, "config.ru"), "run Sinatra::Application")
      File.write(File.join(tmpdir, "Gemfile"), "gem 'sinatra'")
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:project_type]).to eq("sinatra_app")
    end
  end

  describe "test framework detection" do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(tmpdir) }

    it "detects rspec from lockfile" do
      File.write(File.join(tmpdir, "Gemfile.lock"), <<~LOCK)
        GEM
          specs:
            rspec (3.12.0)
      LOCK
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:test_framework]).to eq("rspec")
    end

    it "detects minitest from test/ directory" do
      FileUtils.mkdir_p(File.join(tmpdir, "test"))
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:test_framework]).to eq("minitest")
    end

    it "defaults to rspec when no indicators found" do
      scanner = described_class.new(tmpdir)
      expect(scanner.scan[:test_framework]).to eq("rspec")
    end
  end
end
