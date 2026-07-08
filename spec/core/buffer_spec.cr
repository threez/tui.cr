require "../spec_helper"

describe TUI::Buffer do
  describe "#box" do
    it "applies the given style to border glyphs but not to title text" do
      buffer = TUI::Buffer.new(20, 10)
      buffer.box(0, 0, 10, 20, title: "hi", style: TUI::Style.new(fg: TUI.color(:gray)))

      buffer.cell(0, 0).style.should contain("\e[90m") # top-left corner
      buffer.cell(9, 0).style.should contain("\e[90m") # bottom-left corner
      buffer.cell(1, 0).style.should contain("\e[90m") # side border

      buffer.cell(0, 2).char.should eq("h") # title text, drawn plain
      buffer.cell(0, 2).style.should_not contain("\e[90m")
    end

    it "draws borders unstyled by default" do
      buffer = TUI::Buffer.new(20, 10)
      buffer.box(0, 0, 10, 20)

      buffer.cell(0, 0).style.should eq("")
    end

    it "does not raise when h/w are too small to fit a border (e.g. mid-resize)" do
      buffer = TUI::Buffer.new(5, 5)
      buffer.box(0, 0, 0, 0)
      buffer.box(0, 0, 1, 1)
      buffer.box(0, 0, 2, 2)
    end

    it "does not raise for negative h/w" do
      buffer = TUI::Buffer.new(5, 5)
      buffer.box(0, 0, -3, -3)
    end
  end

  describe "#box_with_divider" do
    it "draws a normal box plus T-junction characters at the divider column" do
      buffer = TUI::Buffer.new(20, 10)
      buffer.box_with_divider(0, 0, 10, 20, divider_at: 9, title: "hi")

      buffer.cell(0, 0).char.should eq(TUI::Term::TL)
      buffer.cell(0, 19).char.should eq(TUI::Term::TR)
      buffer.cell(9, 0).char.should eq(TUI::Term::BL)
      buffer.cell(9, 19).char.should eq(TUI::Term::BR)

      buffer.cell(0, 9).char.should eq(TUI::Term::TJ)
      buffer.cell(9, 9).char.should eq(TUI::Term::BJ)
    end

    it "leaves the rest of the top/bottom rows untouched by the junction stamp" do
      buffer = TUI::Buffer.new(20, 10)
      buffer.box_with_divider(0, 0, 10, 20, divider_at: 9)

      buffer.cell(0, 8).char.should eq(TUI::Term::HL)
      buffer.cell(0, 10).char.should eq(TUI::Term::HL)
      buffer.cell(9, 8).char.should eq(TUI::Term::HL)
      buffer.cell(9, 10).char.should eq(TUI::Term::HL)
    end
  end

  describe "#scrollbar" do
    it "applies the given style to both the track and the thumb" do
      buffer = TUI::Buffer.new(20, 10)
      buffer.scrollbar(0, 19, 10, 0.0, visible: 4, total: 8, style: TUI::Style.new(fg: TUI.color(:gray)))

      buffer.cell(1, 19).style.should contain("\e[90m") # thumb (fraction 0.0 starts at top)
      buffer.cell(7, 19).style.should contain("\e[90m") # track
    end

    it "draws the scrollbar unstyled by default" do
      buffer = TUI::Buffer.new(20, 10)
      buffer.scrollbar(0, 19, 10, 0.0, visible: 4, total: 8)

      buffer.cell(1, 19).style.should eq("")
    end

    it "draws nothing when fraction is nil" do
      buffer = TUI::Buffer.new(20, 10)
      buffer.scrollbar(0, 19, 10, nil)

      buffer.cell(1, 19).char.should eq(" ")
    end
  end

  describe "#hline" do
    it "draws a separator spanning the given width" do
      buffer = TUI::Buffer.new(20, 10)
      buffer.hline(0, 0, 10)

      buffer.cell(0, 0).char.should eq(TUI::Term::BL)
      buffer.cell(0, 9).char.should eq(TUI::Term::BR)
      buffer.cell(0, 5).char.should eq(TUI::Term::HL)
    end

    it "does not raise when w is too small to fit both joints (e.g. mid-resize)" do
      buffer = TUI::Buffer.new(5, 5)
      buffer.hline(0, 0, 0)
      buffer.hline(0, 0, 1)
    end

    it "does not raise for negative w" do
      buffer = TUI::Buffer.new(5, 5)
      buffer.hline(0, 0, -2)
    end
  end
end
