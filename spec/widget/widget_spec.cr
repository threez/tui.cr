require "../spec_helper"

private class TestWidget < TUI::Widget
  def render : Nil
  end

  def handle_key(ev : TUI::KeyEvent) : Bool
    false
  end

  def status_hint : String
    ""
  end
end

describe TUI::Widget do
  describe "#absolute" do
    it "maps (0, 0) to the widget's own origin" do
      widget = TestWidget.new(5, 3, 20, 10)
      widget.absolute(0, 0).should eq({row: 3, col: 5})
    end

    it "adds local offsets onto the widget's origin" do
      widget = TestWidget.new(5, 3, 20, 10)
      widget.absolute(2, 7).should eq({row: 5, col: 12})
    end

    it "tracks a widget positioned away from the terminal origin" do
      widget = TestWidget.new(1, 1, 80, 24)
      widget.absolute(4, 9).should eq({row: 5, col: 10})
    end
  end

  describe "#local" do
    it "maps the widget's own origin to (0, 0)" do
      widget = TestWidget.new(5, 3, 20, 10)
      widget.local(3, 5).should eq({row: 0, col: 0})
    end

    it "subtracts the widget's origin from absolute offsets" do
      widget = TestWidget.new(5, 3, 20, 10)
      widget.local(5, 12).should eq({row: 2, col: 7})
    end

    it "is the inverse of #absolute" do
      widget = TestWidget.new(5, 3, 20, 10)
      abs = widget.absolute(4, 9)
      widget.local(abs[:row], abs[:col]).should eq({row: 4, col: 9})
    end
  end
end
