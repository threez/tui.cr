require "../spec_helper"

describe TUI::DropdownPicker do
  describe ".centered" do
    it "sizes width to fit the longest option label" do
      screen = TUI::Screen.new
      options = [TUI::FormEnumOption.new("A very long option label", "a"), TUI::FormEnumOption.new("B", "b")]
      result = TUI::DropdownPicker.centered(screen, "Title", options)

      result[:window].width.should eq("A very long option label".size + 6)
    end

    it "sizes width to fit the title when it's longer than every option label" do
      screen = TUI::Screen.new
      options = [TUI::FormEnumOption.new("A", "a")]
      result = TUI::DropdownPicker.centered(screen, "A Very Long Title Indeed", options)

      result[:window].width.should eq("A Very Long Title Indeed".size + 4)
    end

    it "never shrinks narrower than 20 columns" do
      screen = TUI::Screen.new
      options = [TUI::FormEnumOption.new("A", "a")]
      result = TUI::DropdownPicker.centered(screen, "T", options)

      result[:window].width.should eq(20)
    end

    it "sizes height to option count plus 2, clamped to max_height" do
      screen = TUI::Screen.new
      options = (1..3).map { |i| TUI::FormEnumOption.new("Opt#{i}", "#{i}") }
      result = TUI::DropdownPicker.centered(screen, "Title", options, max_height: 12)

      result[:window].height.should eq(3 + 2)
    end

    it "clamps height at max_height when there are many options" do
      screen = TUI::Screen.new
      options = (1..50).map { |i| TUI::FormEnumOption.new("Opt#{i}", "#{i}") }
      result = TUI::DropdownPicker.centered(screen, "Title", options, max_height: 12)

      result[:window].height.should eq(12)
    end

    it "seeds the cursor at initial_index" do
      screen = TUI::Screen.new
      options = [TUI::FormEnumOption.new("A", "a"), TUI::FormEnumOption.new("B", "b"), TUI::FormEnumOption.new("C", "c")]
      result = TUI::DropdownPicker.centered(screen, "Title", options, initial_index: 2)

      result[:list].selected_index.should eq(2)
    end

    it "centers the window within the screen" do
      screen = TUI::Screen.new
      options = [TUI::FormEnumOption.new("A", "a")]
      result = TUI::DropdownPicker.centered(screen, "Title", options)
      window = result[:window]

      (window.x + (window.width - 1) // 2).should be_close(screen.cols // 2, 1)
      (window.y + (window.height - 1) // 2).should be_close(screen.rows // 2, 1)
    end
  end

  describe ".centered_multi" do
    it "builds a MultiOptionListView sized the same way as .centered" do
      screen = TUI::Screen.new
      options = [TUI::FormEnumOption.new("A", "a"), TUI::FormEnumOption.new("B", "b")]
      result = TUI::DropdownPicker.centered_multi(screen, "Title", options, Set{"b"})

      result[:list].should be_a(TUI::MultiOptionListView)
      result[:window].height.should eq(2 + 2)
    end
  end
end
