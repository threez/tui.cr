require "../spec_helper"

describe TUI::Scroller do
  describe "#up" do
    it "moves the offset up, clamped at 0" do
      s = TUI::Scroller.new(5)
      s.up(2)
      s.offset.should eq(3)
      s.up(10)
      s.offset.should eq(0)
    end
  end

  describe "#down" do
    it "moves the offset down, clamped at total - visible" do
      s = TUI::Scroller.new(0)
      s.down(2, total: 10, visible: 5)
      s.offset.should eq(2)
      s.down(10, total: 10, visible: 5)
      s.offset.should eq(5)
    end
  end

  describe "#clamp" do
    it "pulls a stale offset back within bounds" do
      s = TUI::Scroller.new(20)
      s.clamp(10, 5)
      s.offset.should eq(5)
    end
  end

  describe "#reset" do
    it "returns the offset to 0" do
      s = TUI::Scroller.new(7)
      s.reset
      s.offset.should eq(0)
    end
  end

  describe "#reveal" do
    it "scrolls up to reveal an index above the viewport" do
      s = TUI::Scroller.new(5)
      s.reveal(2, 3)
      s.offset.should eq(2)
    end

    it "scrolls down to reveal an index below the viewport" do
      s = TUI::Scroller.new(0)
      s.reveal(10, 3)
      s.offset.should eq(8)
    end
  end

  describe "#fraction" do
    it "is nil when content fits entirely" do
      s = TUI::Scroller.new(0)
      s.fraction(5, 10).should be_nil
    end

    it "reflects the offset's position within the scrollable range" do
      s = TUI::Scroller.new(5)
      s.fraction(15, 5).should eq(0.5)
    end
  end

  describe "::WHEEL_STEP" do
    it "is 3" do
      TUI::Scroller::WHEEL_STEP.should eq(3)
    end
  end

  describe "#wheel_up" do
    it "moves by WHEEL_STEP by default" do
      s = TUI::Scroller.new(10)
      s.wheel_up
      s.offset.should eq(10 - TUI::Scroller::WHEEL_STEP)
    end

    it "accepts an explicit step override" do
      s = TUI::Scroller.new(10)
      s.wheel_up(1)
      s.offset.should eq(9)
    end
  end

  describe "#wheel_down" do
    it "moves by WHEEL_STEP by default, clamped like #down" do
      s = TUI::Scroller.new(0)
      s.wheel_down(total: 100, visible: 10)
      s.offset.should eq(TUI::Scroller::WHEEL_STEP)
    end

    it "clamps at total - visible" do
      s = TUI::Scroller.new(0)
      s.wheel_down(total: 5, visible: 4)
      s.offset.should eq(1)
    end
  end
end
