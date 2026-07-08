# App shell

See [architecture.md](architecture.md) for how this fits into the
overall layering.

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
  the render → read-key → dispatch loop (see
  [rendering.md](rendering.md) for the input side of that loop). It
  wraps a `NavStack(Widget)` and layers auto-resize on top of its
  push/pop/replace_base:
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
    current widget's size, and re-renders. Any widget on top of the
    stack that itself hosts nested layout (e.g. a `Form::Host` and its
    internal `Grid` — see [widgets.md](widgets.md)) is responsible for
    propagating that resize down to its own children on the next
    `#composite`, the same way `Form::Host#composite` re-derives its
    `Grid`'s geometry every frame rather than trusting values fixed at
    construction time.
  - `render_now` forces a synchronous render+flush outside the normal
    loop, for a long blocking operation that emits progress via
    callbacks and needs the screen repainted between the loop's normal
    render points.
