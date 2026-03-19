# frozen_string_literal: true

RSpec.describe Rubyn::Commands::Dashboard do
  let(:tmpdir) { Dir.mktmpdir }
  let(:command) { described_class.new }
  let(:formatter) { Rubyn::Output::Formatter }

  before do
    allow(Dir).to receive(:pwd).and_return(tmpdir)

    allow($stdout).to receive(:write)
    allow($stdout).to receive(:print)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#execute" do
    context "when in a Rails project with engine mounted" do
      before do
        routes_dir = File.join(tmpdir, "config")
        FileUtils.mkdir_p(routes_dir)
        File.write(File.join(routes_dir, "routes.rb"), <<~RUBY)
          Rails.application.routes.draw do
            mount Rubyn::Engine => "/rubyn"
          end
        RUBY
      end

      it "tells the user to use rails server" do
        expect(formatter).to receive(:info).with(/localhost:3000\/rubyn/)
        expect(formatter).to receive(:info).with(/rails s/)
        command.execute
      end

      it "does not start standalone server" do
        expect(command).not_to receive(:start_standalone_dashboard)
        command.execute
      end
    end

    context "when in a non-Rails project" do
      it "starts the standalone Sinatra dashboard and calls run!" do
        # Create a fake Sinatra::Base that executes blocks from DSL methods
        fake_sinatra_base = Class.new do
          def self.set(*, **); end

          def self.get(_path, &block)
            @route_blocks ||= []
            @route_blocks << block
          end

          def self.helpers(&block)
            @helper_blocks ||= []
            @helper_blocks << block
          end

          def self.run!
            # Execute helper blocks first, then route blocks, to cover all lines
            (@helper_blocks || []).each { |b| class_eval(&b) }
            (@route_blocks || []).each do |b|
              # Create an instance to execute route blocks
              inst = new
              inst.instance_eval(&b) rescue nil # rubocop:disable Style/RescueModifier
            end
          end
        end

        # Stub the require so the real sinatra/base is not loaded
        allow(command).to receive(:require).with("sinatra/base")
        stub_const("Sinatra::Base", fake_sinatra_base)

        expect(formatter).to receive(:info).with(/Starting standalone dashboard/)
        expect(formatter).to receive(:info).with(/localhost:9292\/rubyn/)

        command.execute
      end
    end

    context "when routes.rb exists but engine is not mounted" do
      before do
        routes_dir = File.join(tmpdir, "config")
        FileUtils.mkdir_p(routes_dir)
        File.write(File.join(routes_dir, "routes.rb"), <<~RUBY)
          Rails.application.routes.draw do
            resources :posts
          end
        RUBY
      end

      it "does not detect Rails engine and calls standalone dashboard" do
        allow(command).to receive(:start_standalone_dashboard)
        command.execute
        expect(command).to have_received(:start_standalone_dashboard)
      end
    end
  end

  describe "#rails_project_with_engine?" do
    it "returns false when no routes file exists" do
      result = command.send(:rails_project_with_engine?)
      expect(result).to be false
    end

    it "returns true when routes file contains Rubyn::Engine" do
      routes_dir = File.join(tmpdir, "config")
      FileUtils.mkdir_p(routes_dir)
      File.write(File.join(routes_dir, "routes.rb"), 'mount Rubyn::Engine => "/rubyn"')
      result = command.send(:rails_project_with_engine?)
      expect(result).to be true
    end

    it "returns false when routes file does not contain Rubyn::Engine" do
      routes_dir = File.join(tmpdir, "config")
      FileUtils.mkdir_p(routes_dir)
      File.write(File.join(routes_dir, "routes.rb"), "resources :posts")
      result = command.send(:rails_project_with_engine?)
      expect(result).to be false
    end
  end
end
