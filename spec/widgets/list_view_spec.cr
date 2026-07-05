require "../spec_helper"

# ListView is abstract — no real app consumes it directly today (pkgx uses
# TableView, the only concrete subclass). This stub exists purely to
# exercise the base's scroll/cursor/filter/click machinery in isolation
# from any column concept.
private class PlainListView < TUI::ListView
  def row_content(index : Int32) : String
    "item-#{index}"
  end
end

private class PlainListSource < TUI::ListDataSource
  def initialize(@count : Int32 = 20)
  end

  def size : Int32
    @count
  end

  def title(filter : String, sort_key : Symbol) : String
    "Stub"
  end

  def sort_keys : Array(Symbol)
    [:name]
  end

  def reload(filter : String, sort : Symbol) : Nil
  end
end

private def scroll(visible = 15) : TUI::ScrollControl
  TUI::ScrollControl.new(TUI::Scroller.new, visible)
end

describe TUI::ListView do
  it "moves the cursor with Up/Down" do
    list = PlainListView.new(PlainListSource.new)
    list.reload

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Down), scroll)
    list.selected_index.should eq(1)

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Up), scroll)
    list.selected_index.should eq(0)
  end

  it "enters and exits filter mode" do
    list = PlainListView.new(PlainListSource.new)
    list.reload

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Char, '/'), scroll)
    list.status_hint.should contain("Type to filter")

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Esc), scroll)
    list.status_hint.should_not contain("Type to filter")
  end

  it "selects a row via a mouse click" do
    list = PlainListView.new(PlainListSource.new)
    list.reload

    list.handle_click(3, 5, scroll)

    list.selected_index.should eq(3)
  end

  describe "#status_hint" do
    it "does not claim bindings ListView itself never implements" do
      list = PlainListView.new(PlainListSource.new)
      list.reload

      hint = list.status_hint
      hint.should_not contain("Tab")
      hint.should_not contain("q:quit")
      hint.should_not contain("Enter:detail")
    end
  end

  describe "mouse wheel scrolling" do
    it "keeps the cursor within the visible window after wheel-down at the bottom edge" do
      list = PlainListView.new(PlainListSource.new(20))
      list.reload
      scroller = TUI::Scroller.new
      ctl = TUI::ScrollControl.new(scroller, 15)

      # Enough wheel-down ticks to run past the bottom of a 20-row list
      # with a 15-row viewport (max offset 5) — the cursor must never
      # land outside [offset, offset + visible).
      10.times { list.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelDown), ctl) }

      cursor = list.selected_index
      cursor.should_not be_nil
      if cursor
        offset = scroller.offset
        cursor.should be >= offset
        cursor.should be < offset + 15
      end
    end

    it "keeps the cursor within the visible window after wheel-up at the top edge" do
      list = PlainListView.new(PlainListSource.new(20))
      list.reload
      scroller = TUI::Scroller.new
      ctl = TUI::ScrollControl.new(scroller, 15)

      10.times { list.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelUp), ctl) }

      cursor = list.selected_index
      cursor.should_not be_nil
      if cursor
        offset = scroller.offset
        cursor.should be >= offset
        cursor.should be < offset + 15
      end
    end
  end

  it "Tab is not consumed (no dead mode-toggle hook)" do
    list = PlainListView.new(PlainListSource.new)
    list.reload

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Tab), scroll).should be_false
  end

  describe "bare Enter (no filter active)" do
    it "fires on_activate with the current cursor index" do
      list = PlainListView.new(PlainListSource.new)
      list.reload
      activated = nil.as(Int32?)
      list.on_activate = ->(index : Int32) { activated = index; nil }

      list.handle_key(TUI::KeyEvent.new(TUI::Key::Down), scroll)
      list.handle_key(TUI::KeyEvent.new(TUI::Key::Enter), scroll).should be_true

      activated.should eq(1)
    end

    it "consumes Enter even with no on_activate set" do
      list = PlainListView.new(PlainListSource.new)
      list.reload

      list.handle_key(TUI::KeyEvent.new(TUI::Key::Enter), scroll).should be_true
    end
  end
end
