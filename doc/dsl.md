# DSL mode

`tui.cr` ships three macro-based DSLs that generate the exact same
objects its plain declarative API already produces — `TUI::Form::FieldSpec(M)`
arrays, `TUI::ArrayTableSource(T)` instances, and `TUI::ArrayDetailSource(T)`
instances — from a terser block syntax. All three are purely additive
sugar: nothing about `FieldSpec`, `Form::Host`, `ArrayTableSource`,
`ArrayDetailSource`, `TableView`, `DetailView`, etc. changes, and every
plain constructor call documented in [ARCHITECTURE.md](ARCHITECTURE.md)
still works unmodified. Reach for the DSL when a form, table source, or
detail source is declared once, by hand, at a fixed shape (the common
case); keep hand-writing `FieldSpec.new(...)`/`ArrayTableSource.new(...)`/
`ArrayDetailSource.new(...)` directly for anything built dynamically or
shaped by something other than a literal block of `field`/`column`/`line`
calls.

Not every class in this library gets DSL sugar — only ones with real,
repeated constructor complexity that a macro genuinely simplifies. A
full audit against every widget in the catalog found that most
remaining classes are either trivial (1-2 arg constructors), internal-only
(never constructed by app code — `OptionListView`, `ClickTracker`), or
already collapsed via a plain `.full_screen`/`.centered` factory method
with no block/DSL syntax needed (`Window`, `SplitWindow`, `HSplit`,
`Popup`, `DropdownPicker`). Forcing a macro onto a single, non-repeated
call site (e.g. `example/menu_page.cr`'s one static menu widget, or
`widget_browser.cr`'s one `Runtime`/`NavStack` wiring block) would add
unused surface area for its own sake — see this library's own stated
design principle in [ARCHITECTURE.md](ARCHITECTURE.md). `Picker(W)`
specifically has zero usages anywhere in this repo and stays undemonstrated
for that reason (see the README's Example section).

All three macros exist as the first macro-based code in this library —
the sections below note the Crystal mechanics involved in enough detail
to extend the DSL safely (e.g. adding a new `field:`/`column:`/`line:`
kwarg) without retripping the same constraints.

## `TUI::Form.define` — declaring form fields

```crystal
TUI::Form.define(FORM_FIELDS, PackageEdit) do
  field :name
  field :description, rows: 4
  field :category, options: CATEGORY_OPTIONS, rows: CATEGORY_OPTIONS.size
  field :tags, options: TAG_OPTIONS, flags: true, rows: TAG_OPTIONS.size
  field :size_mb, label: "Size (MB)", validate: :float, error: "Size must be a number"
  field :installed, bool: true
  field :released, validate: :time, error: "Released must be a date"
  field :origin, dropdown: ORIGIN_OPTIONS
  field :dependents, dropdown: DEPENDENT_OPTIONS, multi: true
end
```

This expands to a plain `Array(TUI::Form::FieldSpec(PackageEdit))`
assigned to the constant `FORM_FIELDS` — pass it to `Form::Host`/
`Form::Host.full_screen` exactly as you would a hand-written array (see
`example/pages/form_page.cr` for the full, real call site this is drawn
from).

### `field` kwargs

Each `field :prop, ...` call maps 1:1 onto an existing `FieldSpec`
constructor argument or picks one of the four existing `FormField`
subclasses — the DSL invents no new runtime behavior, only a terser way
to spell the same constructor calls.

| kwarg | Meaning | Maps to |
|---|---|---|
| `:prop` (positional) | property name on the bound model | `get`/`set` procs reading/writing `m.prop`/`m.prop=` |
| `label:` | override the label shown in the form | `FieldSpec#label` (default: auto-derived Title Case, e.g. `:size_mb` → `"Size Mb"`) |
| `rows:` | how many buffer rows this field may draw into | `FieldSpec#rows` (default `1`) |
| `options:` | an `Array(FormEnumOption)` for an in-place single-select preview | `build: -> { EnumField.new(options) }` |
| `options:` + `flags: true` | an in-place multi-select preview | `build: -> { FlagsField.new(options) }` |
| `bool: true` | a yes/no toggle | `build: -> { BoolField.new }` |
| (none of the above) | plain single/multi-line text | `build: -> { TextField.new }` (the default) |
| `validate: :float \| :time \| :int \| :decimal` | reject a commit that fails `TUI::Validation.valid_xxx?` | `validator: ->TUI::Validation.valid_xxx?(String)` |
| `validate:` (a `Proc(String, Bool)` literal) | a custom validator, escape hatch | `validator:` passed through verbatim |
| `error:` | the message shown when `validate:` rejects a commit | `error_message:` (default `"Invalid value"`) |
| `dropdown:` | an `Array(FormEnumOption)` driven via a `TUI::DropdownPicker` popup instead of an in-place editor | `dropdown_options:` |
| `dropdown:` + `multi: true` | a popup multi-select, confirmed as a set | `dropdown_options:` + `dropdown_multi: true` |

`options:` and `dropdown:` are mutually exclusive on the same `field`
call — combining them is a **compile-time error** (`{% raise %}` inside
the macro), not a silent "one wins."

### Why `get`/`set` are safe even though they're generated

`FieldSpec(M)`'s `get : M -> String`/`set : (M, String) -> Nil` have no
default — a `FieldSpec` cannot exist without a real binding to the
model. The DSL preserves that guarantee: every `field :prop` call
generates a literal `->(m : M) { m.prop }` / `->(m : M, v : String) { m.prop = v; nil }`
closure inside the macro-generated `self.build` method. If `prop` isn't
a real property on the model, this is an ordinary Crystal compile error:

```
Error: undefined method 'nonexistent_property' for PackageEdit
```

**One sharp edge worth knowing if you're debugging a DSL block that
seems to compile despite a typo**: Crystal skips type-checking an
unread top-level constant's initializer entirely. If a `TUI::Form.define(FOO, M) do ... end`
block's `FOO` is never referenced anywhere else in the program, a typo
inside it can compile clean with exit code 0. This is ordinary Crystal
dead-code elision, not a DSL-specific gap — every real call site in this
codebase passes the result straight into `Form::Host`/`Form::Host.full_screen`,
which reads it, so the typo-safety guarantee holds in practice. It's
still worth remembering if you ever see a DSL-declared field's edits
silently doing nothing: check that the constant is actually consumed
somewhere.

### `TUI::ArrayTableSource.define` also composes with `Form.define`

A DSL-declared model's `property` fields are ordinary Crystal instance
variables — nothing about `TUI::Form.define` cares whether the model was
itself built with a macro. `example/pages/form_page.cr`'s `PackageEdit`
is a plain hand-written class; the DSL only needs `M`'s properties to
exist by the time `TUI::Form.define`'s generated code compiles.

## `TUI::ArrayTableSource.define` — declaring a table data source

```crystal
TUI::ArrayTableSource.define(PackageSourceBuilder, Package) do
  title "Packages"
  filter_by :name
  column :name, "Name", width: 10..20, expand: true, sort: true
  column :version, "Version", width: 8..12
  column :size_mb, "Size (MB)", width: 6..10, align: :right, sort: true
  column :installed?, "Installed", width: 6..11
end

def build_package_source : TUI::ArrayTableSource(Package)
  PackageSourceBuilder.build(FAKE_PACKAGES)
end
```

Unlike `Form.define`, this macro does **not** auto-assign a constant to
a built source. `TableView`-consuming pages in this library's own
example (Table view, Split window) each need their own independent
`ArrayTableSource` instance — sharing one would mean filtering the
package list in one page's pane silently affects another page's pane.
Since Crystal disallows declaring a `class` inside a `def` body
(`Error: can't define class inside def`), a macro that both declared the
builder class and returned a ready instance couldn't be called from
inside a per-page wrapper function. So the DSL instead:

1. Declares a **named builder class** (`PackageSourceBuilder` above) as
   a top-level statement, once.
2. Callers get a fresh `ArrayTableSource` per call via that class's own
   `.build(all)`, typically wrapped in a small function (`build_package_source`)
   so every page that needs one gets its own independent instance —
   exactly the shape `example/data.cr` uses for both `Package` and
   `Formula`.

### `title`/`filter_by`/`column` calls

| DSL call | Meaning | Maps to |
|---|---|---|
| `title "X"` | the source's title (shown, with a filter suffix, in the table's border) | `ArrayTableSource#@title` |
| `filter_by :prop` | which property backs `/`-search (stringified via `.to_s`) | `filter_text: ->(item : T) { item.prop.to_s }` |
| `column :prop, "Header", width: lo..hi` | one column, reading `item.prop` for its cell | one `TableColumn` + one cell-rendering closure |
| `expand: true` | this column grows to fill leftover width | `TableColumn#expand` |
| `align: :right \| :left` | column text alignment | `TUI::Align::Right`/`Left` (default: `Left`) |
| `sort: true` | register a `:prop`-keyed sort comparator | adds `:prop => ->(a, b) { a.prop <=> b.prop || 0 }` to `sort_keys` |

A column without `width:` defaults to `6..10`; a column without
`sort: true` simply isn't sortable (absent from `sort_keys`, exactly
like a hand-written source that never registers that key). `:installed?`
(a `getter?`-declared boolean property, trailing `?` and all) works as
an ordinary property-name symbol.

