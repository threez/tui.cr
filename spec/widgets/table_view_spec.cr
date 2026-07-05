require "../spec_helper"

private class StubTableSource < TUI::TableDataSource
  def initialize(@count : Int32 = 20)
  end

  def columns : Array(TUI::TableColumn)
    [TUI::TableColumn.new("Name", 4, 10, expand: true)]
  end

  def size : Int32
    @count
  end

  def row(index : Int32) : TUI::TableRow
    TUI::TableRow.new(cells: [TUI::Cell.new("item-#{index}")])
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

private class ColoredTableSource < TUI::TableDataSource
  def initialize(@count : Int32 = 20)
  end

  def columns : Array(TUI::TableColumn)
    [TUI::TableColumn.new("Name", 4, 10, expand: true)]
  end

  def size : Int32
    @count
  end

  def row(index : Int32) : TUI::TableRow
    TUI::TableRow.new(cells: [TUI::Cell.new("item-#{index}", style: TUI::Style.new(fg: TUI.color(:green)))])
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

private class AlignedTableSource < TUI::TableDataSource
  def initialize(@align : TUI::Align)
  end

  def columns : Array(TUI::TableColumn)
    [TUI::TableColumn.new("Hdr", 5, 5, align: @align)]
  end

  def size : Int32
    1
  end

  def row(index : Int32) : TUI::TableRow
    TUI::TableRow.new(cells: [TUI::Cell.new("hi")])
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

private class MultiColumnTableSource < TUI::TableDataSource
  def columns : Array(TUI::TableColumn)
    [
      TUI::TableColumn.new("Name", 8, 26, expand: true),
      TUI::TableColumn.new("Version", 8, 16),
      TUI::TableColumn.new("Size", 6, 10, align: TUI::Align::Right),
      TUI::TableColumn.new("Origin", 8, 30),
    ]
  end

  def size : Int32
    1
  end

  def row(index : Int32) : TUI::TableRow
    TUI::TableRow.new(cells: [
      TUI::Cell.new("ImageMagick7"),
      TUI::Cell.new("7.1.2.24"),
      TUI::Cell.new("29.7 M"),
      TUI::Cell.new("graphics/ImageMagick7"),
    ])
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

private def click(list : TUI::TableView, row : Int32, col : Int32) : Bool
  list.handle_click(row, col, scroll)
end

