# frozen_string_literal: true

RSpec.describe Rubyn::Output::DiffRenderer do
  describe ".render" do
    it "shows added lines" do
      original = "line1\n"
      modified = "line1\nline2\n"
      expect { described_class.render(original: original, modified: modified) }.to output(/line2/).to_stdout
    end

    it "shows removed lines" do
      original = "line1\nline2\n"
      modified = "line1\n"
      expect { described_class.render(original: original, modified: modified) }.to output(/line2/).to_stdout
    end

    it "shows unchanged lines" do
      original = "line1\nline2\n"
      modified = "line1\nline2\n"
      expect { described_class.render(original: original, modified: modified) }.to output(/line1/).to_stdout
    end

    it "outputs header markers" do
      expect { described_class.render(original: "a\n", modified: "b\n") }.to output(/---.*\+\+\+/m).to_stdout
    end
  end
end
