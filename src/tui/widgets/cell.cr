require "../core/term"

module TUI
  # A styled string, e.g. one TableView column value or DetailView row's
  # value. `style` is resolved to an actual ANSI sequence only at render
  # time via CellStyle.apply — the default `Style.new` renders `text`
  # plain.
  record Cell,
    text : String,
    style : Style = Style.new

  module CellStyle
    def self.apply(style : Style, s : String) : String
      Term.apply(style, s)
    end
  end
end
