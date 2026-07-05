module TUI
  # A composable set of SGR attributes — weight (bold/dim), reverse-video,
  # and foreground/background color — applied together via Term.apply.
  # Replaces ad-hoc, manually-nested `Term.fg(:red, Term.bold(s))`-style
  # calls scattered through widget render methods with one value every
  # widget can expose as a named, overridable style property (e.g.
  # TableView#header_style, Form::Host#label_style). The default
  # `Style.new` (every field false/nil) means "no styling" — Term.apply
  # returns its input unchanged for it.
  #
  # `fg`/`bg` take any Color, built via `TUI.color(...)`:
  #   TUI.color(:red)             one of the 16 classic ANSI names (+ :gray)
  #   TUI.color(208)               a raw 0-255 xterm 256-color palette index
  #   TUI.color(r: 5, g: 2, b: 0)  a 256-color cube coordinate
  #   TUI.color(gray: 10)          a 256-color grayscale ramp step
  record Style,
    bold : Bool = false,
    dim : Bool = false,
    reverse : Bool = false,
    fg : Color? = nil,
    bg : Color? = nil
end
