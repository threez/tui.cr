require "../spec_helper"

private record DefineItem, name : String, size : Float64, active : Bool

TUI::ArrayTableSource.define(DefineItemSourceBuilder, DefineItem) do
  title "Items"
  filter_by :name
  column :name, "Name", width: 4..10, expand: true, sort: true
  column :size, "Size", width: 4..10, align: :right, sort: true
  column :active, "Active", width: 4..8
end

private def sample_source : TUI::ArrayTableSource(DefineItem)
  items = [
    DefineItem.new("banana", 2.0, true),
    DefineItem.new("apple", 3.0, false),
    DefineItem.new("cherry", 1.0, true),
  ]
  DefineItemSourceBuilder.build(items)
end

describe "TUI::ArrayTableSource.define" do
  it "shows every item unfiltered by default" do
    source = sample_source
    source.reload("", :name)
    source.size.should eq(3)
  end

  it "filters by substring match via the filter_by property" do
    source = sample_source
    source.reload("an", :name)
    source.size.should eq(1)
    source.item_at(0).name.should eq("banana")
  end

  it "sorts using the comparator registered for a sort: true column" do
    source = sample_source
    source.reload("", :name)
    source.item_at(0).name.should eq("apple")
    source.item_at(1).name.should eq("banana")
    source.item_at(2).name.should eq("cherry")
  end

  it "sorts a Float64 column numerically, not lexicographically" do
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

  it "only lists sort_keys for columns declared with sort: true" do
    source = sample_source
    source.sort_keys.should eq([:name, :size])
  end

  it "builds table rows via the generated row proc" do
    source = sample_source
    source.reload("", :name)
    source.row(0).cells.first.text.should eq("apple")
  end

  it "reports the title, with the filter appended once non-empty" do
    source = sample_source
    source.title("", :name).should eq("Items")
    source.title("an", :name).should contain("filter: an")
  end

  it "styles a Float64 column's cell like TypeStyle.for(\"float64\", \"\") would" do
    source = sample_source
    source.reload("", :name)
    source.row(0).cells[1].style.should eq(TUI::TypeStyle.for("float64", ""))
  end

  it "styles a Bool column's cell like TypeStyle.for(\"bool\", \"\") would" do
    source = sample_source
    source.reload("", :name)
    source.row(0).cells[2].style.should eq(TUI::TypeStyle.for("bool", ""))
  end
end
