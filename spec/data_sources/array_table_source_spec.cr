require "../spec_helper"

private record Item, name : String, size : Float64

private def sample_source : TUI::ArrayTableSource(Item)
  items = [Item.new("banana", 2.0), Item.new("apple", 3.0), Item.new("cherry", 1.0)]
  TUI::ArrayTableSource(Item).new(
    items,
    title: "Items",
    columns: [TUI::TableColumn.new("Name", 4, 10, expand: true)],
    filter_text: ->(item : Item) { item.name },
    row: ->(item : Item) { TUI::TableRow.new(cells: [TUI::Cell.new(item.name)]) },
    sort_keys: {
      :name => ->(a : Item, b : Item) { a.name <=> b.name || 0 },
      :size => ->(a : Item, b : Item) { a.size <=> b.size || 0 },
    } of Symbol => (Item, Item) -> Int32
  )
end

describe TUI::ArrayTableSource do
  it "shows every item unfiltered by default" do
    source = sample_source
    source.reload("", :name)
    source.size.should eq(3)
  end

  it "filters by substring match via the filter_text proc" do
    source = sample_source
    source.reload("an", :name)
    source.size.should eq(1)
    source.item_at(0).name.should eq("banana")
  end

  it "sorts using the comparator registered under the given symbol" do
    source = sample_source
    source.reload("", :name)
    source.item_at(0).name.should eq("apple")
    source.item_at(1).name.should eq("banana")
    source.item_at(2).name.should eq("cherry")
  end

  it "sorts by a different key when asked" do
    source = sample_source
    source.reload("", :size)
    source.item_at(0).size.should eq(1.0)
    source.item_at(1).size.should eq(2.0)
    source.item_at(2).size.should eq(3.0)
  end

  it "falls back to unsorted order for an unregistered sort key" do
    source = sample_source
    source.reload("", :nonexistent)
    source.size.should eq(3)
    source.item_at(0).name.should eq("banana")
  end

  it "exposes the registered sort_keys" do
    source = sample_source
    source.sort_keys.should eq([:name, :size])
  end

  it "builds table rows via the row proc" do
    source = sample_source
    source.reload("", :name)
    source.row(0).cells.first.text.should eq("apple")
  end

  it "reports the title, with the filter appended once non-empty" do
    source = sample_source
    source.title("", :name).should eq("Items")
    source.title("an", :name).should contain("filter: an")
  end
end
