require "yaml"
require "../src/tui"

# Fabricated data for the widget browser, loaded from packages.yaml at
# startup rather than hardcoded as Crystal literals — 300+ packages
# (enough to actually show TableView's filter/sort/scroll at scale) is
# unwieldy as source code, and a plain data file is easier to edit/add
# to without touching any Crystal at all.

class Package
  include YAML::Serializable

  getter name : String
  getter version : String
  getter size_mb : Float64
  getter? installed : Bool
  getter origin : String
  getter license : String
  getter maintainer : String
  getter description : String
end

class Formula
  include YAML::Serializable

  getter name : String
  getter dependents : Int32
end

private class PackageData
  include YAML::Serializable

  getter packages : Array(Package)
  getter formulas : Array(Formula)
  getter pkg_origin_options : Array(String)
end

private DATA = PackageData.from_yaml(File.read(File.join(__DIR__, "packages.yaml")))

FAKE_PACKAGES      = DATA.packages
FAKE_FORMULAS      = DATA.formulas
PKG_ORIGIN_OPTIONS = DATA.pkg_origin_options

# Builds the "Table view" page's TableDataSource: real in-memory
# filter/sort, so `/` and `s` actually do something interactively.
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

# DetailDataSource backing the drill-down from a package row — one
# toggleable section ("description") to demonstrate expand/soft-wrap.
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

# A second, differently-shaped TableDataSource so the two-pane demo pages
# (SplitWindow/HSplit) show distinct datasets side by side.
TUI::ArrayTableSource.define(FormulaSourceBuilder, Formula) do
  title "Formulas"
  filter_by :name
  column :name, "Formula", width: 10..20, expand: true, sort: true
  column :dependents, "Dependents", width: 6..12, align: :right, sort: true
end

def build_formula_source : TUI::ArrayTableSource(Formula)
  FormulaSourceBuilder.build(FAKE_FORMULAS)
end
