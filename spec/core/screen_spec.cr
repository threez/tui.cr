require "../spec_helper"

describe TUI::Screen do
  describe "#at" do
    it "writes a string at 1-based absolute coordinates" do
      screen = TUI::Screen.new
      screen.at(1, 1, "hi")
      screen.cell(0, 0).char.should eq("h")
      screen.cell(0, 1).char.should eq("i")
    end
  end

  describe "#blit" do
    it "composites a widget buffer at 1-based (x, y)" do
      screen = TUI::Screen.new
      buffer = TUI::Buffer.new(3, 2)
      buffer.set(0, 0, "ab")
      buffer.set(1, 0, "cd")

      screen.blit(2, 3, buffer)

      screen.cell(2, 1).char.should eq("a")
      screen.cell(2, 2).char.should eq("b")
      screen.cell(3, 1).char.should eq("c")
      screen.cell(3, 2).char.should eq("d")
    end
  end

  describe "#vline" do
    it "draws a vertical line of the given height at absolute coordinates" do
      screen = TUI::Screen.new
      screen.vline(5, 1, 3)

      screen.cell(0, 4).char.should eq(TUI::Term::VL)
      screen.cell(1, 4).char.should eq(TUI::Term::VL)
      screen.cell(2, 4).char.should eq(TUI::Term::VL)
    end
  end

  describe "#status_bar" do
    it "fills the whole row width with the given text, reverse-video styled" do
      screen = TUI::Screen.new
      screen.status_bar(1, "hi")

      screen.cell(0, 0).char.should eq("h")
      screen.cell(0, 1).char.should eq("i")
      screen.cell(0, 0).style.should contain("7")
    end
  end

  describe "#refresh_size" do
    it "re-reads the terminal size and resets both buffers" do
      screen = TUI::Screen.new
      screen.at(1, 1, "x")
      screen.refresh_size
      screen.cell(0, 0).char.should eq(" ")
    end
  end
end
