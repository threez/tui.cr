require "./list_view"

module TUI
  class ListView
    # Declares how many rows this ListView subclass reserves above its
    # data rows (e.g. a table's column header), as a bare class-body
    # statement: `scroll header: 1`. Expands to the #content_row_offset
    # override — the single source of truth #render_content and
    # Scrollable#header_rows (queried by Window to keep scroll/cursor
    # math from running past what's actually drawable) both read from.
    macro scroll(header)
      protected def content_row_offset : Int32
        {{ header }}
      end
    end
  end
end
