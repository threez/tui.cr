require "../../src/tui"

# Sample doc exercising every in-scope Markdown construct (numbered
# headings, nested ordered/unordered/task lists, a GFM table with all
# three alignment hints, a blockquote, an hrule, a fenced code block,
# and emphasis/inline-code/links) — used both as the demo page's content
# and, verbatim, as the manual-smoke-test target in the implementation
# plan.
MARKDOWN_SAMPLE = <<-MD
# Guide

Welcome to **tui.cr**. This is a *sample* document with `inline code`
and a [link](https://example.com) to prove word-wrap handles long
paragraphs correctly by breaking only at whitespace boundaries.

## Installation

1. Clone the repo
2. Run `shards install`
   - Verify Crystal >= 1.19.1
   - Check shard.yml
3. Build

## Features

- Headings are numbered
- Lists nest with proper indentation
- Tables align columns
- [x] Word-wrap preserves inline styling
- [ ] Syntax highlighting (not yet)

### Example table

| Name   | Type  | Price |
|:-------|:-----:|------:|
| Widget | tool  | $9.99 |
| Gadget | gizmo | $19.99 |

> Blockquotes render indented with a bar.

---

```crystal
puts "code block, not word-wrapped"
```
MD

# Builds the "Markdown viewer" demo page: a MarkdownView over
# MARKDOWN_SAMPLE, hosted in a bordered Window for the scrollbar/title
# chrome every other page already gets for free.
def build_markdown_page(screen : TUI::Screen) : TUI::Widget
  view = TUI::MarkdownView.new(MARKDOWN_SAMPLE)
  TUI::Window.full_screen(screen, view)
end
