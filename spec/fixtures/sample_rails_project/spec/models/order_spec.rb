require "rails_helper"

RSpec.describe Order do
  describe "validations" do
    it { is_expected.to validate_presence_of(:total) }
  end
end
