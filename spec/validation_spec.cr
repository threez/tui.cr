require "./spec_helper"

describe TUI::Validation do
  describe ".valid_time?" do
    it "accepts a bare date" do
      TUI::Validation.valid_time?("2024-01-15").should be_true
    end

    it "accepts space-separated date and time" do
      TUI::Validation.valid_time?("2024-01-15 10:30:00").should be_true
    end

    it "accepts a T-separated ISO 8601 timestamp" do
      TUI::Validation.valid_time?("2024-01-15T10:30:00").should be_true
    end

    it "accepts fractional seconds" do
      TUI::Validation.valid_time?("2024-01-15T10:30:00.123").should be_true
    end

    it "accepts a timezone offset" do
      TUI::Validation.valid_time?("2024-01-15T10:30:00+02:00").should be_true
    end

    it "accepts fractional seconds with a timezone offset" do
      TUI::Validation.valid_time?("2024-01-15T10:30:00.123+02:00").should be_true
    end

    it "tolerates surrounding whitespace" do
      TUI::Validation.valid_time?("  2024-01-15  ").should be_true
    end

    it "rejects garbage input" do
      TUI::Validation.valid_time?("not a date").should be_false
    end

    it "rejects an empty string" do
      TUI::Validation.valid_time?("").should be_false
    end
  end

  describe ".valid_int?" do
    it "accepts a plain integer" do
      TUI::Validation.valid_int?("42").should be_true
    end

    it "accepts a negative integer" do
      TUI::Validation.valid_int?("-7").should be_true
    end

    it "tolerates surrounding whitespace" do
      TUI::Validation.valid_int?("  42  ").should be_true
    end

    it "rejects a float" do
      TUI::Validation.valid_int?("4.2").should be_false
    end

    it "rejects non-numeric input" do
      TUI::Validation.valid_int?("abc").should be_false
    end
  end

  describe ".valid_float?" do
    it "accepts a plain integer" do
      TUI::Validation.valid_float?("42").should be_true
    end

    it "accepts a decimal value" do
      TUI::Validation.valid_float?("4.2").should be_true
    end

    it "tolerates surrounding whitespace" do
      TUI::Validation.valid_float?("  4.2  ").should be_true
    end

    it "rejects non-numeric input" do
      TUI::Validation.valid_float?("abc").should be_false
    end
  end

  describe ".valid_decimal?" do
    it "accepts a plain integer" do
      TUI::Validation.valid_decimal?("42").should be_true
    end

    it "accepts a decimal value" do
      TUI::Validation.valid_decimal?("4.2").should be_true
    end

    it "accepts an arbitrary-precision value" do
      TUI::Validation.valid_decimal?("123456789012345678901234567890.123").should be_true
    end

    it "tolerates surrounding whitespace" do
      TUI::Validation.valid_decimal?("  4.2  ").should be_true
    end

    it "rejects non-numeric input" do
      TUI::Validation.valid_decimal?("abc").should be_false
    end
  end
end
