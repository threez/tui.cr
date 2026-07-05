require "../spec_helper"

describe TUI::ScrollControl do
  describe "#visible" do
    it "returns the viewport size it was constructed with" do
      control = TUI::ScrollControl.new(TUI::Scroller.new, 7)
      control.visible.should eq(7)
    end
  end

  describe "#offset" do
    it "reads through to the underlying Scroller" do
      scroller = TUI::Scroller.new(5)
      control = TUI::ScrollControl.new(scroller, 10)
      control.offset.should eq(5)
    end
  end

  describe "#reveal" do
    it "passes the captured visible size to the Scroller" do
      scroller = TUI::Scroller.new(0)
      control = TUI::ScrollControl.new(scroller, 3)
      control.reveal(10)
      scroller.offset.should eq(8)
    end
  end

  describe "#up" do
    it "delegates to the Scroller, clamped at 0" do
      scroller = TUI::Scroller.new(5)
      control = TUI::ScrollControl.new(scroller, 10)
      control.up(10)
      scroller.offset.should eq(0)
    end
  end

  describe "#down" do
    it "passes the captured visible size through as the Scroller's viewport size" do
      scroller = TUI::Scroller.new(0)
      control = TUI::ScrollControl.new(scroller, 5)
      control.down(10, total: 10)
      scroller.offset.should eq(5)
    end
  end

  describe "#wheel_up" do
    it "delegates to the Scroller's wheel step" do
      scroller = TUI::Scroller.new(10)
      control = TUI::ScrollControl.new(scroller, 10)
      control.wheel_up
      scroller.offset.should eq(10 - TUI::Scroller::WHEEL_STEP)
    end
  end

  describe "#wheel_down" do
    it "passes the captured visible size through as the Scroller's viewport size" do
      scroller = TUI::Scroller.new(0)
      control = TUI::ScrollControl.new(scroller, 4)
      control.wheel_down(total: 5)
      scroller.offset.should eq(1)
    end
  end

  describe "#reset" do
    it "delegates to the Scroller" do
      scroller = TUI::Scroller.new(7)
      control = TUI::ScrollControl.new(scroller, 5)
      control.reset
      scroller.offset.should eq(0)
    end
  end
end