describe TUI::TableView do
  describe "mouse click" do
    it "selects the clicked row without activating it" do
      activated = false
      list = TUI::TableView.new(StubTableSource.new)
      list.reload
      list.on_activate = ->(_index : Int32) { activated = true; nil }

      click(list, 2, 5) # header at row 0, so row 2 -> content index 1 (row_at: idx = 0 + (2 - 1))

      list.selected_index.should eq(1)
      activated.should be_false
    end

    it "activates on a second click within the double-click threshold" do
      activated_index = nil.as(Int32?)
      list = TUI::TableView.new(StubTableSource.new)
      list.reload
      list.on_activate = ->(index : Int32) { activated_index = index; nil }

      click(list, 2, 5)
      click(list, 2, 5)

      activated_index.should eq(1)
    end

    it "does not activate on two clicks spaced beyond the threshold" do
      activated = false
      list = TUI::TableView.new(StubTableSource.new)
      list.reload
      list.on_activate = ->(_index : Int32) { activated = true; nil }

      click(list, 2, 5)
      sleep 500.milliseconds
      click(list, 2, 5)

      activated.should be_false
    end

    it "does not activate when the second click lands on a different row" do
      activated = false
      list = TUI::TableView.new(StubTableSource.new)
      list.reload
      list.on_activate = ->(_index : Int32) { activated = true; nil }

      click(list, 2, 5)
      click(list, 3, 5)

      activated.should be_false
    end

    it "selects without exiting filter mode, but a double-click exits it" do
      list = TUI::TableView.new(StubTableSource.new)
      list.reload
      list.handle_key(TUI::KeyEvent.new(TUI::Key::Char, '/'), scroll)

      click(list, 2, 5)
      list.status_hint.should contain("Type to filter")

      click(list, 2, 5)
      list.status_hint.should_not contain("Type to filter")
    end
  end

  describe "#render_content" do
    it "keeps a cell's own color when its row is the cursor row and focused" do
      list = TUI::TableView.new(ColoredTableSource.new)
      list.reload
      list.focus_if(true)

      buffer = TUI::Buffer.new(20, 10)
      list.render_content(buffer, scroll)

      # row 0 is the cursor row (content_row_offset 1 for the header)
      cell = buffer.cell(1, 3)                      # past " ▸" pointer prefix, into the cell text
      cell.style.should contain("\e[32m")           # green survives
      cell.style.should contain(TUI::Term::REVERSE) # cursor highlight also present
    end

    it "keeps a cell's own color when its row is the cursor row but unfocused (bold highlight)" do
      list = TUI::TableView.new(ColoredTableSource.new)
      list.reload
      list.focus_if(false)

      buffer = TUI::Buffer.new(20, 10)
      list.render_content(buffer, scroll)

      cell = buffer.cell(1, 3)
      cell.style.should contain("\e[32m")
      cell.style.should contain(TUI::Term::BOLD)
    end

    it "keeps a cell's own color on non-cursor rows too" do
      list = TUI::TableView.new(ColoredTableSource.new)
      list.reload
      list.handle_key(TUI::KeyEvent.new(TUI::Key::Down), scroll) # cursor -> row 1, row 0 no longer selected

      buffer = TUI::Buffer.new(20, 10)
      list.render_content(buffer, scroll)

      cell = buffer.cell(1, 3)
      cell.style.should contain("\e[32m")
    end
  end

  describe "column alignment" do
    it "left-aligns by default: header and data flush against the column's left edge" do
      list = TUI::TableView.new(AlignedTableSource.new(TUI::Align::Left))
      list.reload

      buffer = TUI::Buffer.new(20, 10)
      list.render_content(buffer, scroll)

      buffer.cell(0, 2).char.should eq("H")
      buffer.cell(1, 2).char.should eq("h")
      buffer.cell(1, 3).char.should eq("i")
      buffer.cell(1, 4).char.should eq(" ")
    end

    it "right-aligns: header and data flush against the column's right edge" do
      list = TUI::TableView.new(AlignedTableSource.new(TUI::Align::Right))
      list.reload

      buffer = TUI::Buffer.new(20, 10)
      list.render_content(buffer, scroll)

      buffer.cell(0, 4).char.should eq("H")
      buffer.cell(1, 5).char.should eq("h")
      buffer.cell(1, 6).char.should eq("i")
    end

    it "center-aligns: header and data padded on both sides" do
      list = TUI::TableView.new(AlignedTableSource.new(TUI::Align::Center))
      list.reload

      buffer = TUI::Buffer.new(20, 10)
      list.render_content(buffer, scroll)

      buffer.cell(0, 3).char.should eq("H")
      buffer.cell(1, 3).char.should eq("h")
      buffer.cell(1, 4).char.should eq("i")
    end
  end

  describe "row width accounting" do
    it "does not truncate the last column when its content comfortably fits its preferred width" do
      list = TUI::TableView.new(MultiColumnTableSource.new)
      list.reload

      # 120-wide buffer, matching a realistic terminal — regression test
      # for an off-by-one in render_header's `available` calc that
      # reserved only 1 of the 2 leading prefix chars every row carries
      # (" " + pointer), silently truncating the last column on every
      # row even though there was ample room.
      buffer = TUI::Buffer.new(120, 10)
      list.render_content(buffer, scroll)

      line = (0...120).map { |col| buffer.cell(1, col).char }.join
      line.should contain("graphics/ImageMagick7")
      line.should_not contain("…")
    end
  end

  describe "hosted in a Window (header row accounted for in scroll math)" do
    it "keeps the cursor marker visible after wheel-scrolling to the bottom edge" do
      # Regression test: TableView reserves row 0 for its header
      # (`scroll header: 1`), so only `inner_height - 1` rows are
      # actually drawable — but Window used to hand ScrollControl the
      # raw inner_height, letting the cursor scroll one row past what
      # render_content could draw, so it silently vanished off-screen.
      list = TUI::TableView.new(StubTableSource.new(50))
      window = TUI::Window.new(1, 1, 20, 10, list)
      window.focus_if(true)
      window.composite(TUI::Screen.new)

      40.times { window.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelDown)) }
      screen = TUI::Screen.new
      window.composite(screen)

      rows = (0...10).map { |row| (0...20).map { |col| screen.cell(row, col).char }.join }
      rows.any?(&.includes?("▸")).should be_true
    end
  end
end
