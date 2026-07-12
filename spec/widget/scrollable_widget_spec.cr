require "../spec_helper"

private class StubWidget < TUI::Widget
  property last_key : TUI::KeyEvent? = nil
  property rendered_size : {Int32, Int32}? = nil

  def render : Nil
    @rendered_size = {width, height}
    @buffer.set(0, 0, "hi")
  end

  def handle_key(ev : TUI::KeyEvent) : Bool
    @last_key = ev
    true
  end

  def status_hint : String
    "widget-hint"
  end
end

describe TUI::ScrollableWidget do
  it "draws the wrapped widget's own render output into the host buffer" do
    widget = StubWidget.new(0, 0, 0, 0)
    adapter = TUI::ScrollableWidget.new(widget)

    buffer = TUI::Buffer.new(5, 3)
    adapter.render_content(buffer, TUI::ScrollControl.new(TUI::Scroller.new, 3))

    widget.rendered_size.should eq({5, 3})
    buffer.cell(0, 0).char.should eq("h")
    buffer.cell(0, 1).char.should eq("i")
  end

  it "forwards non-positional keys directly to the wrapped widget" do
    widget = StubWidget.new(0, 0, 0, 0)
    adapter = TUI::ScrollableWidget.new(widget)

    ev = TUI::KeyEvent.new(TUI::Key::Char, 'x')
    adapter.handle_key(ev, TUI::ScrollControl.new(TUI::Scroller.new, 3)).should be_true
    widget.last_key.should eq(ev)
  end

  it "translates a click's local coordinates into the widget's own absolute space" do
    widget = StubWidget.new(0, 0, 0, 0)
    adapter = TUI::ScrollableWidget.new(widget)
    buffer = TUI::Buffer.new(5, 3)
    adapter.render_content(buffer, TUI::ScrollControl.new(TUI::Scroller.new, 3)) # sets widget.x/y to 0,0

    adapter.handle_click(1, 2, TUI::ScrollControl.new(TUI::Scroller.new, 3))

    widget.last_key.should_not be_nil
    key = widget.last_key.as(TUI::KeyEvent)
    key.key.should eq(TUI::Key::MouseClick)
    key.row.should eq(1)
    key.col.should eq(2)
  end

  it "delegates status_hint and title to the wrapped widget/constructor argument" do
    widget = StubWidget.new(0, 0, 0, 0)
    adapter = TUI::ScrollableWidget.new(widget, title: "Pane")

    adapter.status_hint.should eq("widget-hint")
    adapter.title.should eq("Pane")
  end

  it "hosts as a SplitWindow pane alongside a plain Scrollable" do
    widget = StubWidget.new(0, 0, 0, 0)
    left = TUI::ScrollableWidget.new(widget, title: "Left")
    split = TUI::SplitWindow.new(1, 1, 21, 10, left, StubRightScrollable.new, left_width: 10)

    split.render

    widget.rendered_size.should_not be_nil
  end
end

private class StubRightScrollable
  include TUI::Scrollable

  def content_size : Int32
    10
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
    "Right"
  end

  def status_hint : String
    ""
  end
end
