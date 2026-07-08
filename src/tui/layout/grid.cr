require "../widget/widget"
require "../widget/key_menu"
require "../widget/scroller"

module TUI
  # Positions an arbitrary number of widgets in a row/column grid,
  # GTK Gtk.Grid-style: #attach(child, col, row, col_span, row_span)
  # places a child at a cell (optionally spanning several columns/rows),
  # and Grid repositions it every #composite the same way HSplit
  # repositions its two panes — by writing directly to the child's own
  # x/y/width/height. Each child still owns and composites its own
  # buffer; Grid draws no content of its own beyond an optional border.
  #
  # Unlike GTK's Grid, columns are NOT sized by measuring each child's
  # size requisition — this toolkit has no size-negotiation protocol
  # (Widget's width/height are always set by a parent, never requested
  # by a child), so auto-sizing from content isn't available to build
  # on. Instead a caller supplies relative column *weights* at
  # construction (e.g. `[1]` for one full-width column, `[1, 2]` for a
  # 1:2 split) and #layout converts those to actual pixel widths from
  # Grid's own current `width` every #composite — the same "re-derive
  # from current geometry every frame" technique HSplit#layout uses for
  # its own ratio mode, generalized from 2 panes to N columns, so a Grid
  # whose own width changes (e.g. a terminal resize propagating down
  # through Form::Host, see Form::Host#composite) keeps every attached
  # child's width in sync automatically rather than staying pinned to
  # whatever width was current when #attach was first called. Per-row
  # height stays a fixed cell count (row_span the way FieldSpec#rows
  # already reserves multiple rows for one field) since rows are a
  # counted list of fields, not a proportional split of the available
  # height.
  #
  # Focus is tracked as a single flat index into attachment order (not
  # per-row/per-column), generalizing the binary `@active` pane toggle
  # HSplit/SplitWindow both hard-code to N children — Tab/Shift+Tab move
  # forward/backward through attachments and wrap, exactly like
  # Form::Host's historical Enter-starts-edit / Esc-or-Enter-commits
  # convention meant Up/Down only ever navigated fields while nothing was
  # being edited. Up/Down are also bound as a second way to move focus,
  # matching that same historical Form::Host convention — but as a
  # *fallback*, tried only after the focused child's own #handle_key
  # declines the key (returns false), not intercepted upfront the way
  # Tab/Shift+Tab are (see #handle_key). This ordering is what lets
  # Up/Down double as both "move between fields" while idle and "move
  # the cursor within a field" while a ScrollableField-backed cell
  # (src/tui/form/scrollable_field.cr) is actively editing multi-line
  # text: an idle FormFieldCell's own #handle_key only ever consumes
  # Enter (see FormFieldCell#handle_nav_key), so Up/Down fall through to
  # Grid; an actively-editing cell always reports the key consumed once
  # an edit session is open (see FormFieldCell#handle_editor_key), so
  # Up/Down never reach Grid's fallback while a field is mid-edit,
  # matching the old Form::Host behavior of Up/Down only navigating
  # between fields, never while one is being edited.
  #
  # Scrolls when total attached row extent exceeds Grid's own viewport
  # (see #total_rows/#visible_rows) — owns a Scroller exactly like
  # Window/SplitWindow do for their own single Scrollable, generalized
  # here to a row offset shared by every attachment's `row`. Unlike
  # Window, Grid's children are independent Widgets that blit themselves
  # directly via Screen#blit rather than rendering into one shared
  # scratch Buffer Grid could bound on its own — so clipping instead
  # relies on Screen#with_clip (src/tui/core/screen.cr), which bounds
  # every #blit call for the duration of Grid's own #composite to Grid's
  # box. This is what lets a child taller than what's currently visible
  # (row_span > 1, scrolled so only part of it should show) clip
  # correctly with zero cooperation from the child itself: it always
  # renders its full local buffer as normal; Screen#blit's clip check
  # silently drops whichever cells land outside Grid's rect this frame.
  # PageUp/PageDown/mouse-wheel scroll the same way Up/Down navigate —
  # as a fallback tried only after the focused child declines the key,
  # since TextEdit (wrapped by ScrollableField) unconditionally consumes
  # those keys for its own internal scrolling while being edited.
  class Grid < Widget
    record Attachment, child : Widget, col : Int32, row : Int32, col_span : Int32, row_span : Int32

    # Applied to the border drawn by #render when #bordered? is true.
    property border_style : Style = Style.new(fg: TUI.color(:gray))

    # Whether to draw a box border around the grid. Mirrors Window#bordered?.
    property? bordered : Bool

    @scrollbar_style : Style? = nil

    # Applied to the scrollbar track/thumb drawn by #render — defaults
    # to whatever #border_style currently is, resolved fresh on every
    # read, same convention as Window#scrollbar_style.
    def scrollbar_style : Style
      @scrollbar_style || border_style
    end

    def scrollbar_style=(style : Style) : Nil
      @scrollbar_style = style
    end

    # Read-only list of attached children in attachment order — the
    # order Tab/Shift+Tab/Up/Down traverse.
    getter attachments = [] of Attachment

    @menu : KeyMenu
    @scroller : Scroller

    def initialize(x : Int32, y : Int32, width : Int32, height : Int32,
                   @col_weights : Array(Int32), @row_height : Int32 = 1, @bordered : Bool = false)
      super(x, y, width, height)
      @focus_index = 0
      @scroller = Scroller.new
      @menu = build_menu
    end

    # Places `child` at grid position (col, row), optionally spanning
    # `col_span` columns and `row_span` rows (row_span lets one child
    # reserve several row-heights, the same role FieldSpec#rows plays
    # for a Form::Host field today). Re-runs #layout immediately so the
    # child's geometry is valid even before the next #composite.
    def attach(child : Widget, col : Int32, row : Int32, col_span : Int32 = 1, row_span : Int32 = 1) : Nil
      @attachments << Attachment.new(child, col, row, col_span, row_span)
      layout
    end

    # Wraps the per-child composite loop in Screen#with_clip, bounded to
    # Grid's own inner rect (the same rect its scrollbar/content occupy)
    # — this is what stops an attachment positioned outside the current
    # scroll window from bleeding its cells onto whatever else is on
    # screen below/above Grid, see the class doc comment above. Skipping
    # a fully-out-of-view child's #composite call entirely is a cheap
    # optimization, not load-bearing for correctness: the clip alone
    # would already turn its blit into a no-op.
    def composite(screen : Screen) : Nil
      layout
      reveal_focused
      @attachments.each_with_index do |attachment, index|
        attachment.child.focus_if(index == @focus_index)
      end
      super
      clip = ClipRect.new(row: y + inset, col: x + inset, height: inner_height, width: inner_width)
      screen.with_clip(clip) do
        @attachments.each do |attachment|
          attachment.child.composite(screen) if child_visible?(attachment)
        end
      end
    end

    def render : Nil
      @buffer.box(0, 0, height, width, style: border_style) if bordered?
      total = total_rows
      visible = visible_rows
      @buffer.scrollbar(0, width - 1, height, @scroller.fraction(total, visible),
        visible: visible, total: total, style: scrollbar_style, inset: inset)
    end

    # Menu (Tab/Shift+Tab) dispatches unconditionally, before the
    # focused child ever sees the key — same as always. Everything else
    # goes to the focused child first; only once it declines does Grid
    # try its own fallbacks (scroll, then nav) — see the class doc
    # comment for why this order matters for ScrollableField.
    def handle_key(ev : KeyEvent) : Bool
      return true if @menu.dispatch(ev)
      return false if @attachments.empty?
      return true if @attachments[@focus_index].child.handle_key(ev)
      handle_scroll_fallback(ev) || handle_nav_fallback(ev)
    end

    def status_hint : String
      hint = @menu.hint
      hint += "  PgUp/PgDn:scroll" if total_rows > visible_rows
      return hint if @attachments.empty?
      hint + "  " + @attachments[@focus_index].child.status_hint
    end

    private def build_menu : KeyMenu
      menu = KeyMenu.new
      menu.bind(Key::Tab, "Tab/↑↓:navigate") { focus_next }
      menu.bind(Key::ShiftTab, "") { focus_prev }
      menu
    end

    private def focus_next : Nil
      return if @attachments.empty?
      @focus_index = (@focus_index + 1) % @attachments.size
      reveal_focused
    end

    private def focus_prev : Nil
      return if @attachments.empty?
      @focus_index = (@focus_index - 1) % @attachments.size
      reveal_focused
    end

    # Up/Down as a fallback way to move focus, tried only after the
    # focused child has already declined the key — see the Up/Down
    # design note above #handle_key for why this must run after, not
    # via @menu (which would intercept unconditionally, before a
    # ScrollableField-backed cell ever got a chance to move its own
    # cursor with the same keys).
    private def handle_nav_fallback(ev : KeyEvent) : Bool
      case ev.key
      when Key::Down
        focus_next
        true
      when Key::Up
        focus_prev
        true
      else
        false
      end
    end

    # PageUp/PageDown/mouse-wheel scroll Grid's own viewport, same
    # fallback tier and same reasoning as #handle_nav_fallback — kept as
    # a separate method since it's conceptually distinct (scroll the
    # viewport vs move focus), tried in the same step from #handle_key.
    private def handle_scroll_fallback(ev : KeyEvent) : Bool
      case ev.key
      when Key::PageUp
        @scroller.up(visible_rows)
        true
      when Key::PageDown
        @scroller.down(visible_rows, total: total_rows, visible: visible_rows)
        true
      when Key::MouseWheelUp
        @scroller.wheel_up
        true
      when Key::MouseWheelDown
        @scroller.wheel_down(total: total_rows, visible: visible_rows)
        true
      else
        false
      end
    end

    private def inset : Int32
      bordered? ? 1 : 0
    end

    # One column reserved for the scrollbar when borderless — mirrors
    # ScrollableField#render's own unconditional last-column reservation
    # (src/tui/form/scrollable_field.cr) for the same reason: reserving
    # it only when content actually overflows would make col_widths
    # (and so every attached child's width) jump by 1 cell at the exact
    # frame scrolling toggles on/off, which reads worse than a
    # permanently slightly narrower column. When bordered, the
    # scrollbar instead uses the existing border column (see #render,
    # same convention Window uses) and no extra column is needed.
    private def scrollbar_reserve : Int32
      bordered? ? 0 : 1
    end

    private def inner_height : Int32
      height - 2 * inset
    end

    private def inner_width : Int32
      width - 2 * inset - scrollbar_reserve
    end

    # Tallest stack across every attachment — the logical row-space
    # #scroller scrolls across. 0 when nothing is attached.
    private def total_rows : Int32
      @attachments.max_of? { |attachment| attachment.row + attachment.row_span } || 0
    end

    private def visible_rows : Int32
      [inner_height // @row_height, 0].max
    end

    # A child whose full row range falls entirely outside the current
    # scroll window — used by #composite to skip a #render call
    # guaranteed to be fully clipped anyway (see #composite's doc
    # comment: this is an optimization, not what makes clipping work).
    private def child_visible?(attachment : Attachment) : Bool
      row_bottom = attachment.row + attachment.row_span
      row_bottom > @scroller.offset && attachment.row < @scroller.offset + visible_rows
    end

    # Scrolls minimally so the focused attachment's row range is
    # visible, reusing Scroller#reveal (single-index) twice — once for
    # the attachment's bottom row, once for its top row. The second call
    # wins any conflict (an attachment taller than the viewport), so its
    # TOP ends up visible rather than its bottom: this matches
    # ScrollableField#start always resetting ITS OWN internal scroll to
    # the top when a field starts being edited (see scrollable_field.cr)
    # — Grid's own scroll and a field's internal scroll should agree on
    # what "just got focused" looks like.
    private def reveal_focused : Nil
      return if @attachments.empty?
      focused = @attachments[@focus_index]
      visible = visible_rows
      @scroller.reveal(focused.row + focused.row_span - 1, visible)
      @scroller.reveal(focused.row, visible)
    end

    # Recomputes every attached child's x/y/width/height from its
    # (col, row, col_span, row_span), @col_weights, @row_height, and the
    # current scroll offset — the same "parent writes directly to child
    # geometry properties" technique HSplit#layout uses for its two
    # panes, generalized to an attachment list. Column pixel widths are
    # re-derived from @col_weights against Grid's *current* width every
    # call (see #col_widths), so a Grid resized after children were
    # attached reflows them automatically. Row y-offsets are
    # `(row - scroller.offset) * @row_height`, so row_span reserves
    # `row_span * @row_height` rows starting there — a later attachment
    # whose `row` lands inside an earlier row_span's reserved span
    # simply overlaps it, the same way a caller misusing FieldSpec#rows
    # today could overlap two fields; Grid does not police this. A
    # child's own height is left as its FULL row_span * row_height even
    # when scrolled to only partially visible — #composite's clip, not a
    # shrunk height, is what bounds the visible portion (see class doc
    # comment), so the child's own #render stays completely oblivious to
    # scrolling.
    private def layout : Nil
      @scroller.clamp(total_rows, visible_rows)
      widths = col_widths
      offsets = widths.each_with_object([0]) { |col_width, acc| acc << acc.last + col_width }

      @attachments.each do |attachment|
        attachment.child.x = x + inset + offsets[attachment.col]
        attachment.child.y = y + inset + (attachment.row - @scroller.offset) * @row_height
        attachment.child.width = widths[attachment.col, attachment.col_span].sum
        attachment.child.height = attachment.row_span * @row_height
      end
    end

    # Converts @col_weights into actual pixel widths summing to exactly
    # #inner_width (never more, never less — #inner_width already
    # excludes both border insets and any reserved scrollbar column, see
    # #scrollbar_reserve) by flooring each column's proportional share
    # and handing any remainder from integer rounding to the last
    # column — same rounding-remainder handling HSplit#layout gets for
    # free from `.round.to_i` on a single split point; with N columns
    # the remainder has to be assigned somewhere explicit instead.
    private def col_widths : Array(Int32)
      available = [inner_width, 0].max
      total_weight = @col_weights.sum
      return @col_weights.map { 0 } if total_weight == 0

      widths = @col_weights.map { |weight| available * weight // total_weight }
      widths[-1] += available - widths.sum
      widths
    end
  end
end
