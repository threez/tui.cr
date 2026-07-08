# Rendering and input

See [architecture.md](architecture.md) for how this fits into the
overall layering.

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
  built from `Term`'s glyph constants. `scrollbar`'s `inset:` parameter
  (default `1`) reserves that many rows off each end of its track before
  drawing — the default assumes a bordered box's own top/bottom border
  rows straddle the track; pass `inset: 0` for a borderless caller with
  no border rows to skip (e.g. `Grid`'s or `ScrollableField`'s own
  scrollbar — see [widgets.md](widgets.md)).

## Screen

**`Screen`** (`src/tui/core/screen.cr`) owns a front/back `Buffer` pair
sized to the terminal (`Term.size`).

- `blit(x, y, buffer)` composites a widget's local buffer onto the back
  buffer at absolute 1-based coordinates `(x, y)`.
- `at(row, col, s)` / `status_bar(row, text)` write directly onto the
  back buffer for app-level chrome (status bar, dividers) that no
  widget owns.
- `with_clip(rect, &block)` bounds every `blit` call inside `block` to
  `rect` (a `ClipRect`, same 1-based coordinate convention as
  `Widget#x`/`#y`), intersected with any clip already active so nesting
  can only narrow, never widen. This exists because `Widget#composite`
  always reaches the real screen through exactly one call — `blit` — no
  matter how deep the widget tree gets, so clipping there is sufficient
  for any container. `Grid` (see [widgets.md](widgets.md)) is the one
  consumer today: its children are independent `Widget`s that blit
  themselves directly via absolute `x`/`y`, unlike a `Scrollable`, which
  renders into a scratch buffer its host already sized to the visible
  area (clipping "for free," nothing to address outside the buffer).
  `Grid` has no such shared scratch buffer for N independently
  self-compositing children, so `with_clip` is what stops a child
  positioned outside `Grid`'s own box (e.g. scrolled out of view) from
  bleeding its cells onto whatever else is on screen, rather than being
  cleanly clipped to the container's rectangle. The clip is always
  restored after `block` returns, even if it raises.
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

## Widget

**`Widget`** (`src/tui/widget/widget.cr`) is the abstract base for every
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
cursor (e.g. `InputField#cursor_offset`) and for translating an
absolute mouse event down into a widget's local space, respectively.
`local`'s result may fall outside the widget's bounds; callers must
bounds-check.

The terminal's own cursor is kept hidden across frames by design —
selection/focus is conveyed by drawing reverse-video or block-glyph
styling into buffers, not by moving the real cursor. The one documented
exception is text editing (`InputField`, and `TextEdit`/`ScrollableField`
for multi-line content), which needs to show and position the real
cursor between flushes via `Widget#absolute`.

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
  unconsumed" idiom in [app-shell.md](app-shell.md).
