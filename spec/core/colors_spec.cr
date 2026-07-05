require "../spec_helper"

describe TUI::RGB256 do
  it "wraps a valid 0-255 index" do
    TUI::RGB256.new(0).index.should eq(0)
    TUI::RGB256.new(255).index.should eq(255)
  end

  it "raises on an out-of-range index" do
    expect_raises(ArgumentError) { TUI::RGB256.new(256) }
    expect_raises(ArgumentError) { TUI::RGB256.new(-1) }
  end

  it "renders itself as a 256-color SGR fragment" do
    TUI::RGB256.new(208).sgr_fg.should eq("38;5;208")
    TUI::RGB256.new(208).sgr_bg.should eq("48;5;208")
  end
end

describe TUI::NamedColor do
  it "renders the classic ANSI SGR codes" do
    TUI::NamedColor.new(:red).sgr_fg.should eq("31")
    TUI::NamedColor.new(:red).sgr_bg.should eq("41")
  end

  it "renders :gray as bright-black (90/100)" do
    TUI::NamedColor.new(:gray).sgr_fg.should eq("90")
    TUI::NamedColor.new(:gray).sgr_bg.should eq("100")
  end
end

describe TUI::Colors do
  describe ".cube" do
    it "maps the black corner to 16" do
      TUI::Colors.cube(0, 0, 0).should eq(TUI::RGB256.new(16))
    end

    it "maps the white corner to 231" do
      TUI::Colors.cube(5, 5, 5).should eq(TUI::RGB256.new(231))
    end

    it "maps the pure-red corner to 196" do
      TUI::Colors.cube(5, 0, 0).should eq(TUI::RGB256.new(196))
    end

    it "maps the pure-green corner to 46" do
      TUI::Colors.cube(0, 5, 0).should eq(TUI::RGB256.new(46))
    end

    it "computes an interior point via 16 + 36r + 6g + b" do
      TUI::Colors.cube(2, 3, 4).should eq(TUI::RGB256.new(110))
    end

    it "raises when any channel is out of range 0-5" do
      expect_raises(ArgumentError) { TUI::Colors.cube(6, 0, 0) }
      expect_raises(ArgumentError) { TUI::Colors.cube(0, -1, 0) }
    end
  end

  describe ".gray" do
    it "maps step 0 to 232" do
      TUI::Colors.gray(0).should eq(TUI::RGB256.new(232))
    end

    it "maps step 23 to 255" do
      TUI::Colors.gray(23).should eq(TUI::RGB256.new(255))
    end

    it "maps an interior step via 232 + n" do
      TUI::Colors.gray(10).should eq(TUI::RGB256.new(242))
    end

    it "raises when the step is out of range 0-23" do
      expect_raises(ArgumentError) { TUI::Colors.gray(24) }
      expect_raises(ArgumentError) { TUI::Colors.gray(-1) }
    end
  end
end

describe "TUI.color" do
  it "builds a NamedColor from a Symbol" do
    color = TUI.color(:red)
    color.should be_a(TUI::NamedColor)
    color.sgr_fg.should eq("31")
  end

  it "builds an RGB256 from a raw palette index" do
    color = TUI.color(208)
    color.should be_a(TUI::RGB256)
    color.as(TUI::RGB256).index.should eq(208)
  end

  it "builds an RGB256 from r:/g:/b: cube coordinates" do
    color = TUI.color(r: 5, g: 0, b: 0)
    color.should eq(TUI::Colors.cube(5, 0, 0))
  end

  it "builds an RGB256 from a gray: grayscale step" do
    color = TUI.color(gray: 10)
    color.should eq(TUI::Colors.gray(10))
  end
end
