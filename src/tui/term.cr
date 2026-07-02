module TUI
  module Term
    RESET   = "\e[0m"
    BOLD    = "\e[1m"
    DIM     = "\e[2m"
    REVERSE = "\e[7m"

    # Box-drawing characters
    TL = "┌"; TR = "┐"; BL = "└"; BR = "┘"
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

    def self.bold(s : String) : String
      "#{BOLD}#{s}#{RESET}"
    end

    def self.dim(s : String) : String
      "#{DIM}#{s}#{RESET}"
    end

    def self.reverse(s : String) : String
      "#{REVERSE}#{s}#{RESET}"
    end

    # Strip all ANSI escape sequences, returning plain visible text.
    def self.strip_ansi(s : String) : String
      s.gsub(/\e\[[0-9;]*m/, "")
    end

    def self.fg(color : Symbol, s : String) : String
      code = case color
             when :red     then "31"
             when :green   then "32"
             when :yellow  then "33"
             when :blue    then "34"
             when :magenta then "35"
             when :cyan    then "36"
             when :white   then "37"
             else               "37"
             end
      "\e[#{code}m#{s}#{RESET}"
    end

    # Visible (printable) length — excludes ANSI escape sequences.
    def self.visible_size(s : String) : Int32
      s.gsub(/\e\[[0-9;]*m/, "").chars.size
    end

    # Truncate string to `width` visible columns, appending "…" if cut.
    # Strips ANSI codes before measuring; truncated output is plain text.
    def self.trunc(s : String, width : Int32) : String
      return s if width <= 0
      return "" if s.empty?
      plain = s.gsub(/\e\[[0-9;]*m/, "")
      chars = plain.chars
      return s if chars.size <= width
      chars[0, width - 1].join + "…"
    end

    # Pad or truncate to exactly `width` visible columns.
    def self.fit(s : String, width : Int32) : String
      vis = visible_size(s)
      if vis >= width
        trunc(s, width)
      else
        s + " " * (width - vis)
      end
    end
  end
end
