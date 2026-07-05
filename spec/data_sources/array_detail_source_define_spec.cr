require "../spec_helper"

private record DefineDetailItem, name : String, size : Float64, note : String

private DEFINE_DETAIL_ITEMS = [
  DefineDetailItem.new("apple", 1.5, "a fruit"),
  DefineDetailItem.new("bolt", 2.0, "a fastener"),
]

TUI::ArrayDetailSource.define(DEFINE_DETAIL_SOURCE, DefineDetailItem, DEFINE_DETAIL_ITEMS) do
  id_key :name
  line :name, "Name"
  line :size, "Size", suffix: " MB"
  toggle :note, "note" do
    line :note, "Note"
  end
end

describe "TUI::ArrayDetailSource.define" do
  it "looks up the item by id_key and reports its base lines" do
    lines = DEFINE_DETAIL_SOURCE.lines("apple", Set(Symbol).new)
    lines.map(&.label).should eq(["Name", "Size"])
    lines[1].value.text.should eq("1.5 MB")
  end

  it "returns no lines for an unknown id" do
    DEFINE_DETAIL_SOURCE.lines("nonexistent", Set(Symbol).new).should be_empty
  end

  it "appends a toggle's lines only while its symbol is in expansions" do
    DEFINE_DETAIL_SOURCE.lines("bolt", Set(Symbol).new).map(&.label).should_not contain("Note")
    DEFINE_DETAIL_SOURCE.lines("bolt", Set{:note}).map(&.label).should contain("Note")
  end

  it "registers toggles and their labels" do
    DEFINE_DETAIL_SOURCE.toggles.should eq([:note])
    DEFINE_DETAIL_SOURCE.toggle_label(:note).should eq("note")
  end

  it "titles by the raw id" do
    DEFINE_DETAIL_SOURCE.title("apple").should eq("apple")
  end

  it "drives a real DetailView end-to-end" do
    view = TUI::DetailView.new(DEFINE_DETAIL_SOURCE)
    view.load("apple")
    view.status_hint.should contain("note")
  end
end