### Cell styling: a runtime, not macro-time, decision

`ArrayTableSource(T)`'s own hand-written call sites color cells via
`TypeStyle.for("float64", "")`, `TypeStyle.for("bool", "")`, etc. — a
string tag picked by whoever wrote the `row:` proc, because they know
each field's static type. The DSL doesn't have that information cheaply:
Crystal's `instance_vars` type-reflection only works inside a `def` body,
not at the macro-expansion time of a single `column` call (see
"Crystal macro mechanics" below), so introspecting `Package#size_mb`'s
declared type from inside `column`'s own macro expansion isn't a
realistic option without much larger structural changes.

Instead, each generated cell looks up its own style **at render time**,
from the actual runtime value:

```crystal
value = item.size_mb
TUI::Cell.new(value.to_s, style: TUI::TypeStyle.for(value.class.name.downcase, ""))
```

`Float64.name.downcase == "float64"`, `Bool.name.downcase == "bool"`,
etc. — matching `TypeStyle`'s own case-when keys exactly, at the cost of
one extra `Class#name` call per cell per render (negligible, no
allocation, no I/O).

### `sort:` stays a comparator, not a key-extractor

`ArrayTableSource(T)#sort_keys` is typed `Hash(Symbol, (T, T) -> Int32)`
— a two-argument comparator per key, not a `Hash(Symbol, T -> _)`
key-extractor. This is deliberate: Crystal can't type-check a comparison
between two values pulled from a `Hash` whose value type is a union
across heterogeneous field types (a `String` sort key next to a
`Float64` one, say). The DSL's `sort: true` therefore generates a
literal two-argument comparator per column —
`->(a : T, b : T) { a.prop <=> b.prop || 0 }` — never a key-extractor
Hash, so it can't regress into that type-union problem no matter how
many differently-typed sortable columns a `define` block declares.

