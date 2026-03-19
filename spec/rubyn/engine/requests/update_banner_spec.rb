# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Update banner", type: :request do
  before do
    cache_file = Rubyn::VersionChecker::CACHE_FILE
    FileUtils.rm_f(cache_file) if File.exist?(cache_file)
    stub_get_balance(balance: 100, plan: "free")
    stub_get_history
  end

  context "when a newer version is available" do
    before do
      allow(Rubyn::VersionChecker).to receive(:update_message)
        .and_return("Rubyn 2.0.0 is available (you have #{Rubyn::VERSION}). Run `gem update rubyn` to upgrade.")
    end

    it "shows the update banner on the dashboard" do
      get "/rubyn"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("rubyn-update-banner")
      expect(response.body).to include("2.0.0")
      expect(response.body).to include("gem update rubyn")
    end
  end

  context "when on the latest version" do
    before do
      allow(Rubyn::VersionChecker).to receive(:update_message).and_return(nil)
    end

    it "does not show the update banner" do
      get "/rubyn"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("rubyn-update-banner")
    end
  end

  context "when version check fails" do
    before do
      allow(Rubyn::VersionChecker).to receive(:update_message).and_return(nil)
    end

    it "does not show the update banner and does not error" do
      get "/rubyn"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("rubyn-update-banner")
    end
  end
end
