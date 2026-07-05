require "../spec_helper"

describe TUI::CellStyle do
  describe ".apply" do
    it "renders plain text unchanged for the default (unstyled) Style" do
      TUI::CellStyle.apply(TUI::Style.new, "hi").should eq("hi")
    end

    it "delegates to Term.apply for a styled Cell" do
      style = TUI::Style.new(bold: true)
      TUI::CellStyle.apply(style, "hi").should eq(TUI::Term.apply(style, "hi"))
    end
  end
end
