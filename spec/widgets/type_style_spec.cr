require "../spec_helper"

describe TUI::TypeStyle do
  describe ".for" do
    it "maps int32/int64/uuid portable types to cyan" do
      TUI::TypeStyle.for("int32", "").should eq(TUI::Style.new(fg: TUI.color(:cyan)))
      TUI::TypeStyle.for("int64", "").should eq(TUI::Style.new(fg: TUI.color(:cyan)))
      TUI::TypeStyle.for("uuid", "").should eq(TUI::Style.new(fg: TUI.color(:cyan)))
    end

    it "maps float32/float64/decimal portable types to yellow" do
      TUI::TypeStyle.for("float32", "").should eq(TUI::Style.new(fg: TUI.color(:yellow)))
      TUI::TypeStyle.for("float64", "").should eq(TUI::Style.new(fg: TUI.color(:yellow)))
      TUI::TypeStyle.for("decimal", "").should eq(TUI::Style.new(fg: TUI.color(:yellow)))
    end

    it "maps bool to green" do
      TUI::TypeStyle.for("bool", "").should eq(TUI::Style.new(fg: TUI.color(:green)))
    end

    it "maps time to blue" do
      TUI::TypeStyle.for("time", "").should eq(TUI::Style.new(fg: TUI.color(:blue)))
    end

    it "maps bytes to magenta" do
      TUI::TypeStyle.for("bytes", "").should eq(TUI::Style.new(fg: TUI.color(:magenta)))
    end

    it "falls back to the default style for an unrecognized portable type" do
      TUI::TypeStyle.for("something_else", "").should eq(TUI::Style.new)
    end

    it "sniffs type_text substrings when portable_type is nil" do
      TUI::TypeStyle.for(nil, "INTEGER").should eq(TUI::Style.new(fg: TUI.color(:cyan)))
      TUI::TypeStyle.for(nil, "SERIAL").should eq(TUI::Style.new(fg: TUI.color(:cyan)))
      TUI::TypeStyle.for(nil, "DOUBLE PRECISION").should eq(TUI::Style.new(fg: TUI.color(:yellow)))
      TUI::TypeStyle.for(nil, "NUMERIC(10,2)").should eq(TUI::Style.new(fg: TUI.color(:yellow)))
      TUI::TypeStyle.for(nil, "BOOLEAN").should eq(TUI::Style.new(fg: TUI.color(:green)))
      TUI::TypeStyle.for(nil, "TIMESTAMP").should eq(TUI::Style.new(fg: TUI.color(:blue)))
      TUI::TypeStyle.for(nil, "BYTEA").should eq(TUI::Style.new(fg: TUI.color(:magenta)))
    end

    it "sniffs case-insensitively" do
      TUI::TypeStyle.for(nil, "integer").should eq(TUI::Style.new(fg: TUI.color(:cyan)))
    end

    it "falls back to the default style when no substring hint matches" do
      TUI::TypeStyle.for(nil, "JSONB").should eq(TUI::Style.new)
    end
  end
end
