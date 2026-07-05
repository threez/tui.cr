require "../spec_helper"

describe TUI::ClickTracker do
  it "returns false on a first click" do
    tracker = TUI::ClickTracker.new
    tracker.register(3).should be_false
  end

  it "returns true on a second click on the same target within the threshold" do
    tracker = TUI::ClickTracker.new
    tracker.register(3)
    tracker.register(3).should be_true
  end

  it "resets after a double-click so a third click starts a fresh pair" do
    tracker = TUI::ClickTracker.new
    tracker.register(3)
    tracker.register(3).should be_true
    tracker.register(3).should be_false
  end

  it "returns false when the second click lands on a different target" do
    tracker = TUI::ClickTracker.new
    tracker.register(3)
    tracker.register(4).should be_false
  end

  it "returns false when clicks are spaced beyond the threshold" do
    tracker = TUI::ClickTracker.new(threshold: 100.milliseconds)
    tracker.register(3)
    sleep 200.milliseconds
    tracker.register(3).should be_false
  end

  it "honors a custom threshold" do
    tracker = TUI::ClickTracker.new(threshold: 50.milliseconds)
    tracker.register(3)
    sleep 100.milliseconds
    tracker.register(3).should be_false
  end
end
