# Architecture

`tui.cr` is a layered Crystal TUI library: each layer has a single,
narrow contract, and higher layers compose lower ones rather than
reaching around them. There's no framework magic and no unused surface
area — it was extracted from two real consumer apps (pkgx, prostore.cr),
so every abstraction exists because something concrete needed it.

This file is the map. See:

- [rendering.md](rendering.md) — the render pipeline (`Buffer`,
  `Screen`, `Widget`) and the input pipeline (`Keys`, `KeyEvent`).
- [widgets.md](widgets.md) — the `Scrollable`/`Window`/`Grid` split and
  the full widget catalog.
- [app-shell.md](app-shell.md) — `NavStack` and `Runtime`, the app-level
  scaffolding every consumer wires up once.
- [dsl.md](dsl.md) — the macro-based DSL layer (`Form.define`,
  `ArrayTableSource.define`, `ArrayDetailSource.define`).

## Layering

```
Term, Keys              terminal I/O primitives (ANSI codes, box glyphs,
                        raw-mode toggles; raw-byte -> KeyEvent parsing)
   |
Buffer                  a widget-local grid of (char, style) cells
   |
Screen                  owns front/back Buffer; blit + diff-flush;
                        Screen#with_clip bounds blit to a rect
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
Grid                    positions arbitrary Widgets (not just
                        Scrollables) by row/column, GTK-style; scrolls
                        and clips via Screen#with_clip when attached
                        content overflows its own viewport
   |
NavStack(Widget) + Runtime   app shell: stack of full-screen widgets,
                             terminal lifecycle, render/read/dispatch loop
```

`HSplit` sits beside `Window`/`SplitWindow` as a lower-level sibling: it
lays out two independent `Widget`s (not `Scrollable`s) with a plain
divider and no shared border, for cases where each pane is already
fully self-contained. `Grid` generalizes that same "position full
`Widget`s directly" idea from 2 fixed panes to N cells in a row/column
layout — see [widgets.md](widgets.md) for both.

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
- A container whose children can self-composite past its own box
  (`Grid`) bounds them with `Screen#with_clip` rather than trusting
  positioning alone — see [rendering.md](rendering.md#screen) for why
  positioning can't clip on its own.

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
