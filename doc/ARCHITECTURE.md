# Architecture

`tui.cr` is a layered Crystal TUI library: each layer has a single,
narrow contract, and higher layers compose lower ones rather than
reaching around them. There's no framework magic and no unused surface
area — it was extracted from two real consumer apps (pkgx, prostore.cr),
so every abstraction exists because something concrete needed it.

## Layering

```
Term, Keys              terminal I/O primitives (ANSI codes, box glyphs,
                        raw-mode toggles; raw-byte -> KeyEvent parsing)
   |
Buffer                  a widget-local grid of (char, style) cells
   |
Screen                  owns front/back Buffer; blit + diff-flush
   |
Widget                  x/y/width/height, owns a Buffer, composite()
   |
Scrollable  <--hosted-by--  Window / SplitWindow
(content contract:          (Widget subclasses: border, scrollbar,
 no position, no buffer,     Scroller(s), routes clicks/keys into
 no scroller of its own)     the Scrollable(s) they host)
   |
ListView -> TableView, DetailView, Popup, FormField, Picker(W), OptionListView/MultiOptionListView -> DropdownPicker
   |
NavStack(Widget) + Runtime   app shell: stack of full-screen widgets,
                             terminal lifecycle, render/read/dispatch loop
```

`HSplit` sits beside `Window`/`SplitWindow` as a lower-level sibling: it
lays out two independent `Widget`s (not `Scrollable`s) with a plain
divider and no shared border, for cases where each pane is already
fully self-contained.

## Render pipeline

The library never clears the screen between frames. Every redraw is a
diff against the previous frame, which is what keeps it flicker-free.

- **`Buffer`** (`src/tui/core/buffer.cr`) is a widget-local grid of
  `BufferCell` (`record BufferCell, char : String = " ", style : String
  = ""`) — a value type, so cell-to-cell comparison is structural.
  `Buffer#set(row, col, s)` parses a string for embedded ANSI escape
  codes and tracks a running style accumulator, attaching the
  accumulated style to each subsequent plain character's cell rather
  than storing escape codes as their own cells — this is what lets
  `Screen` diff `(char, style)` pairs per cell instead of re-emitting
  escape codes for every character. `Buffer` also owns box/line/scrollbar
  drawing (`box`, `box_with_divider`, `hline`, `vline`, `scrollbar`)
  built from `Term`'s glyph constants.

- **`Screen`** (`src/tui/core/screen.cr`) owns a front/back `Buffer` pair
  sized to the terminal (`Term.size`).
  - `blit(x, y, buffer)` composites a widget's local buffer onto the
    back buffer at absolute 1-based coordinates `(x, y)`.
  - `at(row, col, s)` / `status_bar(row, text)` write directly onto the
    back buffer for app-level chrome (status bar, dividers) that no
    widget owns.
  - `flush` walks every cell, diffs back against front, and emits only
    the cells that changed — a targeted `Term.move` plus the new
    char/style — then swaps front/back and clears the new back buffer.
    Style state is explicitly reset at every row boundary: without
    that, a terminal or multiplexer (e.g. tmux) can paint untouched
    cells past the last styled one using whatever SGR was last active,
    bleeding a border's highlight or a stale color across the row.
  - `refresh_size` (called on `SIGWINCH`) force-clears the real
    terminal before reallocating fresh buffers — a shrinking terminal
    can leave stale content outside the new smaller grid that the
    normal diff would never revisit, since it only iterates the current
    row/col count. This is a one-time cost on resize, not per-frame, so
    it doesn't reintroduce flicker.

