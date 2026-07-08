# Widgets

See [architecture.md](architecture.md) for how this fits into the
overall layering, and [rendering.md](rendering.md) for `Widget`/`Screen`
fundamentals this section builds on.

## The Scrollable / Window split

A `Widget` owns its own position, buffer, and (if it wants one) a
border and scrollbar. Most content doesn't want to duplicate that
scaffolding — a table, a list, a detail pane all just want "here's my
data, tell me what's visible." That's what `Scrollable` decouples from
`Window`.

- **`Scrollable`** (`src/tui/widget/scrollable.cr`) is a module with no
  `x`/`y`, no `Buffer`, no `Scroller` of its own. It must implement:
  - `content_size : Int32` — total scrollable rows, **not** including
    any header row (a header is content-internal, e.g. `TableView`'s
    concern, not `Window`'s).
  - `render_content(buffer : Buffer, scroll : ScrollControl) : Nil` —
    render into a buffer already sized to just the content area (the
    border/scrollbar columns are already excluded by the host).
  - `handle_key(ev : KeyEvent, scroll : ScrollControl) : Bool` — all
    non-positional input.
  - `handle_click(local_row : Int32, local_col : Int32, scroll :
    ScrollControl) : Bool` — a mouse event, pre-translated by the host
    into content-local coordinates.
  - `title : String`, `status_hint : String`.

- **`Scroller`** (`src/tui/widget/scroller.cr`) is the mutable scroll-offset
  primitive: just `@offset : Int32` plus `up`/`down`/`reveal(index,
  visible)`/`fraction(total, visible)` (scrollbar thumb position, `nil`
  if content fits — no scrollbar needed) and wheel convenience wrappers
  (`WHEEL_STEP = 3`). `clamp(total, visible)` recomputes a valid offset
  against current sizes and is called every render, so the offset
  self-heals when content shrinks (a filter, a collapsed section) or
  the widget resizes, without every mutation site needing its own
  reset/clamp logic. `Grid` (below) reuses this exact primitive for its
  own row-based scrolling, generalized from one `Scrollable` to a whole
  list of positioned children.

- **`ScrollControl`** (`src/tui/widget/scroll_control.cr`) is a `struct` — a
  narrow handle built fresh each render/key call, pairing a `Scroller`
  with that frame's `visible` viewport size, so content can call
  `scroll.reveal(i)` / `scroll.up` / `scroll.wheel_down` without owning
  or resizing anything itself.

- **`Window < Widget`** (`src/tui/widget/window.cr`) hosts exactly one
  `Scrollable`: it owns the border, the scrollbar, and one `Scroller`.
  Each `render` clamps the scroller against `content_size`/inner
  height, then builds a fresh `ScrollControl` for `render_content`.
  Clicks are translated from absolute to content-local coordinates;
  a click landing outside the content area (e.g. on the border itself)
  is consumed but not forwarded to content. `bordered: false` embeds
  the same content in a layout (e.g. inside `HSplit`) without a double
  border. `reset_scroll` is a manual hook for callers that mutate
  content outside the normal key-handling flow (e.g. `DetailView#load`
  swapping in new data) and need the scroll position zeroed afterward,
  since content itself owns no `Scroller` to reset.

- **`SplitWindow`** (`src/tui/layout/split_window.cr`) generalizes `Window` to
  two independent `Scrollable`s + two independent `Scroller`s sharing
  one outer border, with the internal divider merged into the border
  via T-junction characters (`Buffer#box_with_divider`). `Tab` (via an
  internal `KeyMenu`) toggles which pane is active; clicking a pane also
  activates it (a click on the divider itself is consumed but routed to
  neither pane); only the active pane receives non-positional key
  input. Uniquely among the hosts, `SplitWindow` calls
  `Scrollable#focus_if` on both panes every render (plain `Window` never
  calls it, since with one pane focus is implicit). Both panes always
  render — there's no hide/show built in, so an app that needs a side
  panel to appear/disappear should swap what's at the base of a
  `NavStack` rather than expecting `SplitWindow` to collapse itself.
  `focus_left` resets which pane is active, for reused instances that
  shouldn't carry over stale focus.

- **`HSplit`** (`src/tui/layout/hsplit.cr`) is the lower-level sibling:
  it positions two full `Widget`s side by side with a plain divider and
  no border of its own — reach for it when you have two
  independently-bordered/unbordered widgets (e.g. two `Window`s) to
  place side by side; reach for `SplitWindow` when you want one shared
  border around two `Scrollable` content panes. `HSplit` overrides
  `composite` itself: it draws its own (blank-except-divider) buffer via
  `super` *before* compositing its children — compositing children
  second means each child's `blit` overwrites its own region, so if the
  order were reversed the blank `HSplit` buffer would wipe out whatever
  the children had just drawn. Like `SplitWindow`, `Tab` (via an
  internal `KeyMenu`) toggles which pane is active and routes keys to
  it, driving `focus_if` on both children each render; `#focus_left`
  resets focus back to the left pane for a reused instance.
  `.full_screen_scrollables(screen, left, right, left_width = nil)` is a
  convenience factory for the common case of two `Scrollable`s (not
  arbitrary `Widget`s) placed side by side without a shared border: it
  wraps each in its own borderless `Window` before delegating to
  `.full_screen`, replacing the pattern of hand-computing `left_width`
  and building two matching `Window.new(..., bordered: false)` calls.

- **`Grid`** (`src/tui/layout/grid.cr`) generalizes `HSplit`'s "position
  full `Widget`s directly" idea from 2 fixed panes to an arbitrary
  row/column layout, GTK `Gtk.Grid`-style: `attach(child, col, row,
  col_span, row_span)` places a child at a cell, optionally spanning
  several columns/rows, and `Grid` repositions every attached child's
  `x`/`y`/`width`/`height` directly each `#composite`, the same
  technique `HSplit#layout` uses for its two panes. Column widths are
  relative *weights* (e.g. `[1]` for one full-width column, `[1, 2]`
  for a 1:2 split) converted to pixel widths from `Grid`'s own current
  `width` every layout pass — this toolkit has no size-negotiation
  protocol (a `Widget`'s size is always set by its parent, never
  requested), so columns can't auto-size from child content the way
  GTK's own `Grid` does.

  Focus is a single flat index into attachment order: `Tab`/`Shift+Tab`
  cycle it with wraparound. `Up`/`Down` are a second way to move focus,
  but only as a *fallback*, tried after the focused child's own
  `handle_key` has already declined the key — this is what lets a
  `ScrollableField`-backed cell (below) keep `Up`/`Down` for its own
  cursor movement while being edited, and only fall back to field
  navigation once idle.

  `Grid` scrolls when the total attached row extent (`row + row_span`
  across every attachment) exceeds its own viewport, using an owned
  `Scroller` exactly like `Window` does for its `Scrollable` — except a
  `Grid`'s children are independent `Widget`s that blit themselves
  directly rather than rendering into one shared scratch buffer `Grid`
  could bound on its own, so clipping instead relies on
  `Screen#with_clip` (see [rendering.md](rendering.md#screen)) around
  the per-child composite loop. `PageUp`/`PageDown`/mouse-wheel scroll
  the viewport, in the same fallback tier as `Up`/`Down`, for the same
  reason (`TextEdit`, wrapped by `ScrollableField`, consumes those keys
  unconditionally for its own internal scrolling while being edited).
  Tab/Shift+Tab/Up/Down-driven focus changes auto-reveal the
  newly-focused attachment if it's scrolled out of view.

## Widget catalog

### `ListView` (abstract)

Backed by `ListDataSource` (`size`, `title(filter, sort_key)`,
`sort_keys`, `reload(filter, sort)`). Cursor movement, `/`-filter,
`s`-sort-cycle, double-click-activate via `ClickTracker`, mouse wheel.
Subclasses implement `row_content(index)`; `render_header`/
`content_row_offset` are the hooks `TableView` overrides to inject a
header row.

### `TableView < ListView`

Backed by `TableDataSource < ListDataSource` (adds `columns`,
`row(index) : TableRow`). `TableColumn` has `min_width`/
`preferred_width`/optional `expand`. `compute_col_widths`: start every
column at `preferred_width`; if the total exceeds available space,
shrink all to `min_width` then distribute remaining slack proportional
to shrinkable headroom; otherwise give slack only to `expand` columns
proportional to their share, with the last expanding column absorbing
the rounding remainder.

### `DetailView`

Backed by `DetailDataSource` (`title(id)`, `lines(id, expansions)`,
`toggles`, `toggle_label(sym)`). Standalone `Scrollable`, not part of
the `ListView` chain (no cursor/selection concept). Expandable sections
keyed by symbols mapped from `source.toggles` order, via an internal
`KeyMenu`. Soft-wraps long values with a dim `\` continuation marker.
`load(id)` clears expansions and rebuilds lines — caller must
separately call the hosting `Window#reset_scroll`.

### `MarkdownView`

Owns a parsed `Markdown::Block` AST directly, no external
`DataSource`. Hand-rolled block+inline Markdown parser
(`TUI::Markdown::Parser`/`Inline`/`Wrap`/`Layout` — no runtime shard
dependency). Headings numbered via nested-outline counters reset per
level, since a terminal can't grow font size for `#`/`##`/`###`. Real
word-wrap (`Markdown::Wrap.wrap`) preserves inline styling across wrap
boundaries via `InlineRun` spans. Nested lists indent continuations
under the text column, not the marker. GFM tables get alignment-aware
column widths and box-drawing borders. `render_content`'s buffer width
isn't known to `content_size` (`Window#render` calls `content_size`
before building the inner buffer) — `MarkdownView` re-lays-out lazily
keyed on last-known width, one frame stale across an active resize and
self-healing the same frame `render_content` next runs, matching
`Scroller#clamp`'s existing resize-tolerance philosophy rather than
widening `Scrollable`'s abstract contract.

### `TextEdit`

`include Scrollable`. Multi-line, soft-wrapping, scrolling text editor,
hosted standalone (e.g. `Window.full_screen(screen, TextEdit.new(...))`)
or wrapped as a form field (see `ScrollableField` below). Owns its own
cursor and per-line syntax-highlighter hook (`#highlighter : (String ->
Array(Cell))?`); `MarkdownEdit < TextEdit` wires that hook to a
Markdown-aware highlighter without `TextEdit` itself knowing about any
one syntax.

### `Cell` / `CellStyle`

`record Cell, text, style : Symbol?`. One style per cell — no
composition (can't be both dim and colored).

### `TypeStyle`

Maps a SQL-ish column type to a `Cell` style. Deliberately narrow:
generic numeric/bool/time/bytes coloring only; domain-specific coloring
belongs in the app's own `DataSource`.

### `Popup`

Small, centered, non-full-screen `Widget`, dismissed by any key. Pushed
via `NavStack#push` directly, bypassing `Runtime`'s forced full-screen
resize, so it keeps the size `.centered` computed for it.

### `FormField` (abstract)

Not a `Widget`/`Scrollable` itself — a plain embedded helper
`FormFieldCell` (below) delegates to while `editor != nil`. One
concrete class per kind, since the kinds share almost no mechanics:
`InputField` (single-line only), `BoolField`, `EnumField`,
`FlagsField`, `ScrollableField(T)`. `InputField`/`BoolField`/
`ScrollableField` commit on Esc (no other discard gesture exists for
them); `EnumField`/`FlagsField` cancel on Esc instead (a picker with
nothing chosen has no sensible commit value).

### `ScrollableField(T)`

Wraps any `Scrollable` with `#value : String`. Adapts `TextEdit`/
`MarkdownEdit` into a `FormField`, so a form field can be multi-line
and scrolling instead of `InputField`'s single-line-only editing. Owns
a `Scroller` and blits a scratch buffer into whatever region
`FormFieldCell` gives it (`FormField#render`'s contract), the same
technique `Window` uses to host a `Scrollable`, just at `FormField`'s
smaller scale. Esc commits (matching `InputField`'s convention); Enter
is *not* intercepted, so it inserts a newline exactly like `TextEdit`'s
standalone behavior — all commit semantics live in the wrapper, not in
`TextEdit` itself, so standalone `Window`-hosted `TextEdit`/
`MarkdownEdit` is unaffected.

### `FormFieldCell(M)`

Backed by one `FieldSpec(M)`. A `Widget` wrapping one form field's
label + `FormField` edit session (start/commit/cancel, inline
validation error rendering, the `DropdownPicker`-popup bypass for
`dropdown_options` fields). `Form::Host` builds one per `FieldSpec` and
attaches them into an internal `Grid` (above) instead of hand-computing
row/column layout itself.

### `Form::Host(M)`

Backed by `Array(FieldSpec(M))`. Thin builder over an internal `Grid`:
constructs one `FormFieldCell` per field (`row_span: field.rows`),
attaches them, and delegates `render`/`handle_key`/`status_hint`/
`composite` straight through. Owns only the outer box/title chrome —
layout, per-field focus, and scrolling when a form has more fields than
fit on screen are all `Grid`'s job now. See [dsl.md](dsl.md) for
`TUI::Form.define`, the macro sugar over `FieldSpec` construction.

### `Picker(W)`

Backed by `Pickable` (`selected_value : String?`). Pure decorator
wrapping any `Pickable` widget as a modal value-picker: Enter reports
the selection if non-nil, Esc cancels, listed chars are suppressed,
everything else passes through unchanged. Does not modify the wrapped
widget.

### `OptionListView` / `MultiOptionListView`

Backed by `OptionListSource` (`Array(FormEnumOption)` + substring
filter). Single/multi-select `ListView`s backing `DropdownPicker`'s
popup. `on_activate`'s index (single-select) and
`MultiOptionListView`'s toggle state are only ever meaningful relative
to the currently-filtered list — resolve via
`option_source.option_at(index)`/`wire_value`, never a caller's own
unfiltered options array by raw index. Multi-select confirms the whole
selected set (by `wire_value`, a stable identity) via `on_confirm` on
Enter, not per-row `on_activate`.

### `DropdownPicker`

Factory building a centered, content-sized `Window` — the
`Popup.centered` counterpart for an interactive searchable option list
instead of static text. `.centered`/`.centered_multi`. Pushed the same
way as `Popup` (`NavStack#push` directly); Esc-cancel needs no special
dispatch handling since any non-`Popup` widget already pops generically
on unconsumed Esc via `Runtime#handle_esc`.

### `Validation`

Pure string validators (`valid_time?`, `valid_int?`, `valid_float?`,
`valid_decimal?`), no widget state or I/O — meant to validate a
`FormField#value` string before a host allows commit.

### `KeyMenu`

Registry of `{trigger, label, when:, action}` bindings backing both
`dispatch` and `hint` off the same active-binding set, so the two can
never drift apart. Deliberately excludes `MouseClick` — a click has no
stable label and needs widget-specific coordinate math, which stays in
`Window`/`SplitWindow`/`Grid`. `DetailView` uses one internally for its
toggle letters.

### `ClickTracker`

Standalone double-click detector (`DEFAULT_THRESHOLD =
400.milliseconds`); `register` returns true only for the same target
within the threshold, resetting its own state on a true double-click so
a third rapid click starts a fresh pair rather than chaining into a
triple-click. Driven by content's own `handle_click` (e.g. `ListView`'s).
