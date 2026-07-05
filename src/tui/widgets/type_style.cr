module TUI
  # Maps a column's data type to a Cell Style for display. Prefers a
  # precise portable-type tag (e.g. "int32", "bool") when the caller has
  # one; otherwise falls back to sniffing common substrings in a raw SQL
  # type_text, so it still gives reasonable coloring against databases with
  # no portable-type metadata.
  #
  # Intentionally narrow: this only covers types generic enough to appear
  # across any SQL-backed app (numbers, bools, times, bytes). Domain-specific
  # coloring — foreign keys, enums, validation errors — depends on
  # app-specific schema metadata and belongs in the app's own DataSource,
  # not here.
  module TypeStyle
    def self.for(portable_type : String?, type_text : String) : Style
      if pt = portable_type
        for_portable_type(pt)
      else
        for_type_text(type_text)
      end
    end

    private def self.for_portable_type(pt : String) : Style
      case pt
      when "int32", "int64", "uuid"        then Style.new(fg: TUI.color(:cyan))
      when "float32", "float64", "decimal" then Style.new(fg: TUI.color(:yellow))
      when "bool"                          then Style.new(fg: TUI.color(:green))
      when "time"                          then Style.new(fg: TUI.color(:blue))
      when "bytes"                         then Style.new(fg: TUI.color(:magenta))
      else                                      Style.new
      end
    end

    # Color => substrings to look for (case-insensitively) in a raw SQL
    # type_text, checked in declaration order by #for_type_text — the
    # fallback path used when no portable_type is available.
    TYPE_TEXT_HINTS = {
      :cyan    => %w[INT SERIAL],
      :yellow  => %w[REAL FLOAT DOUBLE NUMERIC DECIMAL],
      :green   => %w[BOOL],
      :blue    => %w[DATE TIME STAMP],
      :magenta => %w[BLOB BYTE BINARY],
    }

    private def self.for_type_text(type_text : String) : Style
      t = type_text.upcase
      TYPE_TEXT_HINTS.each do |color, hints|
        return Style.new(fg: TUI.color(color)) if hints.any? { |hint| t.includes?(hint) }
      end
      Style.new
    end
  end
end
