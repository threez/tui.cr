require "./spec_helper"

describe TUI::Popup do
  describe ".centered" do
    it "sizes and centers the popup within the screen" do
      screen = TUI::Screen.new
      popup = TUI::Popup.centered(screen, "Error", "something went wrong")

      popup.width.should be <= screen.cols
      popup.height.should eq(5)
      (popup.x + popup.width).should be <= screen.cols + 2
      (popup.y + popup.height).should be <= screen.rows + 2
      popup.x.should be >= 1
      popup.y.should be >= 1
    end

    it "widens to fit a long message, capped to the screen width" do
      screen = TUI::Screen.new
      long_message = "x" * 500
      popup = TUI::Popup.centered(screen, "Error", long_message)

      popup.width.should eq(screen.cols - 4)
    end
  end

  describe "#handle_key" do
    it "consumes any key (dismiss-on-any-key)" do
      popup = TUI::Popup.new(1, 1, 30, 5, "Error", "boom")

      popup.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'x')).should be_true
      popup.handle_key(TUI::KeyEvent.new(TUI::Key::Esc)).should be_true
      popup.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)).should be_true
    end
  end

  describe "#render" do
    it "draws without raising for a representative size" do
      popup = TUI::Popup.new(1, 1, 30, 5, "Error", "boom")
      popup.composite(TUI::Screen.new)
    end

    it "draws without raising when the message is longer than the interior width" do
      popup = TUI::Popup.new(1, 1, 10, 5, "Error", "a message way too long to fit")
      popup.composite(TUI::Screen.new)
    end
  end
end
