# frozen_string_literal: true

RSpec.describe Rubyn::Output::Formatter do
  describe ".header" do
    it "outputs formatted header" do
      expect { described_class.header("Test") }.to output(/Test/).to_stdout
    end
  end

  describe ".success" do
    it "outputs success message" do
      expect { described_class.success("Done") }.to output(/Done/).to_stdout
    end
  end

  describe ".warning" do
    it "outputs warning message" do
      expect { described_class.warning("Caution") }.to output(/Caution/).to_stdout
    end
  end

  describe ".error" do
    it "outputs error message" do
      expect { described_class.error("Failed") }.to output(/Failed/).to_stdout
    end
  end

  describe ".info" do
    it "outputs info message" do
      expect { described_class.info("Note") }.to output(/Note/).to_stdout
    end
  end

  describe ".code_block" do
    it "outputs code block" do
      expect { described_class.code_block("puts 'hi'") }.to output(/puts.*hi/).to_stdout
    end
  end

  describe ".credit_usage" do
    it "outputs credit info" do
      expect { described_class.credit_usage(2, 98) }.to output(/2 used.*98 remaining/).to_stdout
    end
  end

  describe ".stream_print" do
    it "prints without newline" do
      expect { described_class.stream_print("chunk") }.to output("chunk").to_stdout
    end
  end
end
