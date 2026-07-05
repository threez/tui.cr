# tui.cr

Minimal Crystal TUI primitives: a diffing screen compositor, a handful of
composable widgets (lists, tables, detail views, scrollable panes, splits,
modals), and an app-shell (`Runtime`) that owns terminal lifecycle and the
render/read-key/dispatch loop. Built incrementally against a real consumer
app rather than designed up front, so every piece exists because something
needed it — there's no unused surface area.

See [doc/ARCHITECTURE.md](doc/ARCHITECTURE.md) for the full layering,
render/input pipelines, and widget catalog, and [doc/dsl.md](doc/dsl.md)
for the macro-based DSL layer described below.

## Installation

```yaml
dependencies:
  tui:
    path: ../tui.cr # or a git source once published
```

```crystal
require "tui"
```

## Core model

Three layers, each with a narrow, single-purpose contract:

- **`Buffer`** — a widget-local grid of cells (`tui/core/buffer.cr`). Widgets
  draw into their own buffer using local coordinates; a cell tracks a
  running ANSI style so `Screen` can diff `(char, style)` pairs per cell
  rather than re-emitting escape codes for every character.
- **`Screen`** (`tui/core/screen.cr`) — owns a front/back `Buffer` pair sized to
  the terminal. `blit` composites a widget's buffer onto the back buffer
  at its `(x, y)`; `flush` diffs back against front and writes only the
  changed cells, then swaps. This is what makes redraws flicker-free —
  never `\e[2J` between frames, only targeted `\e[H`-style cursor moves
  for cells that actually changed.
- **`Widget`** (`tui/widget/widget.cr`) — the abstract base every top-level,
  independently-positioned thing implements: `x`/`y`/`width`/`height`,
  `render` (draw into `@buffer` using local coords), `handle_key`,
  `status_hint`. `composite(screen)` is the template method every widget
  gets for free: resize/clear the buffer, call `render`, blit onto the
  screen. `absolute`/`local` convert between a widget's own coordinate
  space and the terminal's, for translating mouse events.

## The Scrollable / Window split

A `Widget` owns its own position, buffer, and (if it wants one) a border
and scrollbar. Most content, though, doesn't want to duplicate that
scaffolding — a table, a list, a detail pane all just want "here's my
data, tell me what's visible." That's `Scrollable` (`tui/widget/scrollable.cr`):
no `x`/`y`, no `Buffer`, no `Scroller` of its own. It implements
`content_size`, `render_content(buffer, scroll)`, `handle_key(ev, scroll)`,
`handle_click(row, col, scroll)`, `title`, `status_hint`.

`Window` (`tui/widget/window.cr`) is the `Widget` that hosts exactly one
`Scrollable`: it owns the border, the scrollbar, and a `Scroller` (pure
offset/viewport math, `tui/widget/scroller.cr`), and hands content a
`ScrollControl` (`tui/widget/scroll_control.cr`) each render — a narrow struct
wrapping the `Scroller` plus the viewport size for that frame, so content
can call `scroll.reveal(i)` / `scroll.up` / `scroll.wheel_down` without
owning or resizing anything itself. Pass `bordered: false` to embed the
same content in a layout (e.g. inside `HSplit`) without double borders.

`SplitWindow` (`tui/layout/split_window.cr`) generalizes this to two panes in one
outer box: two independent `Scrollable`s, two independent `Scroller`s, one
shared border with the internal divider merged in via T-junction
characters (`Buffer#box_with_divider`). `Tab` toggles which pane is
active; clicking a pane both routes the click to it and activates it.
Both panes always render — there's no hide/show built in, so an app that
needs a side panel to appear/disappear should swap which widget sits at
the base of its `NavStack` (see `Pkgx::App` in the pkgx repo for a worked
example) rather than expecting `SplitWindow` to collapse itself. Call
`#focus_left` when re-showing a reused `SplitWindow` instance if you want
focus to reset to the left pane rather than carrying over whatever was
active before it was last hidden.

