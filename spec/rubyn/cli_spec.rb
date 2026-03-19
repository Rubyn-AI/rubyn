# frozen_string_literal: true

RSpec.describe Rubyn::CLI do
  describe "command registration" do
    it "has an init command" do
      expect(described_class.all_commands).to have_key("init")
    end

    it "has a refactor command" do
      expect(described_class.all_commands).to have_key("refactor")
    end

    it "has a spec command" do
      expect(described_class.all_commands).to have_key("spec")
    end

    it "has a review command" do
      expect(described_class.all_commands).to have_key("review")
    end

    it "has an agent command" do
      expect(described_class.all_commands).to have_key("agent")
    end

    it "has a usage command" do
      expect(described_class.all_commands).to have_key("usage")
    end

    it "has a config command" do
      expect(described_class.all_commands).to have_key("config")
    end

    it "has a dashboard command" do
      expect(described_class.all_commands).to have_key("dashboard")
    end

    # it "has an analyse command" do
    #   expect(described_class.all_commands).to have_key("analyse")
    # end
  end

  describe ".exit_on_failure?" do
    it "returns true" do
      expect(described_class.exit_on_failure?).to be true
    end
  end

  describe "command dispatch" do
    let(:cli) { described_class.new }

    before do
      allow($stdout).to receive(:write)
      allow($stdout).to receive(:print)
    end

    describe "#init" do
      it "dispatches to Commands::Init" do
        init_instance = instance_double(Rubyn::Commands::Init)
        allow(Rubyn::Commands::Init).to receive(:new).and_return(init_instance)
        expect(init_instance).to receive(:execute)
        cli.init
      end
    end

    describe "#refactor" do
      it "dispatches to Commands::Refactor with the file argument" do
        refactor_instance = instance_double(Rubyn::Commands::Refactor)
        allow(Rubyn::Commands::Refactor).to receive(:new).and_return(refactor_instance)
        expect(refactor_instance).to receive(:execute).with("app/models/user.rb")
        cli.refactor("app/models/user.rb")
      end
    end

    describe "#spec" do
      it "dispatches to Commands::Spec with the file argument" do
        spec_instance = instance_double(Rubyn::Commands::Spec)
        allow(Rubyn::Commands::Spec).to receive(:new).and_return(spec_instance)
        expect(spec_instance).to receive(:execute).with("app/models/user.rb")
        cli.spec("app/models/user.rb")
      end
    end

    describe "#review" do
      it "dispatches to Commands::Review with the file argument" do
        review_instance = instance_double(Rubyn::Commands::Review)
        allow(Rubyn::Commands::Review).to receive(:new).and_return(review_instance)
        expect(review_instance).to receive(:execute).with("app/")
        cli.review("app/")
      end
    end

    describe "#agent" do
      it "dispatches to Commands::Agent" do
        agent_instance = instance_double(Rubyn::Commands::Agent)
        allow(Rubyn::Commands::Agent).to receive(:new).and_return(agent_instance)
        expect(agent_instance).to receive(:execute)
        cli.agent
      end
    end

    describe "#usage" do
      it "dispatches to Commands::Usage" do
        usage_instance = instance_double(Rubyn::Commands::Usage)
        allow(Rubyn::Commands::Usage).to receive(:new).and_return(usage_instance)
        expect(usage_instance).to receive(:execute)
        cli.usage
      end
    end

    describe "#config" do
      it "dispatches to Commands::Config with no arguments" do
        config_instance = instance_double(Rubyn::Commands::Config)
        allow(Rubyn::Commands::Config).to receive(:new).and_return(config_instance)
        expect(config_instance).to receive(:execute).with(nil, nil)
        cli.config
      end

      it "dispatches to Commands::Config with key and value" do
        config_instance = instance_double(Rubyn::Commands::Config)
        allow(Rubyn::Commands::Config).to receive(:new).and_return(config_instance)
        expect(config_instance).to receive(:execute).with("default_model", "sonnet")
        cli.config("default_model", "sonnet")
      end
    end

    describe "#dashboard" do
      it "dispatches to Commands::Dashboard" do
        dashboard_instance = instance_double(Rubyn::Commands::Dashboard)
        allow(Rubyn::Commands::Dashboard).to receive(:new).and_return(dashboard_instance)
        expect(dashboard_instance).to receive(:execute)
        cli.dashboard
      end
    end

    # describe "#analyse" do
    #   it "dispatches to Commands::Index with force option" do
    #     index_instance = instance_double(Rubyn::Commands::Index)
    #     allow(Rubyn::Commands::Index).to receive(:new).and_return(index_instance)
    #     expect(index_instance).to receive(:execute).with(force: false)
    #     cli.invoke(:analyse)
    #   end
    # end
  end
end
