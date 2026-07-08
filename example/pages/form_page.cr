require "../../src/tui"
require "../data"

# Mutable scratch state for the "Edit package" demo. Package itself is a
# read-only YAML::Serializable (getters only), and Category/Tags/Released
# have no real backing fields on Package at all — they were always pure
# form-editing state. PackageEdit gives them a deliberate, real home
# (seeded once from a Package at page-open time) instead of leaving them
# as hardcoded literals disconnected from whichever package was opened.
class PackageEdit
  property name : String
  property description : String
  property category : String
  property tags : String
  property size_mb : String
  property installed : String
  property released : String
  property origin : String
  property dependents : String

  def self.from(package : Package) : PackageEdit
    new(
      name: package.name,
      description: package.description,
      category: "utility",
      tags: "0",
      size_mb: package.size_mb.to_s,
      installed: package.installed?.to_s,
      released: "2024-01-01",
      origin: package.origin,
      dependents: ""
    )
  end

  def initialize(@name, @description, @category, @tags, @size_mb, @installed, @released, @origin, @dependents)
  end
end

CATEGORY_OPTIONS = [
  TUI::FormEnumOption.new("Utility", "utility"),
  TUI::FormEnumOption.new("Library", "library"),
  TUI::FormEnumOption.new("Database", "database"),
  TUI::FormEnumOption.new("Editor", "editor"),
]

TAG_OPTIONS = [
  TUI::FormEnumOption.new("cli", "cli"),
  TUI::FormEnumOption.new("gui", "gui"),
  TUI::FormEnumOption.new("server", "server"),
  TUI::FormEnumOption.new("deprecated", "deprecated"),
]

# Real FreeBSD pkg origins (category/portname, as reported by
# `pkg query %o`) — loaded from packages.yaml alongside the fake
# package list, so both stay in one place to edit.
ORIGIN_OPTIONS = PKG_ORIGIN_OPTIONS.map { |origin| TUI::FormEnumOption.new(origin, origin) }

DEPENDENT_OPTIONS = FAKE_PACKAGES.map { |pkg| TUI::FormEnumOption.new(pkg.name, pkg.name) }

TUI::Form.define(FORM_FIELDS, PackageEdit) do
  field :name
  field :description, rows: 4, edit: true
  field :category, options: CATEGORY_OPTIONS, rows: CATEGORY_OPTIONS.size
  field :tags, options: TAG_OPTIONS, flags: true, rows: TAG_OPTIONS.size
  field :size_mb, label: "Size (MB)", validate: :float, error: "Size must be a number"
  field :installed, bool: true
  field :released, validate: :time, error: "Released must be a date"
  field :origin, dropdown: ORIGIN_OPTIONS
  field :dependents, dropdown: DEPENDENT_OPTIONS, multi: true
end

def build_form_page(screen : TUI::Screen, nav : TUI::NavStack(TUI::Widget)) : TUI::Widget
  popup = TUI::Form::Host.popup_host(screen, nav)
  host = TUI::Form::Host.full_screen(screen, FORM_FIELDS, PackageEdit.from(FAKE_PACKAGES.first), popup, "Edit package")
  host.border_style = TUI::Style.new(fg: TUI.color(:yellow))
  host
end
