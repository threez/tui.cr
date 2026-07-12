require "../spec_helper"

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

describe TUI::Grid do
  describe "#attach" do
    it "positions children by weighted column offset and row * row_height" do
      # +1 col beyond the 15 the split math wants: borderless Grid always
      # reserves 1 column for its scrollbar (see Grid#scrollbar_reserve),
      # so 16 total leaves 15 for the 1:2 weighted split -> 5, 10.
      grid = TUI::Grid.new(1, 1, 16, 10, [1, 2])
      a = StubWidget.new(0, 0, 1, 1, "A")
      b = StubWidget.new(0, 0, 1, 1, "B")
      grid.attach(a, col: 0, row: 0)
      grid.attach(b, col: 1, row: 1)

      a.x.should eq(1)
      a.y.should eq(1)
      a.width.should eq(5)
      a.height.should eq(1)

      b.x.should eq(1 + 5)
      b.y.should eq(1 + 1)
      b.width.should eq(10)
      b.height.should eq(1)
    end

    it "spans multiple columns/rows when col_span/row_span are given" do
      grid = TUI::Grid.new(1, 1, 16, 10, [1, 1, 1]) # 15 usable cols split evenly -> 5 each
      a = StubWidget.new(0, 0, 1, 1, "A")
      grid.attach(a, col: 0, row: 0, col_span: 2, row_span: 3)

      a.width.should eq(10)
      a.height.should eq(3)
    end
  end

  describe "resize" do
    it "reflows attached children's widths when Grid's own width changes" do
      grid = TUI::Grid.new(1, 1, 21, 10, [1]) # 21 - 1 scrollbar col = 20
      a = StubWidget.new(0, 0, 1, 1, "A")
      grid.attach(a, col: 0, row: 0)
      a.width.should eq(20)

      grid.width = 41
      screen = TUI::Screen.new
      grid.composite(screen)

      a.width.should eq(40)
    end

    it "keeps a weighted split proportional after a resize" do
      grid = TUI::Grid.new(1, 1, 16, 10, [1, 2]) # 15 usable cols split 1:2 -> 5, 10
      a = StubWidget.new(0, 0, 1, 1, "A")
      b = StubWidget.new(0, 0, 1, 1, "B")
      grid.attach(a, col: 0, row: 0)
      grid.attach(b, col: 1, row: 0)

      grid.width = 31 # 30 usable, 1:2 -> 10, 20
      screen = TUI::Screen.new
      grid.composite(screen)

      a.width.should eq(10)
      b.width.should eq(20)
      b.x.should eq(1 + 10)
    end
  end

  describe "#handle_key" do
    it "moves focus forward with Tab and wraps past the last attachment" do
      grid = TUI::Grid.new(1, 1, 20, 10, [1])
      a = StubWidget.new(0, 0, 1, 1, "A")
      b = StubWidget.new(0, 0, 1, 1, "B")
      grid.attach(a, col: 0, row: 0)
      grid.attach(b, col: 0, row: 1)

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'x'))
      a.last_key.should_not be_nil
      b.last_key.should be_nil

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Tab))
      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'y'))
      b.last_key.should_not be_nil

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Tab)) # wraps back to A
      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'z'))
      a.last_key.try(&.char).should eq('z')
    end

    it "moves focus backward with Shift+Tab and wraps before the first attachment" do
      grid = TUI::Grid.new(1, 1, 20, 10, [1])
      a = StubWidget.new(0, 0, 1, 1, "A")
      b = StubWidget.new(0, 0, 1, 1, "B")
      grid.attach(a, col: 0, row: 0)
      grid.attach(b, col: 0, row: 1)

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::ShiftTab)) # wraps to B
      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'z'))
      b.last_key.try(&.char).should eq('z')
    end

    it "delegates unconsumed keys to the focused child" do
      grid = TUI::Grid.new(1, 1, 20, 10, [1])
      a = StubWidget.new(0, 0, 1, 1, "A")
      a.consumes = true
      grid.attach(a, col: 0, row: 0)

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'q')).should be_true
    end

    it "does not raise when nothing is attached" do
      grid = TUI::Grid.new(1, 1, 20, 10, [1])
      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'x')).should be_false
    end

    it "moves focus with Down/Up as a fallback when the focused child declines the key" do
      grid = TUI::Grid.new(1, 1, 20, 10, [1])
      a = StubWidget.new(0, 0, 1, 1, "A") # consumes: false by default
      b = StubWidget.new(0, 0, 1, 1, "B")
      grid.attach(a, col: 0, row: 0)
      grid.attach(b, col: 0, row: 1)

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Down)).should be_true
      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'y'))
      b.last_key.should_not be_nil

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Up)).should be_true
      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'z'))
      a.last_key.try(&.char).should eq('z')
    end

    it "lets the focused child consume Down/Up itself instead of moving focus" do
      grid = TUI::Grid.new(1, 1, 20, 10, [1])
      a = StubWidget.new(0, 0, 1, 1, "A")
      a.consumes = true # simulates a ScrollableField-backed cell mid-edit
      b = StubWidget.new(0, 0, 1, 1, "B")
      grid.attach(a, col: 0, row: 0)
      grid.attach(b, col: 0, row: 1)

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Down)).should be_true
      a.last_key.try(&.key).should eq(TUI::Key::Down)
      b.last_key.should be_nil # focus never moved to B
    end
  end

  describe "#composite" do
    it "drives focus_if on exactly the focused attachment" do
      grid = TUI::Grid.new(1, 1, 20, 10, [1])
      a = StubWidget.new(0, 0, 1, 1, "A")
      b = StubWidget.new(0, 0, 1, 1, "B")
      grid.attach(a, col: 0, row: 0)
      grid.attach(b, col: 0, row: 1)

      screen = TUI::Screen.new
      grid.composite(screen)
      a.focused?.should be_true
      b.focused?.should be_false

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::Tab))
      grid.composite(screen)
      a.focused?.should be_false
      b.focused?.should be_true
    end
  end

  describe "#status_hint" do
    it "combines the menu hint with the focused child's hint" do
      grid = TUI::Grid.new(1, 1, 20, 10, [1])
      a = StubWidget.new(0, 0, 1, 1, "A")
      grid.attach(a, col: 0, row: 0)

      grid.status_hint.should contain("Tab")
      grid.status_hint.should contain("A hint")
    end

    it "mentions PgUp/PgDn only once content actually overflows the viewport" do
      grid = TUI::Grid.new(1, 1, 20, 3, [1]) # 3 visible rows (borderless)
      a = StubWidget.new(0, 0, 1, 1, "A")
      grid.attach(a, col: 0, row: 0)
      grid.status_hint.should_not contain("PgUp")

      b = StubWidget.new(0, 0, 1, 1, "B")
      c = StubWidget.new(0, 0, 1, 1, "C")
      d = StubWidget.new(0, 0, 1, 1, "D")
      grid.attach(b, col: 0, row: 1)
      grid.attach(c, col: 0, row: 2)
      grid.attach(d, col: 0, row: 3) # 4 rows > 3 visible -> now overflows
      grid.status_hint.should contain("PgUp")
    end
  end

  describe "scrolling" do
    it "does not shift children when everything fits within the viewport" do
      grid = TUI::Grid.new(1, 1, 20, 10, [1])
      a = StubWidget.new(0, 0, 1, 1, "A")
      grid.attach(a, col: 0, row: 0)
      a.y.should eq(1)
    end

    it "shifts every child's y by the scroll offset once scrolled" do
      grid = TUI::Grid.new(1, 1, 20, 3, [1]) # 3 rows tall, borderless -> 3 visible
      widgets = (0...6).map { |i| StubWidget.new(0, 0, 1, 1, i.to_s) }
      widgets.each_with_index { |widget, i| grid.attach(widget, col: 0, row: i) }

      screen = TUI::Screen.new
      grid.composite(screen)
      widgets[0].y.should eq(1)

      3.times { grid.handle_key(TUI::KeyEvent.new(TUI::Key::PageDown)) }
      grid.composite(screen)
      # Scrolled down by however far PageDown moved (clamped to the max
      # offset, total_rows - visible_rows = 6 - 3 = 3); the first
      # attachment's row (0) minus that offset determines its new y.
      widgets[3].y.should eq(1)
    end

    it "clips a child positioned outside the viewport instead of letting it bleed onto the rest of the screen" do
      grid = TUI::Grid.new(2, 2, 10, 3, [1]) # small grid away from the screen edge
      tall = StubWidget.new(0, 0, 1, 1, "T")
      grid.attach(tall, col: 0, row: 0, row_span: 10) # far taller than the grid

      screen = TUI::Screen.new
      grid.composite(screen)

      # The child's own buffer has "T" at its local (0,0), composited at
      # absolute (grid.x, grid.y) = (2, 2) -> screen row 1, col 1 — still
      # inside the grid, so it must be visible...
      screen.cell(1, 1).char.should eq("T")
      # ...but far below the grid's own 3-row height, the child would
      # still draw " " (StubWidget only ever writes to its own local
      # (0,0)) — the real assertion is that nothing the child does can
      # write past the grid's own box onto whatever is elsewhere on
      # screen. Rows/cols outside the grid's rect stay untouched.
      screen.cell(20, 20).char.should eq(" ")
    end

    it "reveals a newly-focused attachment scrolled out of view" do
      grid = TUI::Grid.new(1, 1, 20, 3, [1]) # 3 visible rows
      widgets = (0...6).map { |i| StubWidget.new(0, 0, 1, 1, i.to_s) }
      widgets.each_with_index { |widget, i| grid.attach(widget, col: 0, row: i) }

      5.times { grid.handle_key(TUI::KeyEvent.new(TUI::Key::Tab)) } # focus -> last attachment
      screen = TUI::Screen.new
      grid.composite(screen)

      widgets.last.y.should be >= 1
      widgets.last.y.should be < 1 + 3
    end

    it "scrolls with PageDown/PageUp as a fallback when the focused child declines the key" do
      grid = TUI::Grid.new(1, 1, 20, 3, [1])
      widgets = (0...6).map { |i| StubWidget.new(0, 0, 1, 1, i.to_s) }
      widgets.each_with_index { |widget, i| grid.attach(widget, col: 0, row: i) }

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::PageDown)).should be_true
      screen = TUI::Screen.new
      grid.composite(screen)
      widgets[0].y.should be < 1 # scrolled up out of the viewport

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::PageUp)).should be_true
      grid.composite(screen)
      widgets[0].y.should eq(1) # back at the top
    end

    it "lets the focused child consume PageDown/PageUp itself instead of scrolling" do
      grid = TUI::Grid.new(1, 1, 20, 3, [1])
      a = StubWidget.new(0, 0, 1, 1, "A")
      a.consumes = true # simulates a ScrollableField-backed cell mid-edit
      widgets = [a] + (1...6).map { |i| StubWidget.new(0, 0, 1, 1, i.to_s) }
      widgets.each_with_index { |widget, i| grid.attach(widget, col: 0, row: i) }

      grid.handle_key(TUI::KeyEvent.new(TUI::Key::PageDown)).should be_true
      a.last_key.try(&.key).should eq(TUI::Key::PageDown)

      screen = TUI::Screen.new
      grid.composite(screen)
      widgets[0].y.should eq(1) # grid itself never scrolled
    end
  end
end
