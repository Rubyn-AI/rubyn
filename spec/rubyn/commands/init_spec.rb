# frozen_string_literal: true

RSpec.describe Rubyn::Commands::Init do
  let(:tmpdir) { Dir.mktmpdir }
  let(:command) { described_class.new }

  before do
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_DIR", tmpdir)
    stub_const("Rubyn::Config::Credentials::CREDENTIALS_FILE", File.join(tmpdir, "credentials"))
    allow(Dir).to receive(:pwd).and_return(tmpdir)
    # Silence output
    allow($stdout).to receive(:write)
    allow($stdout).to receive(:print)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#execute" do
    context "with existing project config" do
      before do
        Rubyn::Config::ProjectConfig.write({ "project_token" => "rprj_existing" }, tmpdir)
        stub_join_project
      end

      it "joins the existing project" do
        expect(Rubyn.api_client).to receive(:join_project).with(project_token: "rprj_existing")
                                                          .and_return({ "project" => { "id" => 1, "role" => "member" } })
        command.execute
      end
    end

    context "new project setup" do
      let(:prompt_double) { instance_double(TTY::Prompt) }

      before do
        allow(TTY::Prompt).to receive(:new).and_return(prompt_double)
        allow(prompt_double).to receive(:ask).and_return("rk_test123")
        allow(prompt_double).to receive(:yes?).and_return(false)
        stub_auth_verify(email: "test@example.com", plan: "free")
        stub_sync_project(project_id: 42, project_token: "rprj_new123")
      end

      it "creates project config file" do
        command.execute
        config = Rubyn::Config::ProjectConfig.read(tmpdir)
        expect(config["project_token"]).to eq("rprj_new123")
        expect(config["project_id"]).to eq(42)
      end

      it "stores credentials" do
        command.execute
        expect(Rubyn::Config::Credentials.exists?).to be true
      end
    end
  end
end
