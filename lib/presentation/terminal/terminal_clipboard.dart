import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

/// Copies the selected text to the clipboard and clears the selection.
/// Returns false when nothing is selected.
Future<bool> copySelection(Terminal terminal, TerminalController selection) async {
  final range = selection.selection;
  if (range == null) return false;
  final text = terminal.buffer.getText(range);
  await Clipboard.setData(ClipboardData(text: text));
  selection.clearSelection();
  return true;
}

/// Selects the visible screen, as the keyboard select-all shortcut does.
void selectVisible(Terminal terminal, TerminalController selection) {
  selection.setSelection(
    terminal.buffer.createAnchor(0, terminal.buffer.height - terminal.viewHeight),
    terminal.buffer.createAnchor(terminal.viewWidth, terminal.buffer.height - 1),
    mode: SelectionMode.line,
  );
}
