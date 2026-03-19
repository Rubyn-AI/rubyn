# frozen_string_literal: true

module FixtureHelpers
  def fixture_path(name)
    File.join(File.dirname(__FILE__), "..", "fixtures", name)
  end

  def sample_rails_project_path
    fixture_path("sample_rails_project")
  end

  def sample_ruby_gem_path
    fixture_path("sample_ruby_gem")
  end
end
