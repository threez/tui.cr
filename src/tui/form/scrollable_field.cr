require "./form_field"
require "../widget/scroller"
require "../widget/scroll_control"

module TUI
  # Adapts any Scrollable with a #value : String getter (TextEdit,
  # MarkdownEdit, or any future syntax-specific TextEdit subclass) into a
  # FormField, so a form field can reuse a Scrollable's existing
  # scrolling multi-line editor instead of InputField's single-line-only edit
  # state. Reuses 100% of the wrapped widget's editing logic — this adds
  # only the same small amount of glue Window already does to host a
  # Scrollable (own a Scroller, fabricate a ScrollControl each call, blit
  # a scratch buffer into the region FormField#render was given), just at
  # FormField's smaller scale instead of Widget's.
  #
  # `T` is deliberately unconstrained (Crystal has no clean "includes
  # Scrollable and has #value" bound) — a `T` missing #value or the
  # Scrollable methods this class calls simply fails with Crystal's
  # ordinary "undefined method" compile error at the call site, the same
  # tradeoff TUI::Form.define's own macro already accepts for a model
  # property typo.
  #
  # Esc always commits (there's no discard-in-place gesture, matching
  # InputField's/BoolField's stated Esc convention — this is a free-text
  # editing kind, not a picker). Esc is intercepted by this wrapper
  # itself, never passed to `@content`: TextEdit#handle_key has no Esc
  # case today and must not gain one just for this, since standalone
  # full-screen TextEdit/MarkdownEdit (Window.full_screen) has no commit
  # concept and must keep behaving exactly as before. Enter is NOT
  # intercepted — it flows through unchanged and inserts a newline,
  # exactly like TextEdit's existing standalone behavior.
  class ScrollableField(T) < FormField
    @content : T

    # Applied to the scrollbar track/thumb drawn by #render.
    property scrollbar_style : Style = Style.new(fg: TUI.color(:gray))

    def initialize(@build : String -> T)
      @content = @build.call("")
      @scroller = Scroller.new
      @last_height = 1
    end

    # `T` has no reseed method (no TextEdit#value=), so this replaces
    # `@content` wholesale with a freshly built instance — mirrors every
    # other FormField getting a fresh instance per edit session, just
    # done one level down (Form::Host's `field.build.call` only
    # constructs this wrapper once; #start is the only hook that ever
    # sees the wire value).
    def start(current_value : String) : Nil
      @content = @build.call(current_value)
      @scroller.reset
    end

    def handle_key(ev : KeyEvent) : Symbol?
      return :commit if ev.key == Key::Esc
      @content.handle_key(ev, ScrollControl.new(@scroller, @last_height))
      nil
    end

    def value : String
      @content.value
    end

    # `height` bounds how many buffer rows this field may draw into,
    # same contract as every other FormField#render. Always reserves the
    # last column of `width` for a scrollbar track — same convention
    # Window follows for its own border's right column (see
    # Window#render, which reserves inner_width = width - 2*inset
    # unconditionally, scrollbar or not) — rather than sizing content to
    # the full `width` when nothing needs to scroll and to `width - 1`
    # when it does: since content_size depends on the width content
    # wraps against, a conditional width would make "does this need a
    # scrollbar" and "how wide is the content" mutually dependent.
    # Reserving unconditionally keeps content_size stable across renders
    # and #handle_key calls, both of which must agree on the same
    # ScrollControl visible/width. Buffer#scrollbar itself no-ops
    # (leaving the column blank) when #fraction is nil, so a field that
    # never overflows just shows a blank last column, not a misleading
    # always-on track.
    #
    # Builds a scratch Buffer sized to the remaining content width since
    # Scrollable#render_content expects one sized to exactly its own
    # content area (it has no notion of drawing into a sub-rectangle of
    # a larger buffer), then blits every cell into `buffer` at the given
    # (y, x) offset — this is Window#blit_inner's body, copied at field
    # scale since Buffer has no sub-region blit primitive to call into
    # directly and Window#blit_inner is private/Window-shaped.
    def render(buffer : Buffer, y : Int32, x : Int32, width : Int32, height : Int32 = 1, focused : Bool = true) : Nil
      @last_height = height
      @content.focus_if(focused)
      content_width = [width - 1, 0].max
      total = @content.content_size
      @scroller.clamp(total, height)
      scroll = ScrollControl.new(@scroller, height)

      scratch = Buffer.new(content_width, height)
      @content.render_content(scratch, scroll)

      height.times do |row|
        content_width.times do |col|
          buffer.set_cell(y + row, x + col, scratch.cell(row, col))
        end
      end

      buffer.scrollbar(y, x + width - 1, height, @scroller.fraction(total, height), visible: height, total: total, style: scrollbar_style, inset: 0)
    end

    def status_hint : String
      @content.status_hint + "  Esc:commit"
    end
  end
end
