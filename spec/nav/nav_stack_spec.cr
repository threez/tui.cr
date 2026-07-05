require "../spec_helper"

describe TUI::NavStack do
  describe "#push / #pop / #current" do
    it "tracks the top of the stack" do
      nav = TUI::NavStack(Int32).new(1)
      nav.current.should eq(1)

      nav.push(2)
      nav.current.should eq(2)
      nav.size.should eq(2)

      nav.pop
      nav.current.should eq(1)
      nav.size.should eq(1)
    end

    it "refuses to pop the last remaining entry" do
      nav = TUI::NavStack(Int32).new(1)
      nav.pop
      nav.current.should eq(1)
      nav.size.should eq(1)
    end
  end

  describe "#replace_base" do
    it "swaps the bottom entry when it's the only one" do
      nav = TUI::NavStack(Int32).new(1)
      nav.replace_base(99)
      nav.current.should eq(99)
      nav.size.should eq(1)
    end

    it "swaps the bottom entry without disturbing anything pushed on top" do
      nav = TUI::NavStack(Int32).new(1)
      nav.push(2)
      nav.push(3)

      nav.replace_base(99)

      nav.current.should eq(3)
      nav.size.should eq(3)

      nav.pop
      nav.pop
      nav.current.should eq(99)
    end
  end
end
