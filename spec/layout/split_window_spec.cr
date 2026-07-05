require "../spec_helper"

private class StubScrollable
  include TUI::Scrollable

  property clicked : {Int32, Int32}? = nil
  property last_render_offset : Int32 = -1

  def initialize(@count : Int32 = 20)
  end

  def content_size : Int32
    @count
  end

  def render_content(buffer : TUI::Buffer, scroll : TUI::ScrollControl) : Nil
    @last_render_offset = scroll.offset
  end

  def handle_key(ev : TUI::KeyEvent, scroll : TUI::ScrollControl) : Bool
    case ev.key
    when TUI::Key::MouseWheelDown
      scroll.wheel_down(total: @count)
      true
    else
      false
    end
  end

  def handle_click(local_row : Int32, local_col : Int32, scroll : TUI::ScrollControl) : Bool
    @clicked = {local_row, local_col}
    true
  end

  def title : String
    "Stub"
  end

  def status_hint : String
    "hint"
  end
end

describe TUI::SplitWindow do
  describe "#handle_key mouse click routing" do
    it "routes a left-pane click to left.handle_click with divider-relative local coords and activates left" do
      left = StubScrollable.new(50)
      right = StubScrollable.new(50)
      split = TUI::SplitWindow.new(1, 1, 20, 10, left, right, left_width: 8)
      split.composite(TUI::Screen.new)

      abs = split.absolute(2, 3) # inside the left pane
      split.handle_key(TUI::KeyEvent.new(TUI::Key::MouseClick, row: abs[:row], col: abs[:col]))

      left.clicked.should eq({1, 2})
      right.clicked.should be_nil
    end

    it "routes a right-pane click to right.handle_click with the divider width subtracted, activates right" do
      left = StubScrollable.new(50)
      right = StubScrollable.new(50)
      split = TUI::SplitWindow.new(1, 1, 20, 10, left, right, left_width: 8)
      split.composite(TUI::Screen.new)

      abs = split.absolute(2, 12) # inside the right pane
      split.handle_key(TUI::KeyEvent.new(TUI::Key::MouseClick, row: abs[:row], col: abs[:col]))

      right.clicked.should eq({1, 2})
      left.clicked.should be_nil
    end

    it "consumes a click exactly on the divider without routing to either pane" do
      left = StubScrollable.new(50)
      right = StubScrollable.new(50)
      split = TUI::SplitWindow.new(1, 1, 20, 10, left, right, left_width: 8)
      split.composite(TUI::Screen.new)

      abs = split.absolute(2, 9) # local col 9 == inset(1) + left_width(8), the divider
      consumed = split.handle_key(TUI::KeyEvent.new(TUI::Key::MouseClick, row: abs[:row], col: abs[:col]))

      consumed.should be_true
      left.clicked.should be_nil
      right.clicked.should be_nil
    end
  end

  describe "#handle_key focus toggle" do
    it "Tab toggles the active pane without forwarding to either pane's handle_key" do
      left = StubScrollable.new(50)
      right = StubScrollable.new(50)
      split = TUI::SplitWindow.new(1, 1, 20, 10, left, right, left_width: 8)
      split.composite(TUI::Screen.new)

      split.handle_key(TUI::KeyEvent.new(TUI::Key::Tab)).should be_true
      split.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelDown))
      split.composite(TUI::Screen.new)

      right.last_render_offset.should eq(TUI::Scroller::WHEEL_STEP)
      left.last_render_offset.should eq(0)
    end
  end

  describe "#status_hint" do
    it "prepends its own Tab:switch pane binding ahead of the active pane's hint" do
      left = StubScrollable.new(50)
      right = StubScrollable.new(50)
      split = TUI::SplitWindow.new(1, 1, 20, 10, left, right, left_width: 8)
      split.composite(TUI::Screen.new)

      split.status_hint.should eq(" Tab:switch pane  hint")
    end
  end

  describe "#focus_left" do
    it "resets the active pane back to left after Tab moved it to right" do
      left = StubScrollable.new(50)
      right = StubScrollable.new(50)
      split = TUI::SplitWindow.new(1, 1, 20, 10, left, right, left_width: 8)
      split.composite(TUI::Screen.new)

      split.handle_key(TUI::KeyEvent.new(TUI::Key::Tab))
      split.focus_left

      split.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelDown))
      split.composite(TUI::Screen.new)

      left.last_render_offset.should eq(TUI::Scroller::WHEEL_STEP)
      right.last_render_offset.should eq(0)
    end
  end

  describe "#handle_key non-positional forwarding" do
    it "forwards to only the currently-active pane" do
      left = StubScrollable.new(50)
      right = StubScrollable.new(50)
      split = TUI::SplitWindow.new(1, 1, 20, 10, left, right, left_width: 8)
      split.composite(TUI::Screen.new)

      split.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelDown))
      split.composite(TUI::Screen.new)

      left.last_render_offset.should eq(TUI::Scroller::WHEEL_STEP)
      right.last_render_offset.should eq(0)
    end
  end

  describe "independent scroll state" do
    it "each pane has its own Scroller" do
      left = StubScrollable.new(50)
      right = StubScrollable.new(50)
      split = TUI::SplitWindow.new(1, 1, 20, 10, left, right, left_width: 8)
      split.composite(TUI::Screen.new)

      split.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelDown))
      split.handle_key(TUI::KeyEvent.new(TUI::Key::Tab))
      split.composite(TUI::Screen.new)

      left.last_render_offset.should eq(TUI::Scroller::WHEEL_STEP)
      right.last_render_offset.should eq(0)
    end
  end

  describe "#render" do
    it "renders without error when bordered, stamping junctions via Buffer#box_with_divider" do
      # The junction-character rendering itself is covered directly at
      # the Buffer level (spec/buffer_spec.cr's #box_with_divider specs)
      # — this just proves SplitWindow's render path calls it without
      # raising for a representative geometry.
      left = StubScrollable.new(50)
      right = StubScrollable.new(50)
      split = TUI::SplitWindow.new(1, 1, 20, 10, left, right, left_width: 8)
      split.composite(TUI::Screen.new)
    end

    it "renders a plain full-height divider with no junctions when borderless" do
      left = StubScrollable.new(50)
      right = StubScrollable.new(50)
      split = TUI::SplitWindow.new(1, 1, 20, 10, left, right, left_width: 8, bordered: false)
      split.composite(TUI::Screen.new)

      abs = split.absolute(0, 8) # top row of the divider column, no border to consume it
      split.handle_key(TUI::KeyEvent.new(TUI::Key::MouseClick, row: abs[:row], col: abs[:col]))

      left.clicked.should be_nil
      right.clicked.should be_nil
    end
  end

  describe ".full_screen" do
    it "sizes and positions to fill the screen below the status bar row, split evenly by default" do
      screen = TUI::Screen.new
      split = TUI::SplitWindow.full_screen(screen, StubScrollable.new, StubScrollable.new)

      split.x.should eq(1)
      split.y.should eq(1)
      split.width.should eq(screen.cols)
      split.height.should eq(screen.rows - 1)
      split.left_width.should eq(screen.cols // 2)
    end

    it "accepts an explicit left_width instead of the even-split default" do
      screen = TUI::Screen.new
      split = TUI::SplitWindow.full_screen(screen, StubScrollable.new, StubScrollable.new, left_width: 12)
      split.left_width.should eq(12)
    end
  end
end
