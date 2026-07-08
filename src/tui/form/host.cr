require "../widget/widget"
require "../nav/nav_stack"
require "./form_field"
require "./field_spec"
require "./form_field_cell"
require "./popup_host"
require "../layout/grid"

module TUI
  module Form
    # Drives a list of FieldSpec(M) against a bound model `M`. Layout and
    # per-field focus/editing are delegated to an internal Grid
    # (src/tui/layout/grid.cr) of FormFieldCell widgets (one per field,
    # each drawing its own label + editor and handling its own
    # start/commit/cancel) — Host itself now only owns the outer
    # box/title chrome and builds the Grid once at construction time.
    # Previously Host hand-computed row/column coordinates and drove
    # @editor/@focus_index directly; that per-field state now lives in
    # each FormFieldCell, and cross-field focus traversal (Tab/Shift+Tab)
    # lives in Grid — both reusable independent of Form::Host.
    class Host(M) < Widget
      # Default column width reserved for a field's label, before the value
      # column starts — override via #initialize's `label_width` for
      # consumers with longer labels.
      DEFAULT_LABEL_WIDTH = 12
      # Default floor: the value column must keep at least this much width
      # before any of it is given up to an inline error message — below
      # this floor, the error is dropped rather than squeezing the value
      # further. Override via #initialize's `min_value_width`.
      DEFAULT_MIN_VALUE_WIDTH = 20
      # Default upper bound on how much value-column width an inline error
      # message may claim, even if there'd be room to give it more.
      # Override via #initialize's `max_error_width`.
      DEFAULT_MAX_ERROR_WIDTH = 40

      # Applied to the box border drawn by #render.
      property border_style : Style = Style.new(fg: TUI.color(:gray))

      def initialize(x : Int32, y : Int32, width : Int32, height : Int32,
                     fields : Array(FieldSpec(M)), model : M, popup : PopupHost,
                     @title : String = "Edit", label_width : Int32 = DEFAULT_LABEL_WIDTH,
                     min_value_width : Int32 = DEFAULT_MIN_VALUE_WIDTH,
                     max_error_width : Int32 = DEFAULT_MAX_ERROR_WIDTH)
        super(x, y, width, height)
        @grid = Grid.new(x + 1, y + 1, width - 2, height - 2, [1], row_height: 1, bordered: false)
        row = 0
        fields.each do |field|
          cell = FormFieldCell(M).new(0, 0, width - 2, field.rows, field, model, popup,
            label_width, min_value_width, max_error_width)
          cell.popup_border_style = border_style
          @grid.attach(cell, col: 0, row: row, row_span: field.rows)
          row += field.rows
        end
      end

      # Sizes and positions a Host to fill the screen below the status bar
      # row — see Window.full_screen for the same reasoning.
      def self.full_screen(screen : Screen, fields : Array(FieldSpec(M)), model : M,
                           popup : PopupHost, title : String = "Edit",
                           label_width : Int32 = DEFAULT_LABEL_WIDTH,
                           min_value_width : Int32 = DEFAULT_MIN_VALUE_WIDTH,
                           max_error_width : Int32 = DEFAULT_MAX_ERROR_WIDTH) : Host(M)
        new(1, 1, screen.cols, screen.rows - 1, fields, model, popup, title,
          label_width, min_value_width, max_error_width)
      end

      # Builds a PopupHost from an app's actual NavStack(Widget), so a host
      # app doesn't need to hand-write the push/pop proc wiring itself.
      def self.popup_host(screen : Screen, nav : NavStack(Widget)) : PopupHost
        PopupHost.new(screen: screen, push: ->(w : Widget) { nav.push(w) }, pop: -> { nav.pop })
      end

      # Re-derives the Grid's own x/y/width/height from Host's current
      # geometry every frame — the same convention HSplit#composite/
      # #layout follow, rather than trusting the values fixed at
      # construction — so a Host that gets resized after construction
      # (e.g. Runtime's SIGWINCH handler calling Widget#width=/#height=
      # on whatever full-screen page is on top of the NavStack, which
      # includes a Form::Host page like example/pages/form_page.cr) still
      # hosts a correctly-sized Grid, which in turn reflows every
      # attached FormFieldCell's width via its own weighted #col_widths
      # (see Grid#layout) instead of staying pinned to the width current
      # when the Grid/cells were first constructed.
      def composite(screen : Screen) : Nil
        @grid.x = x + 1
        @grid.y = y + 1
        @grid.width = width - 2
        @grid.height = height - 2
        super
        @grid.composite(screen)
      end

      def render : Nil
        @buffer.box(0, 0, height, width, title: @title, style: border_style)
      end

      def handle_key(ev : KeyEvent) : Bool
        @grid.handle_key(ev)
      end

      def status_hint : String
        @grid.status_hint
      end
    end
  end
end
