require "../spec_helper"

# Keys.read only applies its escape-sequence follow-up timeout to an
# IO::FileDescriptor (see Keys.read_byte_timeout) — a plain IO::Memory
# always looks like "no more bytes yet" and every escape sequence would
# bail out early as a bare Esc. Route the bytes through a real pipe so the
# reading side is a genuine file descriptor, matching how STDIN is read
# in production.
private def read_from(bytes : Bytes) : TUI::KeyEvent
  reader, writer = IO.pipe
  writer.write(bytes)
  writer.close
  TUI::Keys.read(reader)
ensure
  reader.try &.close
end

describe TUI::Keys do
  describe ".read" do
    it "parses a plain character" do
      read_from("x".to_slice).key.should eq(TUI::Key::Char)
    end

    it "parses an arrow key" do
      read_from("\e[A".to_slice).key.should eq(TUI::Key::Up)
    end

    it "parses SS3-encoded arrow/Home/End keys (application cursor key mode)" do
      read_from("\eOA".to_slice).key.should eq(TUI::Key::Up)
      read_from("\eOB".to_slice).key.should eq(TUI::Key::Down)
      read_from("\eOC".to_slice).key.should eq(TUI::Key::Right)
      read_from("\eOD".to_slice).key.should eq(TUI::Key::Left)
      read_from("\eOH".to_slice).key.should eq(TUI::Key::Home)
      read_from("\eOF".to_slice).key.should eq(TUI::Key::End)
    end

    it "does not leak the SS3 letter into the next read as a stray Char" do
      reader, writer = IO.pipe
      writer.write("\eOBx".to_slice)
      writer.close

      first = TUI::Keys.read(reader)
      second = TUI::Keys.read(reader)

      first.key.should eq(TUI::Key::Down)
      second.key.should eq(TUI::Key::Char)
      second.char.should eq('x')
    ensure
      reader.try &.close
    end

    it "parses repeated back-to-back single-letter CSI keys without desyncing" do
      # Regression: read_csi_seq used to keep consuming bytes looking for
      # a terminator even after `first` (e.g. "B") was already a complete
      # single-letter sequence on its own, swallowing the next
      # keypress(es) in the process — only every ~3rd repeated arrow-key
      # press would parse correctly, the rest turned into stray Char
      # events for whatever letter got eaten.
      reader, writer = IO.pipe
      writer.write("\e[B\e[B\e[B\e[B\e[B".to_slice)
      writer.close

      keys = 5.times.map { TUI::Keys.read(reader) }.map(&.key).to_a
      keys.should eq([TUI::Key::Down] * 5)
    ensure
      reader.try &.close
    end

    it "parses a mix of single-letter and multi-char CSI keys back-to-back without desyncing" do
      reader, writer = IO.pipe
      writer.write("\e[B\e[5~\e[B\e[1;3D\e[B".to_slice)
      writer.close

      keys = 5.times.map { TUI::Keys.read(reader) }.map(&.key).to_a
      keys.should eq([TUI::Key::Down, TUI::Key::PageUp, TUI::Key::Down, TUI::Key::WordLeft, TUI::Key::Down])
    ensure
      reader.try &.close
    end

    it "parses SGR mouse wheel-up (button code 64)" do
      read_from("\e[<64;12;5M".to_slice).key.should eq(TUI::Key::MouseWheelUp)
    end

    it "parses SGR mouse wheel-down (button code 65)" do
      read_from("\e[<65;12;5M".to_slice).key.should eq(TUI::Key::MouseWheelDown)
    end

    it "parses SGR mouse release events without hanging" do
      read_from("\e[<65;1;1m".to_slice).key.should eq(TUI::Key::MouseWheelDown)
    end

    it "parses SGR mouse left-click press with position" do
      ev = read_from("\e[<0;12;5M".to_slice)
      ev.key.should eq(TUI::Key::MouseClick)
      ev.col.should eq(12)
      ev.row.should eq(5)
    end

    it "ignores SGR mouse left-click release" do
      read_from("\e[<0;12;5m".to_slice).key.should eq(TUI::Key::Unknown)
    end

    it "ignores non-left SGR mouse buttons" do
      read_from("\e[<1;1;1M".to_slice).key.should eq(TUI::Key::Unknown)
    end

    it "parses Ctrl-A" do
      read_from("".to_slice).key.should eq(TUI::Key::CtrlA)
    end

    it "parses Ctrl-E" do
      read_from("".to_slice).key.should eq(TUI::Key::CtrlE)
    end

    it "parses Ctrl-Right and Alt-Right as word-right" do
      read_from("\e[1;5C".to_slice).key.should eq(TUI::Key::WordRight)
      read_from("\e[1;3C".to_slice).key.should eq(TUI::Key::WordRight)
    end

    it "parses Ctrl-Left and Alt-Left as word-left" do
      read_from("\e[1;5D".to_slice).key.should eq(TUI::Key::WordLeft)
      read_from("\e[1;3D".to_slice).key.should eq(TUI::Key::WordLeft)
    end

    it "parses Alt-Backspace (bare ESC + DEL) as word-backspace" do
      read_from("\e".to_slice).key.should eq(TUI::Key::WordBackspace)
    end

    it "parses Alt-Delete (CSI 3;3~) as word-delete" do
      read_from("\e[3;3~".to_slice).key.should eq(TUI::Key::WordDelete)
    end

    it "parses a bracketed-paste block into one Paste event carrying the content" do
      ev = read_from("\e[200~hello\nworld\e[201~".to_slice)
      ev.key.should eq(TUI::Key::Paste)
      ev.text.should eq("hello\nworld")
    end

    it "does not interpret escape-like bytes inside pasted content" do
      ev = read_from("\e[200~a\eb\e[Xc\e[201~".to_slice)
      ev.key.should eq(TUI::Key::Paste)
      ev.text.should eq("a\eb\e[Xc")
    end

    it "leaves the stream positioned right after the paste terminator" do
      reader, writer = IO.pipe
      writer.write("\e[200~abc\e[201~x".to_slice)
      writer.close

      first = TUI::Keys.read(reader)
      second = TUI::Keys.read(reader)

      first.key.should eq(TUI::Key::Paste)
      first.text.should eq("abc")
      second.key.should eq(TUI::Key::Char)
      second.char.should eq('x')
    ensure
      reader.try &.close
    end
  end
end
