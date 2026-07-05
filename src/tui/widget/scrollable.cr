require "../core/keys"
require "../core/buffer"

module TUI
  # What a widget hosted inside a Window must provide. Unlike Widget, a
  # Scrollable has no x/y of its own and does not own a Buffer, a border,
  # or a Scroller — Window supplies all of that.
  module Scrollable
    # Gates whether #handle_key/#handle_click should be given a chance to
    # consume the current event, same convention as Widget#focused? —
    # toggle it via #focus_if.
    property? focused : Bool = false

    def focus_if(condition : Bool) : Nil
      @focused = condition
    end

    # Total scrollable content rows. Does NOT include a header row —
    # header is content-internal (TableView-specific), not Window's.
    abstract def content_size : Int32

    # Rows reserved above the data rows (e.g. a table's column header)
    # that Window must exclude from the visible/scrollable viewport size
    # it hands to its Scroller and ScrollControl (see Window#render/
    # #handle_key) — content still draws this row itself via
    # #render_content; Window never draws it and has no other way to
    # know it exists. Defaults to 0 (no header), so existing Scrollables
    # need no changes.
    def header_rows : Int32
      0
    end

    # Render into `buffer`, a region already sized to the content area
    # (border/scrollbar column already excluded by Window). Row 0 is
    # content's own first row.
    abstract def render_content(buffer : Buffer, scroll : ScrollControl) : Nil

    # Everything but positional mouse hit-testing.
    abstract def handle_key(ev : KeyEvent, scroll : ScrollControl) : Bool

    # A positional (mouse) event, pre-translated by Window into
    # content-local row/col (0,0 = content's own first cell).
    abstract def handle_click(local_row : Int32, local_col : Int32, scroll : ScrollControl) : Bool

    abstract def title : String
    abstract def status_hint : String
  end
end