`HSplit` (`tui/layout/hsplit.cr`) is the lower-level sibling: it positions
two full `Widget`s side by side with a plain divider and no border of its
own. Like `SplitWindow`, `Tab` toggles which pane is active and routes
keys to it, with `focus_if` driven from the active pane each render;
`#focus_left` resets focus back to the left pane for a reused instance.
Reach for it when you have two independently-bordered/unbordered widgets
to place side by side; reach for `SplitWindow` when you want one shared
border around two `Scrollable` content panes.

## Widgets

- **`ListView`** (`tui/widgets/list_view.cr`) — abstract `Scrollable` base:
  cursor movement, incremental filter (`/`), sort-key cycling (`s`),
  double-click-to-activate (via `ClickTracker`), mouse wheel. Subclasses
  implement `row_content(index)` and back it with a `ListDataSource`
  (`size`, `title`, `sort_keys`, `reload`).
- **`TableView < ListView`** (`tui/widgets/table_view.cr`) — adds a header
  row and column layout (`TableColumn`: `min_width`/`preferred_width`,
  optional `expand`) over a `TableDataSource` (`columns`, `row(index)`
  returning a `TableRow` of `Cell`s). Column widths shrink to `min_width`
  under pressure and hand slack to `expand`-marked columns otherwise.
- **`DetailView`** (`tui/widgets/detail_view.cr`) — label/value pairs from
  a `DetailDataSource`, with expandable sections (arbitrary symbols
  toggled by the first N letters of the alphabet, mapped from
  `source.toggles` order) and soft-wrapping for long values.
