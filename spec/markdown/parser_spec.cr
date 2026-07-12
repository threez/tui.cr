require "../spec_helper"

describe TUI::Markdown::Parser do
  describe ".parse" do
    it "parses a single ATX heading into a Heading block, numbered '1'" do
      blocks = TUI::Markdown::Parser.parse("# Title")
      blocks.size.should eq(1)
      heading = blocks[0].as(TUI::Markdown::Heading)
      heading.level.should eq(1)
      heading.number.should eq("1")
      heading.runs.map(&.text).join.should eq("Title")
    end

    it "resets deeper-level counters when a shallower heading recurs" do
      blocks = TUI::Markdown::Parser.parse(<<-MD)
        # A
        ## B
        ### C
        ## D
        MD

      headings = blocks.select(TUI::Markdown::Heading)
      headings.map(&.number).should eq(["1", "1.1", "1.1.1", "1.2"])
    end

    it "does not number headings when number_headings is false" do
      blocks = TUI::Markdown::Parser.parse("# Title", number_headings: false)
      blocks[0].as(TUI::Markdown::Heading).number.should eq("")
    end

    it "parses emphasis within a paragraph into distinct InlineRun styles" do
      blocks = TUI::Markdown::Parser.parse("plain **bold** text")
      para = blocks[0].as(TUI::Markdown::Paragraph)
      para.runs.find! { |run| run.text == "bold" }.style.bold.should be_true
    end

    it "parses a nested unordered+ordered list into ListItems with correct depth/ordered/index fields" do
      blocks = TUI::Markdown::Parser.parse(<<-MD)
        1. First
        2. Second
           - Nested one
           - Nested two
        3. Third
        MD

      list = blocks[0].as(TUI::Markdown::ListBlock)
      list.items.map(&.depth).should eq([0, 0, 1, 1, 0])
      list.items.map(&.ordered?).should eq([true, true, false, false, true])
      list.items.select(&.ordered?).map(&.index).should eq([1, 2, 3])
    end

    it "parses a GFM table's delimiter row into left/center/right Align per column" do
      blocks = TUI::Markdown::Parser.parse(<<-MD)
        | A | B | C | D |
        |:--|:-:|--:|---|
        | 1 | 2 | 3 | 4 |
        MD

      table = blocks[0].as(TUI::Markdown::Table)
      table.aligns.should eq([TUI::Align::Left, TUI::Align::Center, TUI::Align::Right, TUI::Align::Left])
      table.header.map(&.map(&.text).join).should eq(["A", "B", "C", "D"])
      table.rows.size.should eq(1)
    end

    it "recognizes a fenced code block's language tag and keeps its content verbatim (not inline-parsed)" do
      blocks = TUI::Markdown::Parser.parse(<<-MD)
        ```crystal
        puts "**not bold**"
        ```
        MD

      code = blocks[0].as(TUI::Markdown::CodeBlock)
      code.language.should eq("crystal")
      code.lines.should eq(["puts \"**not bold**\""])
    end

    it "recognizes a task list item's checked/unchecked state distinctly from a plain list item" do
      blocks = TUI::Markdown::Parser.parse(<<-MD)
        - [ ] todo
        - [x] done
        - plain
        MD

      list = blocks[0].as(TUI::Markdown::ListBlock)
      list.items.map(&.checked).should eq([false, true, nil])
    end

    it "treats an hrule line as a distinct HRule block, not a heading or list item" do
      blocks = TUI::Markdown::Parser.parse("text\n\n---\n\nmore text")
      blocks.any?(TUI::Markdown::HRule).should be_true
    end

    it "parses a blockquote, tracking nesting depth" do
      blocks = TUI::Markdown::Parser.parse("> a quote")
      quote = blocks[0].as(TUI::Markdown::Blockquote)
      quote.depth.should eq(1)
      quote.runs.map(&.text).join.should eq("a quote")
    end
  end
end
