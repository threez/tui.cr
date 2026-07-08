require "../src/tui"
require "./data"
require "./help"
require "./pages/menu_page"
require "./pages/table_page"
require "./pages/split_page"
require "./pages/hsplit_page"
require "./pages/form_page"
require "./pages/markdown_page"
require "./pages/text_edit_page"

screen = TUI::Screen.new

runtime = uninitialized TUI::Runtime
nav = uninitialized TUI::NavStack(TUI::Widget)

menu = build_menu_page(screen, ->(index : Int32) {
  page = case index
         when 0 then build_table_page(screen, runtime)
         when 1 then build_split_page(screen)
         when 2 then build_hsplit_page(screen)
         when 3 then build_form_page(screen, nav)
         when 4 then build_markdown_page(screen)
         else        build_text_edit_page(screen)
         end
  runtime.push(page)
  nil
})
nav = TUI::NavStack(TUI::Widget).new(menu)

runtime = TUI::Runtime.new(screen, nav, ->(ev : TUI::KeyEvent) {
  if nav.current.is_a?(TUI::Popup)
    nav.pop
  else
    consumed = nav.current.handle_key(ev)
    unless consumed
      case ev.key
      when TUI::Key::Esc
        runtime.handle_esc(consumed) { }
      when TUI::Key::Char
        if ev.char == '?'
          help = TUI::Popup.centered(screen, "Help", HELP_TEXT)
          help.border_style = TUI::Style.new(fg: TUI.color(:red))
          nav.push(help.as(TUI::Widget))
        elsif ev.char == 'q'
          exit
        end
      end
    end
  end
  nil
})

runtime.run
