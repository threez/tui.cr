require "../spec_helper"

describe TUI::Term do
  describe ".overlay" do
    it "prepends the code to a plain string with no existing styling" do
      result = TUI::Term.overlay("hello", TUI::Term::REVERSE)
      result.should eq("#{TUI::Term::REVERSE}hello")
    end

    it "preserves an existing embedded color code alongside the overlay code" do
      colored = TUI::Term.fg(TUI.color(:green), "ok")
      result = TUI::Term.overlay(colored, TUI::Term::REVERSE)

      result.should contain("\e[32m")
      result.should contain(TUI::Term::REVERSE)
      TUI::Term.strip_ansi(result).should eq("ok")
    end

    it "re-applies the overlay code after an embedded reset so it holds through the rest of the string" do
      s = "#{TUI::Term::BOLD}bold#{TUI::Term::RESET}plain"
      result = TUI::Term.overlay(s, TUI::Term::REVERSE)

      # REVERSE should appear both right after BOLD and right after RESET
      result.should eq("#{TUI::Term::REVERSE}#{TUI::Term::BOLD}#{TUI::Term::REVERSE}bold#{TUI::Term::RESET}#{TUI::Term::REVERSE}plain")
    end

    it "does not strip existing styling the way Term.reverse effectively requires callers to do" do
      colored = TUI::Term.fg(TUI.color(:red), "danger")
      result = TUI::Term.overlay(colored, TUI::Term::BOLD)

      TUI::Term.strip_ansi(result).should eq("danger")
      result.should contain("\e[31m")
    end
  end

  describe ".apply" do
    it "returns the string unchanged for a default no-op Style" do
      TUI::Term.apply(TUI::Style.new, "hi").should eq("hi")
    end

    it "combines bold, foreground, and background into one escape sequence" do
      result = TUI::Term.apply(TUI::Style.new(bold: true, fg: TUI.color(:red), bg: TUI.color(:white)), "hi")
      result.should eq("\e[1;31;47mhi\e[0m")
    end

    it "supports :gray for foreground and background (SGR bright-black)" do
      TUI::Term.apply(TUI::Style.new(fg: TUI.color(:gray)), "hi").should eq("\e[90mhi\e[0m")
      TUI::Term.apply(TUI::Style.new(bg: TUI.color(:gray)), "hi").should eq("\e[100mhi\e[0m")
    end

    it "supports a 256-color foreground as a 256-color SGR sequence" do
      TUI::Term.apply(TUI::Style.new(fg: TUI.color(208)), "hi").should eq("\e[38;5;208mhi\e[0m")
    end

    it "combines bold, 256-color foreground, and 256-color background into one escape sequence" do
      style = TUI::Style.new(bold: true, fg: TUI.color(208), bg: TUI.color(235))
      TUI::Term.apply(style, "hi").should eq("\e[1;38;5;208;48;5;235mhi\e[0m")
    end

    it "applies italic" do
      TUI::Term.apply(TUI::Style.new(italic: true), "hi").should eq("\e[3mhi\e[0m")
    end

    it "applies underline" do
      TUI::Term.apply(TUI::Style.new(underline: true), "hi").should eq("\e[4mhi\e[0m")
    end

    it "applies strikethrough" do
      TUI::Term.apply(TUI::Style.new(strikethrough: true), "hi").should eq("\e[9mhi\e[0m")
    end

    it "applies blink" do
      TUI::Term.apply(TUI::Style.new(blink: true), "hi").should eq("\e[5mhi\e[0m")
    end

    it "combines bold, italic, underline, and a foreground color in SGR-conventional order" do
      style = TUI::Style.new(bold: true, italic: true, underline: true, fg: TUI.color(:red))
      TUI::Term.apply(style, "hi").should eq("\e[1;3;4;31mhi\e[0m")
    end

    it "combines underline, blink, strikethrough, and reverse in SGR-conventional order" do
      style = TUI::Style.new(underline: true, blink: true, strikethrough: true, reverse: true)
      TUI::Term.apply(style, "hi").should eq("\e[4;5;7;9mhi\e[0m")
    end
  end

  describe ".escape" do
    it "returns an empty string for a default no-op Style" do
      TUI::Term.escape(TUI::Style.new).should eq("")
    end

    it "matches the single-attribute constants for reverse/bold" do
      TUI::Term.escape(TUI::Style.new(reverse: true)).should eq(TUI::Term::REVERSE)
      TUI::Term.escape(TUI::Style.new(bold: true)).should eq(TUI::Term::BOLD)
    end

    it "renders a 256-color-only style as a 256-color escape sequence" do
      TUI::Term.escape(TUI::Style.new(fg: TUI.color(196))).should eq("\e[38;5;196m")
    end

    it "matches the single-attribute constants for italic/underline" do
      TUI::Term.escape(TUI::Style.new(italic: true)).should eq(TUI::Term::ITALIC)
      TUI::Term.escape(TUI::Style.new(underline: true)).should eq(TUI::Term::UNDERLINE)
    end

    it "matches the single-attribute constants for strikethrough/blink" do
      TUI::Term.escape(TUI::Style.new(strikethrough: true)).should eq(TUI::Term::STRIKETHROUGH)
      TUI::Term.escape(TUI::Style.new(blink: true)).should eq(TUI::Term::BLINK)
    end
  end

  describe ".fg" do
    it "renders a named color" do
      TUI::Term.fg(TUI.color(:red), "x").should eq("\e[31mx\e[0m")
    end

    it "renders a 256-color index" do
      TUI::Term.fg(TUI.color(196), "x").should eq("\e[38;5;196mx\e[0m")
    end
  end

  describe ".bg" do
    it "renders a named color" do
      TUI::Term.bg(TUI.color(:red), "x").should eq("\e[41mx\e[0m")
    end

    it "renders a 256-color index" do
      TUI::Term.bg(TUI.color(196), "x").should eq("\e[48;5;196mx\e[0m")
    end
  end

  describe ".fit" do
    it "left-aligns by default, padding on the right" do
      TUI::Term.fit("hi", 5).should eq("hi   ")
    end

    it "left-aligns explicitly the same way" do
      TUI::Term.fit("hi", 5, TUI::Align::Left).should eq("hi   ")
    end

    it "right-aligns, padding on the left" do
      TUI::Term.fit("hi", 5, TUI::Align::Right).should eq("   hi")
    end

    it "center-aligns, splitting padding across both sides" do
      TUI::Term.fit("hi", 6, TUI::Align::Center).should eq("  hi  ")
    end

    it "center-aligns with the extra odd padding column on the right" do
      TUI::Term.fit("hi", 5, TUI::Align::Center).should eq(" hi  ")
    end

    it "ignores alignment when the string needs truncation instead of padding" do
      TUI::Term.fit("hello world", 5, TUI::Align::Right).should eq("hell…")
      TUI::Term.fit("hello world", 5, TUI::Align::Center).should eq("hell…")
    end

    it "returns a string unchanged when it exactly fills the width, without truncating it" do
      TUI::Term.fit("hello", 5).should eq("hello")
      TUI::Term.fit("hello", 5, TUI::Align::Right).should eq("hello")
      TUI::Term.fit("hello", 5, TUI::Align::Center).should eq("hello")
    end
  end
end