- **`Widget`** (`src/tui/widget/widget.cr`) is the abstract base for every
  top-level, independently positioned thing: `x`/`y`/`width`/`height`,
  `focused?`, and an owned `@buffer : Buffer`. Subclasses implement:
  - `render : Nil` — draw into `@buffer` using **local** coordinates
    (0,0 = this widget's own top-left). Widgets never need to know
    their own screen offset to draw themselves.
  - `handle_key(ev : KeyEvent) : Bool` — return whether the event was
    consumed.
  - `status_hint : String` — text for the app's global status bar;
    widgets must not draw their own hint line.

  `composite(screen)` is the template method every widget gets for
  free: reallocate `@buffer` if `width`/`height` changed (else just
  clear it), call `render`, then `screen.blit(x, y, @buffer)`.
  `absolute(row, col)` / `local(row, col)` convert between a widget's
  local coordinate space and the terminal's — used for placing the real
  cursor (e.g. `TextField#cursor_offset`) and for translating an
  absolute mouse event down into a widget's local space, respectively.
  `local`'s result may fall outside the widget's bounds; callers must
  bounds-check.

The terminal's own cursor is kept hidden across frames by design —
selection/focus is conveyed by drawing reverse-video or block-glyph
styling into buffers, not by moving the real cursor. The one documented
exception is text editing (`TextField`), which needs to show and
position the real cursor between flushes via `Widget#absolute`.

## Input pipeline

- **`Keys.read(io)`** (`src/tui/core/keys.cr`) parses raw bytes into a
  `KeyEvent` (`record KeyEvent, key : Key, char : Char = '\0', row :
  Int32? = nil, col : Int32? = nil`). It reads one byte, maps simple
  control characters directly, and for `\e` reads the following byte
  within a 50ms timeout to distinguish a lone Esc keypress from the
  start of an escape sequence. CSI sequences are matched against known
  terminators (arrows, Home/End, Page Up/Down, Delete); `\e[<...M/m`
  is parsed as an SGR mouse report (enabled at runtime via
  `Term.enter_mouse`) — wheel ticks and button presses become
  `MouseWheelUp`/`MouseWheelDown`/`MouseClick(row:, col:)`; only press
  events (not release, not motion) are surfaced.

- **`Runtime`**'s `read_dispatch_loop` reads one `KeyEvent` per
  iteration and calls `@on_key.call(ev)` — Runtime special-cases only
  `Key::CtrlC`/`Key::CtrlD` to exit the loop; it has zero opinion about
  what any other key (including `'q'`) does. All key semantics live in
  the app-supplied `@on_key` callback and in each `Widget#handle_key`.
  The `Bool` return from `handle_key` is a "did you consume this"
  contract callers use to decide whether to bubble the event further —
  see `NavStack#handle_esc`'s "delegate to child, pop only if
  unconsumed" idiom below.

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
  reset/clamp logic.

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

## Widget catalog

| Widget | Backed by | Notes |
|---|---|---|
| `ListView` (abstract) | `ListDataSource` (`size`, `title(filter, sort_key)`, `sort_keys`, `reload(filter, sort)`) | Cursor movement, `/`-filter, `s`-sort-cycle, double-click-activate via `ClickTracker`, mouse wheel. Subclasses implement `row_content(index)`; `render_header`/`content_row_offset` are the hooks `TableView` overrides to inject a header row. |
| `TableView < ListView` | `TableDataSource < ListDataSource` (adds `columns`, `row(index) : TableRow`) | `TableColumn` has `min_width`/`preferred_width`/optional `expand`. `compute_col_widths`: start every column at `preferred_width`; if the total exceeds available space, shrink all to `min_width` then distribute remaining slack proportional to shrinkable headroom; otherwise give slack only to `expand` columns proportional to their share, with the last expanding column absorbing the rounding remainder. |
| `DetailView` | `DetailDataSource` (`title(id)`, `lines(id, expansions)`, `toggles`, `toggle_label(sym)`) | Standalone `Scrollable`, not part of the `ListView` chain (no cursor/selection concept). Expandable sections keyed by symbols mapped from `source.toggles` order, via an internal `KeyMenu`. Soft-wraps long values with a dim `\` continuation marker. `load(id)` clears expansions and rebuilds lines — caller must separately call the hosting `Window#reset_scroll`. |
| `Cell` / `CellStyle` | — | `record Cell, text, style : Symbol?`. One style per cell — no composition (can't be both dim and colored). |
| `TypeStyle` | — | Maps a SQL-ish column type to a `Cell` style. Deliberately narrow: generic numeric/bool/time/bytes coloring only; domain-specific coloring belongs in the app's own `DataSource`. |
| `Popup` | — | Small, centered, non-full-screen `Widget`, dismissed by any key. Pushed via `NavStack#push` directly, bypassing `Runtime`'s forced full-screen resize, so it keeps the size `.centered` computed for it. |
| `FormField` (abstract) | — | Not a `Widget`/`Scrollable` itself — a plain embedded helper a host widget delegates to while `editor != nil`. One concrete class per kind — `TextField`, `BoolField`, `EnumField`, `FlagsField` — since the kinds share almost no mechanics. `TextField`/`BoolField` commit on Esc (no other discard gesture exists for them); `EnumField`/`FlagsField` cancel on Esc instead (a picker with nothing chosen has no sensible commit value). |
| `Picker(W)` | `Pickable` (`selected_value : String?`) | Pure decorator wrapping any `Pickable` widget as a modal value-picker: Enter reports the selection if non-nil, Esc cancels, listed chars are suppressed, everything else passes through unchanged. Does not modify the wrapped widget. |
| `OptionListView`/`MultiOptionListView` | `OptionListSource` (`Array(FormEnumOption)` + substring filter) | Single/multi-select `ListView`s backing `DropdownPicker`'s popup. `on_activate`'s index (single-select) and `MultiOptionListView`'s toggle state are only ever meaningful relative to the currently-filtered list — resolve via `option_source.option_at(index)`/`wire_value`, never a caller's own unfiltered options array by raw index. Multi-select confirms the whole selected set (by `wire_value`, a stable identity) via `on_confirm` on Enter, not per-row `on_activate`. |
| `DropdownPicker` | — | Factory building a centered, content-sized `Window` — the `Popup.centered` counterpart for an interactive searchable option list instead of static text. `.centered`/`.centered_multi`. Pushed the same way as `Popup` (`NavStack#push` directly); Esc-cancel needs no special dispatch handling since any non-`Popup` widget already pops generically on unconsumed Esc via `Runtime#handle_esc`. |
| `Validation` | — | Pure string validators (`valid_time?`, `valid_int?`, `valid_float?`, `valid_decimal?`), no widget state or I/O — meant to validate a `TextField#value` string before a host allows commit. |
| `KeyMenu` | — | Registry of `{trigger, label, when:, action}` bindings backing both `dispatch` and `hint` off the same active-binding set, so the two can never drift apart. Deliberately excludes `MouseClick` — a click has no stable label and needs widget-specific coordinate math, which stays in `Window`/`SplitWindow`. `DetailView` uses one internally for its toggle letters. |
| `ClickTracker` | — | Standalone double-click detector (`DEFAULT_THRESHOLD = 400.milliseconds`); `register` returns true only for the same target within the threshold, resetting its own state on a true double-click so a third rapid click starts a fresh pair rather than chaining into a triple-click. Driven by content's own `handle_click` (e.g. `ListView`'s). |

## App shell

- **`NavStack(T)`** (`src/tui/nav/nav_stack.cr`) is a deliberately minimal
  stack: `push`/`pop`/`current`, plus `replace_base` for swapping the
  bottom of the stack in place when an app's root screen changes shape
  based on runtime state. `pop` refuses to pop the last remaining
  entry. `handle_esc(consumed, &on_pop)` is the "delegate to child, pop
  only if unconsumed" idiom used anywhere a stack of views is
  keyboard-navigable. `push`/`pop` are plain primitives an app can also
  call directly to bypass the normal flow — e.g. pushing a `Popup`
  without triggering a resize.

- **`Runtime`** (`src/tui/runtime.cr`) owns everything an app shouldn't
  have to reimplement: entering/leaving the alt screen, raw mode, mouse
  reporting (all torn down via `at_exit`), `SIGWINCH`-driven resize, and
  the render → read-key → dispatch loop. It wraps a `NavStack(Widget)`
  and layers auto-resize on top of its push/pop/replace_base:
  - `push`/`pop`/`replace_base` each resize the widget being
    revealed/pushed to the current screen (`sync_size`) before the next
    render — which is why callers should always route widget lifecycle
    through these, not `NavStack` directly and not hand-rolled
    `Term.enter_alt_screen`/raw-mode calls. The one sanctioned exception
    is `Popup`, pushed at a deliberately non-full-screen size via
    `@nav.push` directly.
  - the private `render` method calls `nav.current.composite(@screen)`,
    then `@screen.status_bar(@screen.rows, widget.status_hint)`, then
    `@screen.flush` — tying the render pipeline, the widget's own
    status hint, and the diff-flush together every frame.
  - `resize` (on `SIGWINCH`) calls `@screen.refresh_size`, resyncs the
    current widget's size, and re-renders.
  - `render_now` forces a synchronous render+flush outside the normal
    loop, for a long blocking operation that emits progress via
    callbacks and needs the screen repainted between the loop's normal
    render points.

## Design invariants

- Widgets always draw in local coordinates and never know their own
  screen offset — `composite`/`blit`/`absolute`/`local` centralize that
  arithmetic in one place.
- `Runtime` has no opinion about key semantics beyond Ctrl-C/Ctrl-D;
  every other binding (including `'q'`) is entirely up to the app.
- A `Scrollable` never owns positioning, a buffer, or a `Scroller` —
  that's always supplied by whatever hosts it (`Window`/`SplitWindow`).
- `SplitWindow` never hides a pane — an app that needs a pane to
  appear/disappear swaps what's at the base of a `NavStack` instead.
- Recompute `focused` every frame from whatever state determines the
  active widget (`focus_if`), rather than mutating `focused=`
  incrementally at scattered call sites.
- The real terminal cursor stays hidden across frames by design;
  selection/focus is conveyed via styling drawn into buffers, with an
  explicit escape hatch for text editing.
- A `KeyMenu`'s dispatch and its displayed hint text are generated from
  the exact same binding data, so they can never drift apart.

## DSL mode

`TUI::Form.define`, `TUI::ArrayTableSource.define`, and
`TUI::ArrayDetailSource.define` are macro-based sugar over
`FieldSpec(M)`/`ArrayTableSource(T)`/`ArrayDetailSource(T)`
construction — purely additive, generating the same objects the plain
constructors already produce from a terser `field`/`column`/`line`
block syntax. See [dsl.md](dsl.md) for the full kwarg surface, the
Crystal macro-system constraints (class-in-expression-position,
class-in-`def`, `instance_vars` timing) that shaped all three, and the
explicit reasoning for which remaining classes deliberately do NOT get
DSL sugar (most of this library's other constructors are either trivial
or already collapsed via a plain `.full_screen`/`.centered` factory
method with no macro needed).

## Testing conventions

Specs are behavioral, not pixel-based: widgets and data sources are
exercised against small stub/fixture test doubles (`StubScrollable`,
`PlainListSource`, etc.), asserting on recorded calls/state rather than
inspecting rendered buffer contents. The one deliberate exception is
`buffer_spec.cr`, which asserts on `Buffer#box_with_divider`'s exact
junction-character placement — there, the character *is* the behavior
under test. Run the suite with:

```sh
crystal spec
crystal build --no-codegen src/tui.cr # fast compile-only check
```
