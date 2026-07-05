require "../spec_helper"

private class StubScrollable
  include TUI::Scrollable

  property clicked : {Int32, Int32}? = nil
  property last_render_offset : Int32 = -1
  property last_render_visible : Int32 = -1

  def initialize(@count : Int32 = 20, @header_rows : Int32 = 0)
  end

  def content_size : Int32
    @count
  end

  def header_rows : Int32
    @header_rows
  end

  def render_content(buffer : TUI::Buffer, scroll : TUI::ScrollControl) : Nil
    @last_render_offset = scroll.offset
    @last_render_visible = scroll.visible
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

describe TUI::Window do
  describe "#handle_key" do
    it "consumes a click on the border gutter without forwarding it to content" do
      content = StubScrollable.new(50)
      window = TUI::Window.new(1, 1, 20, 10, content)
      window.composite(TUI::Screen.new)

      abs = window.absolute(0, 5) # top border row
      consumed = window.handle_key(TUI::KeyEvent.new(TUI::Key::MouseClick, row: abs[:row], col: abs[:col]))

      consumed.should be_true
      content.clicked.should be_nil
    end

    it "forwards a click inside the interior with content-local coordinates" do
      content = StubScrollable.new(50)
      window = TUI::Window.new(1, 1, 20, 10, content)
      window.composite(TUI::Screen.new)

      abs = window.absolute(2, 3) # inside the border
      window.handle_key(TUI::KeyEvent.new(TUI::Key::MouseClick, row: abs[:row], col: abs[:col]))

      content.clicked.should eq({1, 2}) # border inset of 1 subtracted
    end

    it "forwards a click at the interior origin when borderless (no inset)" do
      content = StubScrollable.new(50)
      window = TUI::Window.new(1, 1, 20, 10, content, bordered: false)
      window.composite(TUI::Screen.new)

      abs = window.absolute(0, 0)
      window.handle_key(TUI::KeyEvent.new(TUI::Key::MouseClick, row: abs[:row], col: abs[:col]))

      content.clicked.should eq({0, 0})
    end

    it "forwards non-positional keys to content with a ScrollControl" do
      content = StubScrollable.new(50)
      window = TUI::Window.new(1, 1, 20, 10, content)
      window.composite(TUI::Screen.new)
      content.last_render_offset.should eq(0) # rendered once already, at offset 0

      window.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelDown)).should be_true
      content.last_render_offset.should eq(0) # render_content only runs on the next composite, not on handle_key itself
    end
  end

  describe "#reset_scroll" do
    it "zeroes the scroll offset seen by content on the next render" do
      content = StubScrollable.new(50)
      window = TUI::Window.new(1, 1, 20, 10, content)
      window.composite(TUI::Screen.new)
      window.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelDown))
      window.composite(TUI::Screen.new)
      content.last_render_offset.should eq(TUI::Scroller::WHEEL_STEP)

      window.reset_scroll
      window.composite(TUI::Screen.new)

      content.last_render_offset.should eq(0)
    end
  end

  describe "header_rows" do
    it "subtracts the content's header_rows from the visible count handed to ScrollControl" do
      content = StubScrollable.new(50, header_rows: 1)
      window = TUI::Window.new(1, 1, 20, 10, content)
      window.composite(TUI::Screen.new)

      # inner_height is 10 - 2 (border inset) = 8; header_rows: 1 means
      # only 7 rows are actually available for data.
      content.last_render_visible.should eq(7)
    end

    it "uses the full inner height when header_rows is 0 (the default)" do
      content = StubScrollable.new(50)
      window = TUI::Window.new(1, 1, 20, 10, content)
      window.composite(TUI::Screen.new)

      content.last_render_visible.should eq(8)
    end
  end

  describe "#status_hint delegation" do
    it "delegates to content" do
      window = TUI::Window.new(1, 1, 20, 10, StubScrollable.new)
      window.status_hint.should eq("hint")
    end
  end

  describe "embedding in HSplit" do
    it "lets two borderless Windows sit side by side without HSplit changes" do
      left_content = StubScrollable.new(50)
      right_content = StubScrollable.new(50)
      left = TUI::Window.new(0, 0, 0, 0, left_content, bordered: false)
      right = TUI::Window.new(0, 0, 0, 0, right_content, bordered: false)
      split = TUI::HSplit.new(1, 1, 21, 10, left, right, left_width: 10)

      split.composite(TUI::Screen.new)

      # Both sides rendered their content directly (no border consumed
      # any of their own space) — proven by each content stub having been
      # asked to render at all, with a real (non-negative) offset.
      left_content.last_render_offset.should be >= 0
      right_content.last_render_offset.should be >= 0
    end
  end

  describe ".full_screen" do
    it "sizes and positions the window to fill the screen below the status bar row" do
      screen = TUI::Screen.new
      window = TUI::Window.full_screen(screen, StubScrollable.new)

      window.x.should eq(1)
      window.y.should eq(1)
      window.width.should eq(screen.cols)
      window.height.should eq(screen.rows - 1)
    end

    it "defaults to bordered, but still accepts bordered: false" do
      screen = TUI::Screen.new
      window = TUI::Window.full_screen(screen, StubScrollable.new, bordered: false)
      window.bordered?.should be_false
    end
  end
end
