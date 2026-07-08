require "../spec_helper"

private class StubScrollable
  include TUI::Scrollable

  def initialize(@count : Int32 = 20)
  end

  def content_size : Int32
    @count
  end

  def render_content(buffer : TUI::Buffer, scroll : TUI::ScrollControl) : Nil
  end

  def handle_key(ev : TUI::KeyEvent, scroll : TUI::ScrollControl) : Bool
    false
  end

  def handle_click(local_row : Int32, local_col : Int32, scroll : TUI::ScrollControl) : Bool
    false
  end

  def title : String
    "Stub"
  end

  def status_hint : String
    "hint"
  end
end

private class StubWidget < TUI::Widget
  property last_key : TUI::KeyEvent? = nil
  property? consumes : Bool = false

  def initialize(x : Int32, y : Int32, width : Int32, height : Int32, @mark : String)
    super(x, y, width, height)
  end

  def render : Nil
    @buffer.set(0, 0, @mark)
  end

  def handle_key(ev : TUI::KeyEvent) : Bool
    @last_key = ev
    @consumes
  end

  def status_hint : String
    "#{@mark} hint"
  end
end

describe TUI::HSplit do
  describe "#composite" do
    it "leaves each child's own content visible on screen, not overwritten by HSplit's own blank buffer" do
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.new(1, 1, 11, 3, left, right, left_width: 5)
      screen = TUI::Screen.new

      split.composite(screen)

      # left is blitted at screen col 0 (x=1, local col 0 -> back buffer col 0);
      # right starts after the divider at x=1+5+1=7 -> back buffer col 6.
      screen.cell(0, 0).char.should eq("L")
      screen.cell(0, 6).char.should eq("R")
    end

    it "still leaves the vertical divider visible at the configured left_width" do
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.new(1, 1, 11, 3, left, right, left_width: 5)
      screen = TUI::Screen.new

      split.composite(screen)

      screen.cell(0, 5).char.should eq(TUI::Term::VL)
    end
  end

  describe "#handle_key" do
    it "routes keys to the left pane by default without forwarding to the right" do
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.new(1, 1, 11, 3, left, right, left_width: 5)

      split.handle_key(TUI::KeyEvent.new(TUI::Key::Down))

      left.last_key.should_not be_nil
      right.last_key.should be_nil
    end

    it "Tab toggles the active pane without forwarding to either pane's handle_key" do
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.new(1, 1, 11, 3, left, right, left_width: 5)

      split.handle_key(TUI::KeyEvent.new(TUI::Key::Tab)).should be_true
      left.last_key.should be_nil
      right.last_key.should be_nil

      split.handle_key(TUI::KeyEvent.new(TUI::Key::Down))
      left.last_key.should be_nil
      right.last_key.should_not be_nil
    end

    it "focus_left resets the active pane back to left" do
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.new(1, 1, 11, 3, left, right, left_width: 5)

      split.handle_key(TUI::KeyEvent.new(TUI::Key::Tab))
      split.focus_left

      split.handle_key(TUI::KeyEvent.new(TUI::Key::Down))
      left.last_key.should_not be_nil
      right.last_key.should be_nil
    end
  end

  describe "#status_hint" do
    it "includes the Tab hint and the active pane's own hint" do
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.new(1, 1, 11, 3, left, right, left_width: 5)

      split.status_hint.should contain("Tab")
      split.status_hint.should contain("L hint")
    end
  end

  it "drives focus_if on whichever pane is active each composite" do
    left = StubWidget.new(0, 0, 1, 1, "L")
    right = StubWidget.new(0, 0, 1, 1, "R")
    split = TUI::HSplit.new(1, 1, 11, 3, left, right, left_width: 5)
    screen = TUI::Screen.new

    split.composite(screen)
    left.focused?.should be_true
    right.focused?.should be_false

    split.handle_key(TUI::KeyEvent.new(TUI::Key::Tab))
    split.composite(screen)
    left.focused?.should be_false
    right.focused?.should be_true
  end

  describe "#left_ratio" do
    it "splits proportionally to the given ratio instead of an absolute column count" do
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.new(1, 1, 30, 3, left, right, left_ratio: 0.3)

      split.left_ratio.should eq(0.3)
      split.left_width.should eq(9) # (0.3 * 30).round
      split.right.width.should eq(30 - 9 - 1)
    end

    it "re-derives left_width from the ratio on every layout, staying proportional across resizes" do
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.new(1, 1, 30, 3, left, right, left_ratio: 0.5)
      screen = TUI::Screen.new

      split.left_width.should eq(15)

      split.width = 40
      split.composite(screen)

      split.left_width.should eq(20)
      split.right.width.should eq(40 - 20 - 1)
    end

    it "clamps ratio 0.0 and 1.0 so one pane collapses to zero width instead of going negative" do
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")

      zero_split = TUI::HSplit.new(1, 1, 20, 3, left, right, left_ratio: 0.0)
      zero_split.left_width.should eq(0)
      zero_split.right.width.should eq(19)

      full_split = TUI::HSplit.new(1, 1, 20, 3, StubWidget.new(0, 0, 1, 1, "L"), StubWidget.new(0, 0, 1, 1, "R"), left_ratio: 1.0)
      full_split.left_width.should eq(20)
      full_split.right.width.should eq(0)
    end

    it "left_ratio= re-splits immediately" do
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.new(1, 1, 20, 3, left, right, left_width: 5)

      split.left_ratio = 0.25
      split.left_width.should eq(5) # (0.25 * 20).round
      split.right.width.should eq(20 - 5 - 1)
    end

    it "left_width= switches back to fixed mode, clearing the ratio" do
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.new(1, 1, 20, 3, left, right, left_ratio: 0.5)

      split.left_width = 8
      split.left_ratio.should be_nil

      split.width = 40
      split.composite(TUI::Screen.new)
      split.left_width.should eq(8) # unchanged by resize now that ratio mode is off
    end
  end

  describe ".full_screen" do
    it "sizes and positions to fill the screen below the status bar row, split evenly by default" do
      screen = TUI::Screen.new
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.full_screen(screen, left, right)

      split.x.should eq(1)
      split.y.should eq(1)
      split.width.should eq(screen.cols)
      split.height.should eq(screen.rows - 1)
      split.left_width.should eq(screen.cols // 2)
    end

    it "accepts an explicit left_width instead of the even-split default" do
      screen = TUI::Screen.new
      left = StubWidget.new(0, 0, 1, 1, "L")
      right = StubWidget.new(0, 0, 1, 1, "R")
      split = TUI::HSplit.full_screen(screen, left, right, left_width: 12)
      split.left_width.should eq(12)
    end
  end

  describe ".full_screen_scrollables" do
    it "wraps each Scrollable in its own borderless Window, split evenly by default" do
      screen = TUI::Screen.new
      split = TUI::HSplit.full_screen_scrollables(screen, StubScrollable.new, StubScrollable.new)

      split.x.should eq(1)
      split.y.should eq(1)
      split.width.should eq(screen.cols)
      split.height.should eq(screen.rows - 1)
      split.left_width.should eq(screen.cols // 2)

      left_window = split.left.as(TUI::Window)
      right_window = split.right.as(TUI::Window)
      left_window.bordered?.should be_false
      right_window.bordered?.should be_false
      left_window.width.should eq(screen.cols // 2)
      # HSplit's own layout (run eagerly in its constructor) resizes the
      # right pane to leave one column for the divider, same as it would
      # for any two Widgets passed to .full_screen directly.
      right_window.width.should eq(screen.cols - screen.cols // 2 - 1)
    end

    it "accepts an explicit left_width instead of the even-split default" do
      screen = TUI::Screen.new
      split = TUI::HSplit.full_screen_scrollables(screen, StubScrollable.new, StubScrollable.new, left_width: 12)

      split.left_width.should eq(12)
      split.left.as(TUI::Window).width.should eq(12)
      split.right.as(TUI::Window).width.should eq(screen.cols - 12 - 1)
    end
  end
end
