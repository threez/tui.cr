# tui.cr

Minimal Crystal TUI primitives: a diffing screen compositor, a handful of
composable widgets (lists, tables, detail views, scrollable panes, splits,
modals), and an app-shell (`Runtime`) that owns terminal lifecycle and the
render/read-key/dispatch loop.

See [doc/ARCHITECTURE.md](doc/ARCHITECTURE.md) for the full layering,
render/input pipelines, and widget catalog, and [doc/dsl.md](doc/dsl.md)
for the macro-based DSL layer.

## Installation

```yaml
dependencies:
  tui:
    path: threez/tui.cr
```

## Hello, world

Every app builds its own `Widget` subclass, wraps it in a `NavStack`, and
hands both to `Runtime`, which owns the terminal lifecycle and the
render/read-key/dispatch loop:

```crystal
require "tui"

class Hello < TUI::Widget
  def render : Nil
    @buffer.set(0, 0, "Hello, World! (press q to quit)")
  end

  def handle_key(ev : TUI::KeyEvent) : Bool
    false # unconsumed
  end

  def status_hint : String
    "q:quit"
  end
end

screen = TUI::Screen.new
nav = TUI::NavStack(TUI::Widget).new(Hello.new(1, 1, screen.cols, screen.rows).as(TUI::Widget))
runtime = TUI::Runtime.new(screen, nav, ->(ev : TUI::KeyEvent) {
  exit if ev.key == TUI::Key::Char && ev.char == 'q'
})
runtime.run
```

Run it in a real terminal — `Runtime` takes over the whole screen (alt
screen, raw mode, mouse reporting) until the process exits.

## Example app

`example/` contains a larger "widget browser" exercising most of the
library's widgets end to end against fabricated in-memory data. Run it with:

```sh
make example
# or: crystal run example/widget_browser.cr
```

## Testing

```sh
crystal spec
crystal build --no-codegen src/tui.cr # fast compile-only check
```