## `TUI::ArrayDetailSource.define` — declaring a detail data source

```crystal
TUI::ArrayDetailSource.define(PACKAGE_DETAIL_SOURCE, Package, FAKE_PACKAGES) do
  id_key :name
  line :name, "Name"
  line :version, "Version"
  line :size_mb, "Size", suffix: " MB"
  line :installed?, "Installed"
  line :origin, "Origin"
  line :license, "License"
  toggle :description, "description" do
    line :description, "Description"
  end
end
```

This expands to a plain `TUI::ArrayDetailSource(Package)` **instance**
assigned directly to the constant `PACKAGE_DETAIL_SOURCE` — pass it
straight to `TUI::DetailView.new` exactly as you would a hand-written
`DetailDataSource` (see `example/data.cr`/`example/pages/table_page.cr`
for the full, real call site this is drawn from).

### Why this one follows `Form.define`'s shape, not `ArrayTableSource.define`'s

`ArrayTableSource.define` needs a **named builder class** (see above)
because Table view and Split window each need their own independent
`ArrayTableSource` instance with independent filter/sort state.
`ArrayDetailSource` has no such driver: a detail source is a read-only
lookup against one shared dataset, with no filter, sort, or swapped-in
data — a single instance genuinely covers every consumer. So
`ArrayDetailSource.define` follows `Form.define`'s simpler shape instead:
the macro auto-assigns the built **value** directly to the caller-named
constant, no builder class exposed. The data array (`FAKE_PACKAGES`
above) is passed as an ordinary third macro argument — not part of the
block — so it must already exist as a top-level constant by the time the
`.define` call executes textually.

### `id_key`/`line`/`toggle` calls

| DSL call | Meaning | Maps to |
|---|---|---|
| `id_key :prop` | which property's `.to_s` becomes the id passed to `.lines(id, ...)` | `id_key: ->(item : T) { item.prop.to_s }` |
| `line :prop, "Header"` | one always-shown label/value row | `DetailLine.new("Header", item.prop.to_s)` |
| `line :prop, "Header", suffix: " MB"` | same, with a literal string appended to the value | `DetailLine.new("Header", "#{item.prop}" + " MB")` |
| `toggle :sym, "label" do ... end` | a toggleable section; its own `line` calls only append while `:sym` is in the current expansions | registers `:sym => "label"` in `toggle_labels`, `:sym => proc` in `toggle_lines` |

