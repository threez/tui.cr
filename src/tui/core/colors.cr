module TUI
  # Anything that can render itself as the parameter portion of an SGR
  # foreground/background escape (no leading "\e[3"/"\e[4" prefix, no
  # trailing "m" — see #sgr_fg/#sgr_bg return shape on each subclass).
  # Term never branches on a concrete Color subclass; it only ever calls
  # these two methods, so adding a new color representation (e.g. 24-bit
  # RGB) never requires touching Term or Style — just a new subclass and
  # a new TUI.color overload.
  abstract class Color
    abstract def sgr_fg : String
    abstract def sgr_bg : String
  end

  # One of the 16 classic ANSI color names, plus :gray — an invented
  # alias for bright-black (SGR 90/100), not a real terminal color name,
  # predating and distinct from the 256-color palette.
  class NamedColor < Color
    def initialize(@name : Symbol)
    end

    def_equals @name

    def sgr_fg : String
      case @name
      when :red     then "31"
      when :green   then "32"
      when :yellow  then "33"
      when :blue    then "34"
      when :magenta then "35"
      when :cyan    then "36"
      when :white   then "37"
      when :gray    then "90"
      else               "37" # unrecognized name falls back to white
      end
    end

    def sgr_bg : String
      case @name
      when :red     then "41"
      when :green   then "42"
      when :yellow  then "43"
      when :blue    then "44"
      when :magenta then "45"
      when :cyan    then "46"
      when :white   then "47"
      when :gray    then "100"
      else               "47" # unrecognized name falls back to white
      end
    end
  end

  # A single xterm 256-color palette index (0-255).
  class RGB256 < Color
    getter index : Int32

    def initialize(@index : Int32)
      raise ArgumentError.new("RGB256 index out of range 0-255: #{@index}") unless (0..255).includes?(@index)
    end

    def_equals @index

    def sgr_fg : String
      "38;5;#{@index}"
    end

    def sgr_bg : String
      "48;5;#{@index}"
    end
  end

  # xterm 256-color palette index math, returning RGB256 instances.
  module Colors
    # 6x6x6 RGB color cube (codes 16-231). Each channel is 0-5; the
    # standard xterm cube's component intensities are
    # [0, 95, 135, 175, 215, 255].
    def self.cube(r : Int32, g : Int32, b : Int32) : RGB256
      unless (0..5).includes?(r) && (0..5).includes?(g) && (0..5).includes?(b)
        raise ArgumentError.new("cube channel out of range 0-5: (#{r}, #{g}, #{b})")
      end
      RGB256.new(16 + 36 * r + 6 * g + b)
    end

    # 24-step grayscale ramp (codes 232-255), n is 0-23. Excludes pure
    # black/white — those are already codes 0/15 (NamedColor) and
    # 16/231 (cube corners).
    def self.gray(n : Int32) : RGB256
      raise ArgumentError.new("gray step out of range 0-23: #{n}") unless (0..23).includes?(n)
      RGB256.new(232 + n)
    end
  end

  # The single call-site-facing color constructor — dispatches on
  # argument shape so callers never construct a Color subclass directly:
  #   TUI.color(:red)             -> NamedColor
  #   TUI.color(208)               -> RGB256 (raw palette index)
  #   TUI.color(r: 5, g: 2, b: 0)  -> RGB256 via Colors.cube
  #   TUI.color(gray: 10)          -> RGB256 via Colors.gray
  def self.color(name : Symbol) : Color
    NamedColor.new(name)
  end

  def self.color(index : Int32) : Color
    RGB256.new(index)
  end

  def self.color(r : Int32, g : Int32, b : Int32) : Color
    Colors.cube(r, g, b)
  end

  # `*,` forces this overload to match only a labeled `gray:` call —
  # Crystal does not disambiguate `Int32` overloads by parameter name for
  # a plain positional argument, so without this a bare `TUI.color(n)`
  # could resolve to either this or the `index` overload above.
  def self.color(*, gray : Int32) : Color
    Colors.gray(gray)
  end
end
