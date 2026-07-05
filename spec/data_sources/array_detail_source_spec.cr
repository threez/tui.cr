require "../spec_helper"

private record Item, name : String, size : Float64, note : String

private def sample_source : TUI::ArrayDetailSource(Item)
  items = [Item.new("apple", 1.5, "a fruit"), Item.new("bolt", 2.0, "a fastener")]
  TUI::ArrayDetailSource(Item).new(
    items,
    id_key: ->(item : Item) { item.name },
    lines: ->(item : Item) {
      [
        TUI::DetailLine.new("Name", item.name),
        TUI::DetailLine.new("Size", "#{item.size} MB"),
      ]
    },
    toggle_lines: {
      :note => ->(item : Item) { [TUI::DetailLine.new("Note", item.note)] },
    } of Symbol => (Item -> Array(TUI::DetailLine)),
    toggle_labels: {:note => "note"}
  )
end

describe TUI::ArrayDetailSource do
  it "looks up the item by id_key and reports its base lines" do
    source = sample_source
    lines = source.lines("apple", Set(Symbol).new)
    lines.map(&.label).should eq(["Name", "Size"])
    lines[1].value.text.should eq("1.5 MB")
  end

  it "returns no lines for an unknown id" do
    sample_source.lines("nonexistent", Set(Symbol).new).should be_empty
  end

  it "appends a toggle's lines only while its symbol is in expansions" do
    source = sample_source
    source.lines("bolt", Set(Symbol).new).map(&.label).should_not contain("Note")
    source.lines("bolt", Set{:note}).map(&.label).should contain("Note")
  end

  it "exposes registered toggles and their labels" do
    source = sample_source
    source.toggles.should eq([:note])
    source.toggle_label(:note).should eq("note")
  end

  it "falls back to the symbol's own name for an unregistered toggle label" do
    sample_source.toggle_label(:unregistered).should eq("unregistered")
  end

  it "titles by the raw id" do
    sample_source.title("apple").should eq("apple")
  end
end
