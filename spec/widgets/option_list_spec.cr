require "../spec_helper"

private def scroll(visible = 15) : TUI::ScrollControl
  TUI::ScrollControl.new(TUI::Scroller.new, visible)
end

private def sample_options : Array(TUI::FormEnumOption)
  [
    TUI::FormEnumOption.new("Alpha", "alpha"),
    TUI::FormEnumOption.new("Beta", "beta"),
    TUI::FormEnumOption.new("Gamma", "gamma"),
  ]
end

describe TUI::OptionListSource do
  it "filters by substring match on label, case-insensitively" do
    source = TUI::OptionListSource.new("Pick", sample_options)
    source.reload("BE", :name)
    source.size.should eq(1)
    source.option_at(0).label.should eq("Beta")
  end

  it "shows the filter in the title once non-empty" do
    source = TUI::OptionListSource.new("Pick", sample_options)
    source.title("", :name).should eq("Pick")
    source.title("a", :name).should contain("filter: a")
  end
end

describe TUI::OptionListView do
  it "seeds the cursor at the given initial index via #seek" do
    source = TUI::OptionListSource.new("Pick", sample_options)
    list = TUI::OptionListView.new(source)
    list.reload
    list.seek(2)
    list.selected_index.should eq(2)
  end

  it "fires on_activate with the picked option's index on Enter" do
    source = TUI::OptionListSource.new("Pick", sample_options)
    list = TUI::OptionListView.new(source)
    list.reload
    picked = nil.as(Int32?)
    list.on_activate = ->(index : Int32) { picked = index; nil }

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Down), scroll)
    list.handle_key(TUI::KeyEvent.new(TUI::Key::Enter), scroll)

    picked.should eq(1)
  end

  it "picking after a filter reports an index relative to the FILTERED list, resolved via option_source" do
    # Regression test: on_activate's index is only meaningful against
    # whatever's currently filtered — a caller that indexes its own
    # original (unfiltered) options array directly with this index picks
    # the wrong option once a filter has narrowed the visible rows. The
    # correct resolution is always list.option_source.option_at(index).
    source = TUI::OptionListSource.new("Pick", sample_options)
    list = TUI::OptionListView.new(source)
    list.reload
    picked = nil.as(String?)
    list.on_activate = ->(index : Int32) { picked = list.option_source.option_at(index).wire_value; nil }

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Char, '/'), scroll)
    list.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'g'), scroll) # filters to just "Gamma"
    list.handle_key(TUI::KeyEvent.new(TUI::Key::Enter), scroll)     # filter-mode Enter fires on_activate directly

    picked.should eq("gamma")
  end
end

describe TUI::MultiOptionListView do
  it "seeds the initial selected set by wire_value" do
    source = TUI::OptionListSource.new("Pick", sample_options)
    list = TUI::MultiOptionListView.new(source, Set{"alpha", "gamma"})
    list.reload
    list.selected_wire_values.should eq(Set{"alpha", "gamma"})
  end

  it "toggles the focused row with Space, independent of cursor movement" do
    source = TUI::OptionListSource.new("Pick", sample_options)
    list = TUI::MultiOptionListView.new(source)
    list.reload

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Down), scroll)
    list.handle_key(TUI::KeyEvent.new(TUI::Key::Char, ' '), scroll)
    list.selected_wire_values.should eq(Set{"beta"})

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Char, ' '), scroll)
    list.selected_wire_values.should eq(Set(String).new)
  end

  it "fires on_confirm with the whole selected set on Enter, not per-row activation" do
    source = TUI::OptionListSource.new("Pick", sample_options)
    list = TUI::MultiOptionListView.new(source)
    list.reload
    confirmed = nil.as(Set(String)?)
    list.on_confirm = ->(selected : Set(String)) { confirmed = selected; nil }

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Char, ' '), scroll)
    list.handle_key(TUI::KeyEvent.new(TUI::Key::Down), scroll)
    list.handle_key(TUI::KeyEvent.new(TUI::Key::Char, ' '), scroll)
    list.handle_key(TUI::KeyEvent.new(TUI::Key::Enter), scroll)

    confirmed.should eq(Set{"alpha", "beta"})
  end

  it "still supports Up/Down/filter navigation via the inherited base behavior" do
    source = TUI::OptionListSource.new("Pick", sample_options)
    list = TUI::MultiOptionListView.new(source)
    list.reload

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Down), scroll)
    list.selected_index.should eq(1)
  end

  it "toggles the correct option by identity even after filtering shifts indices" do
    # Regression test: a filtered row's index is only meaningful within
    # the currently-filtered list, never a stable identity — toggling by
    # raw index against an unfiltered options array would silently
    # select the wrong option once a filter narrows the visible rows.
    source = TUI::OptionListSource.new("Pick", sample_options)
    list = TUI::MultiOptionListView.new(source)
    list.reload

    list.handle_key(TUI::KeyEvent.new(TUI::Key::Char, '/'), scroll)
    list.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'g'), scroll) # filters to just "Gamma", index 0 of the filtered list
    list.handle_key(TUI::KeyEvent.new(TUI::Key::Enter), scroll)     # exits filter mode, keeps the narrowed filter
    list.handle_key(TUI::KeyEvent.new(TUI::Key::Char, ' '), scroll)

    list.selected_wire_values.should eq(Set{"gamma"})
  end
end