- **`Cell`** / **`CellStyle`** (`tui/widgets/cell.cr`) — `record Cell,
  text, style : Symbol?`; `CellStyle.apply` maps a style symbol
  (`:dim`, `:bold`, `:green`, `:red`, `:yellow`, `:blue`, `:magenta`,
  `:cyan`, `:white`) to the matching `Term` helper. One style per cell —
  no composition (can't be both dim and colored).
- **`TypeStyle`** (`tui/widgets/type_style.cr`) — maps a SQL-ish column
  type (portable type tag or raw type text) to a `Cell` style, for apps
  browsing arbitrary database schemas. Deliberately narrow: only generic
  numeric/bool/time/bytes coloring; app-specific/domain coloring belongs
  in the app's own `DataSource`.
- **`Popup`** (`tui/popup.cr`) — small, centered, non-full-screen `Widget`
  with a title and a message, dismissed by any key. Push it via
  `NavStack#push` directly (not `Runtime#push`, which forces every pushed
  widget to full-screen) so it keeps the size `.centered` computed for it.
- **`FormField`** (`tui/form/form_field.cr`) — abstract in-place edit
  state machine for a single field, one concrete class per kind —
  `TextField`, `BoolField`, `EnumField`, `FlagsField` — since the kinds
  share almost no mechanics, for apps that let you edit a row's fields
  inline. `TextField`/`BoolField` commit on Esc (no discard gesture);
  `EnumField`/`FlagsField` cancel on Esc instead, since a picker with
  nothing chosen has no sensible commit value.
- **`Picker(W)`** (`tui/nav/picker.cr`) — wraps any widget implementing
  `Pickable` (`selected_value : String?`) as a modal value-picker: Enter
  reports the selection, Esc cancels, listed chars are suppressed (e.g.
  to block mutating keys while picking), everything else passes through
  unchanged. Does not modify the wrapped widget.
- **`OptionListView`/`MultiOptionListView`** (`tui/widgets/option_list.cr`)
  — single/multi-select `ListView`s over a flat `Array(FormEnumOption)`,
  backing `DropdownPicker`'s popup. `MultiOptionListView` tracks
  selection by `wire_value`, never by list index — an option's index
  shifts as the `/` filter narrows the visible rows, so only its
  `wire_value` is a stable identity across a filter change.
- **`DropdownPicker`** (`tui/widgets/dropdown_picker.cr`) — factory building a
  centered, content-sized `Window` (the `Popup.centered` counterpart for
  an interactive option list rather than static text): `.centered`
  (single-select, reports via `on_activate`) and `.centered_multi`
  (multi-select, reports the whole set via `on_confirm` on Enter, Space
  toggles independent of cursor movement). Push the returned `Window` via
  `NavStack#push` directly, same as `Popup`, so it keeps its computed
  size instead of being forced full-screen; Esc-cancel needs no special
  handling — an unconsumed Esc already pops any non-`Popup` widget via
  the app's generic `Runtime#handle_esc` path.
- **`Validation`** (`tui/validation.cr`) — pure string validators
  (`valid_time?`, `valid_int?`, `valid_float?`, `valid_decimal?`) for
  field-editing apps; no widget state, no I/O.

## App shell

`Runtime` (`tui/runtime.cr`) owns everything an app shouldn't have to
reimplement: entering/leaving the alt screen, raw mode, mouse reporting,
`SIGWINCH`-driven resize, and the render → read-key → dispatch loop. It's
driven by a `NavStack(Widget)` (`tui/nav/nav_stack.cr` — plain push/pop/current,
plus `replace_base` for swapping the bottom of the stack in place when an
app's root screen changes shape based on runtime state) and an `on_key`
callback for everything Runtime itself has no opinion about (including
what `'q'` should do — that's entirely up to the app).

**Always route interactive widget lifecycle through `Runtime#push` /
`#pop` / `#replace_base`**, not `NavStack` directly and not hand-rolled
`Term.enter_alt_screen`/raw-mode calls — `Runtime` resizes whatever's
pushed/revealed/swapped to the current screen before its next render, and
owns the one alt-screen/raw-mode/signal-trap lifecycle for the whole app.
The one documented exception is a modal you want to push at a
deliberately non-full-screen size (see `Popup` above) — push those via
`@nav.push` directly, bypassing `Runtime`'s forced resize, exactly as
`NavStack`'s own doc comment anticipates.

`Keys` (`tui/core/keys.cr`) parses raw terminal input (including SGR mouse
sequences — clicks, wheel) into a `KeyEvent`. `Term` (`tui/core/term.cr`) is
the escape-code/box-drawing constant table plus small text helpers
(`bold`/`dim`/`fg`/`reverse`, `fit`/`trunc`/`visible_size` for ANSI-aware
width math). Box corners are rounded (`╭╮╰╯`, matching lazygit); the
scrollbar thumb is `▐` (right-half block), also matching lazygit.

## Example

`example/` contains a small "widget browser" app exercising most of the
library's widgets end to end against fabricated in-memory data —
`TableView` with `TypeStyle`-colored columns, `DetailView` with a
toggleable section, `FormField` editing a package's fields (one concrete
class per kind, including two `DropdownPicker` popup fields — a
single-select "Origin" and a multi-select "Dependents"), a `Popup` help
screen, and both `SplitWindow` and `HSplit` layout pages (the latter via
`HSplit.full_screen_scrollables`, wrapping each pane in a borderless
`Window`). `Picker(W)` is deliberately left out — it needs a host widget
built around it and has no existing one in this repo to model against.
Its form fields, table sources, and detail source are declared via the
`TUI::Form.define`/`TUI::ArrayTableSource.define`/`TUI::ArrayDetailSource.define`
DSLs (see [doc/dsl.md](doc/dsl.md)) rather than hand-written
`FieldSpec`/`ArrayTableSource`/`ArrayDetailSource` constructor calls.
Run it in a real terminal with:

```sh
make example
# or: crystal run example/widget_browser.cr
```

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

Any interactive/visual verification should go through `Runtime` in a real
terminal (or tmux), never a hand-rolled `Term.enter_alt_screen` script —
see the app-shell section above.
