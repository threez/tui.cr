module TUI
  enum Align
    Left
    Right
    Center
  end

  module Term
    RESET         = "\e[0m"
    BOLD          = "\e[1m"
    DIM           = "\e[2m"
    ITALIC        = "\e[3m"
    UNDERLINE     = "\e[4m"
    BLINK         = "\e[5m"
    REVERSE       = "\e[7m"
    STRIKETHROUGH = "\e[9m"

    # Box-drawing characters. Corners are rounded (matching lazygit's
    # border style); T-junctions/cross stay square, which is standard even
    # in rounded-corner box styles (there's no rounded T-junction glyph).
    TL = "╭"; TR = "╮"; BL = "╰"; BR = "╯"
    HL = "─"; VL = "│"
    TJ = "┬"; BJ = "┴"; LJ = "├"; RJ = "┤"; CJ = "┼"

    def self.enter_raw : Nil
      system("stty -echo -icanon min 1 time 0 2>/dev/null")
    end

    def self.exit_raw : Nil
      system("stty echo icanon 2>/dev/null")
    end

    def self.size : {rows: Int32, cols: Int32}
      rows = `tput lines`.strip.to_i? || 24
      cols = `tput cols`.strip.to_i? || 80
      {rows: rows, cols: cols}
    end

    def self.clear : String
      "\e[2J\e[H"
    end

    def self.move(row : Int32, col : Int32) : String
      "\e[#{row};#{col}H"
    end

    def self.hide_cursor : String
      "\e[?25l"
    end

    def self.show_cursor : String
      "\e[?25h"
    end

    def self.enter_alt_screen : String
      "\e[?1049h"
    end

    def self.leave_alt_screen : String
      "\e[?1049l"
    end

    # SGR extended mouse reporting (mode 1000 reports button/wheel events,
    # mode 1006 switches to the SGR encoding Keys.parse_sgr_mouse expects —
    # plain mode 1000 alone caps coordinates at 223 and uses a different,
    # ambiguous byte encoding).
    def self.enter_mouse : String
      "\e[?1000h\e[?1006h"
    end

    def self.leave_mouse : String
      "\e[?1000l\e[?1006l"
    end

    def self.bold(s : String) : String
      "#{BOLD}#{s}#{RESET}"
    end

    def self.dim(s : String) : String
      "#{DIM}#{s}#{RESET}"
    end

    def self.reverse(s : String) : String
      "#{REVERSE}#{s}#{RESET}"
    end

    # Layers an extra SGR `code` (e.g. REVERSE or BOLD) on top of
    # whatever styling `s` already carries, rather than replacing it —
    # used to highlight a row (cursor/selection) without discarding its
    # cells' own colors. Unlike #bold/#dim/#reverse, this never strips
    # existing codes and never appends a trailing reset, so Buffer#set's
    # per-cell style accumulation picks up both the original color and
    # the overlay for the same cell.
    def self.overlay(s : String, code : String) : String
      result = String::Builder.new
      result << code
      s.scan(/(\e\[[0-9;]*m)|([^\e]+)/m) do |match|
        if esc = match[1]?
          result << esc << code
        elsif plain = match[2]?
          result << plain
        end
      end
      result.to_s
    end

    # Strip all ANSI escape sequences, returning plain visible text.
    def self.strip_ansi(s : String) : String
      s.gsub(/\e\[[0-9;]*m/, "")
    end

    def self.fg(color : Color, s : String) : String
      "\e[#{fg_code(color)}m#{s}#{RESET}"
    end

    def self.bg(color : Color, s : String) : String
      "\e[#{bg_code(color)}m#{s}#{RESET}"
    end

    # Concatenates the SGR codes for every attribute set on `style`, then
    # applies them all at once and resets at the end — the composable
    # counterpart to #bold/#dim/#reverse/#fg/#bg, which each only ever
    # apply one attribute and previously had to be manually nested to
    # combine (e.g. `Term.fg(:red, Term.bold(s))`). A default `Style.new`
    # (every field false/nil) is a no-op: returns `s` unchanged.
    def self.apply(style : Style, s : String) : String
      code = sgr_code(style)
      code.empty? ? s : "\e[#{code}m#{s}#{RESET}"
    end

    # The bare SGR code string for `style`, with no wrapping `\e[`/`m`/
    # RESET — the numeric parameters only, e.g. "1;31". Combine with
    # #escape (or use #apply/#overlay directly) to get an actual escape
    # sequence a terminal understands.
    def self.sgr_code(style : Style) : String
      parts = [] of String
      parts << "1" if style.bold
      parts << "2" if style.dim
      parts << "3" if style.italic
      parts << "4" if style.underline
      parts << "5" if style.blink
      parts << "7" if style.reverse
      parts << "9" if style.strikethrough
      if fg = style.fg
        parts << fg_code(fg)
      end
      if bg = style.bg
        parts << bg_code(bg)
      end
      parts.join(";")
    end

    # The full escape sequence for `style` (e.g. "\e[1;31m"), or "" for a
    # no-op default `Style.new` — for #overlay, which injects a complete
    # escape sequence after every existing one in a string rather than
    # wrapping start/end like #apply does.
    def self.escape(style : Style) : String
      code = sgr_code(style)
      code.empty? ? "" : "\e[#{code}m"
    end

    private def self.fg_code(color : Color) : String
      color.sgr_fg
    end

    private def self.bg_code(color : Color) : String
      color.sgr_bg
    end

    # Visible (printable) length — excludes ANSI escape sequences.
    def self.visible_size(s : String) : Int32
      s.gsub(/\e\[[0-9;]*m/, "").chars.size
    end

    # Truncate string to `width` visible columns, appending "…" if cut.
    # Preserves embedded ANSI codes up to the cut point (rather than
    # stripping them) so a styled string that needs truncating doesn't
    # lose its color/style — only the characters past `width` are
    # dropped, exactly like the untruncated case already does.
    def self.trunc(s : String, width : Int32) : String
      return s if width <= 0
      return "" if s.empty?
      return s if visible_size(s) <= width

      result = String::Builder.new
      visible_count = 0
      s.scan(/(\e\[[0-9;]*m)|(.)/m) do |match|
        break if visible_count >= width - 1
        if esc = match[1]?
          result << esc
        elsif ch = match[2]?
          result << ch
          visible_count += 1
        end
      end
      result << "…"
      result.to_s
    end

    # Pad or truncate to exactly `width` visible columns. `align`
    # controls where padding goes when the string is shorter than
    # `width` — a string needing truncation ignores it (there's no room
    # for padding either way).
    def self.fit(s : String, width : Int32, align : Align = Align::Left) : String
      vis = visible_size(s)
      return s if vis == width
      return trunc(s, width) if vis > width

      pad = width - vis
      case align
      in .right?
        " " * pad + s
      in .center?
        left = pad // 2
        right = pad - left
        " " * left + s + " " * right
      in .left?
        s + " " * pad
      end
    end
  end
end