`:installed?` (a `getter?`-declared boolean property, trailing `?` and
all) works as an ordinary property-name symbol here too — the same
mechanism already proven by `ArrayTableSource.define`'s `column :installed?, ...`.

A gotcha caught while building this macro, worth knowing if you add a
new kwarg that takes a literal string default: splicing a macro node's
value directly into a string interpolation
(`"...#{prop}{{ suffix_node ? suffix_node.value : "" }}"`) does **not**
work — it re-emits the raw, unquoted AST source text at that position,
producing either a parse error or a stray literal `""` in the output.
The fix is to branch with `{% if suffix_node %}`/`{% else %}` over two
entirely separate, independently-valid Crystal expressions (one with
the suffix concatenated, one without), never trying to inline a
conditional default into one interpolated string.

## Crystal macro mechanics behind all three DSLs

All three macros were built against, and are constrained by, a few
Crystal 1.19+ macro-system facts worth knowing if you extend them:

- **A macro that emits `class ... end` must be called as a bare
  top-level statement**, not from expression/value position. `FORM_FIELDS = TUI::Form.define(PackageEdit) do ... end`
  does not work (`Error: can't declare class dynamically`) — this is
  why the syntax is `TUI::Form.define(FORM_FIELDS, PackageEdit) do ... end`:
  the macro itself emits both the helper class declaration *and* the
  `FORM_FIELDS = HelperClass.build` assignment, as two sibling top-level
  statements inside its own expansion.
- **A macro-emitted `class` cannot be declared inside a `def` body**
  (`Error: can't define class inside def`) — the reason
  `ArrayTableSource.define` needs a named builder class instead of
  auto-assigning a constant the way `Form.define`/`ArrayDetailSource.define`
  do (see above) — Table view/Split window genuinely need a fresh,
  independent instance per page, which a `def`-local macro-emitted class
  can't provide.
- **`instance_vars`/type-reflection only works inside a `def` body**, not
  at the macro-expansion time of an individual DSL call. None of the
  three macros in this library actually need it (every `get`/`set`/
  `column`/`line` reference is a literal `m.{{ prop.id }}` spliced
  directly into a generated method body, type-checked by the ordinary
  compiler once that method is called) — but if you're tempted to add
  "auto-discover every property" sugar later, that discovery logic has
  to live inside a `def self.something` of the generated helper class,
  not in the macro's own top-level expansion.
- **`call.named_args` is a `Nop` macro node, not an empty array, when a
  call has zero named args.** All three macros guard for this explicitly
  (`(nargs.is_a?(ArrayLiteral) || nargs.is_a?(TupleLiteral)) ? nargs : [] of Nil`)
  before calling `.find` on it.
- **A single-statement block's `block.body` is a bare `Call`, not an
  `Expressions` node.** All three macros iterate
  `block.body.is_a?(Expressions) ? block.body.expressions : [block.body]`
  to handle a `do ... end` block containing just one `field`/`column`/`line`
  call correctly. **This applies recursively to a nested block, too** —
  `ArrayDetailSource.define`'s `toggle :sym, "label" do ... end` reads its
  own inner block the same way via `call.block.body` (a `Call` node's
  `.block` attribute), confirmed to behave identically to the macro's own
  top-level `&block` argument.
- **A `RangeLiteral`'s bounds are `.begin`/`.end`**, not `.from`/`.to` —
  used for `width: lo..hi` in `column`.
- **Splicing a conditional macro-node value directly into a string
  interpolation doesn't work** — see `ArrayDetailSource.define`'s
  `suffix:` handling above for the failure mode and the fix (branch over
  two whole separate expressions with `{% if %}`/`{% else %}`, never
  inline a conditional default into one interpolated string).

## Specs

`spec/form/define_spec.cr`, `spec/widgets/array_table_source_define_spec.cr`,
and `spec/widgets/array_detail_source_define_spec.cr` exercise all three
DSLs. None just assert "it compiles" — per the unread-constant edge case
above, a spec that never calls `.get`/`.set` (or never reloads/reads a
DSL-built `ArrayTableSource`/`ArrayDetailSource`) wouldn't actually
exercise the property-binding safety guarantee. All three spec files
explicitly call every generated field's `get`/`set` or `lines`/`toggles`,
and `define_spec.cr`/`array_detail_source_define_spec.cr` additionally
drive their DSL-built output through a real `TUI::Form::Host`/
`TUI::DetailView` (mirroring `spec/form/host_spec.cr`'s own fixtures) to
prove the DSL's output isn't just type-compatible but behaviorally
identical to a hand-written array/source.
