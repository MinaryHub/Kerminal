import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/presentation/terminal/terminal_palettes.dart';

void main() {
  test('ids are unique and stable-looking', () {
    final ids = TerminalPalette.all.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate palette id');
    // Ids are persisted in settings; an empty or whitespace id would round-trip
    // badly and silently fall back.
    for (final id in ids) {
      expect(id.trim(), isNotEmpty);
      expect(id, id.trim());
    }
  });

  test('byId falls back instead of throwing on unknown or null', () {
    // A value written by a newer build, or a corrupt pref, must not break the
    // terminal — it just uses the default scheme.
    expect(TerminalPalette.byId(null).id, TerminalPalette.fallback.id);
    expect(TerminalPalette.byId('does-not-exist').id,
        TerminalPalette.fallback.id);
    expect(TerminalPalette.byId('').id, TerminalPalette.fallback.id);
  });

  test('byId returns each declared palette', () {
    for (final p in TerminalPalette.all) {
      expect(TerminalPalette.byId(p.id).name, p.name);
    }
  });

  test('the default id resolves to the pre-existing scheme', () {
    // Existing users must see no change until they pick something else.
    expect(TerminalPalette.fallback.id, 'default');
    expect(TerminalPalette.byId('default').theme.background,
        TerminalPalette.fallback.theme.background);
  });

  test('every palette is legible: foreground differs from background', () {
    for (final p in TerminalPalette.all) {
      expect(
        p.theme.foreground,
        isNot(p.theme.background),
        reason: '${p.name} would render invisible text',
      );
      expect(
        p.theme.cursor,
        isNot(p.theme.background),
        reason: '${p.name} would hide the cursor',
      );
    }
  });

  test('search hit colours contrast with their own background', () {
    for (final p in TerminalPalette.all) {
      expect(
        p.theme.searchHitForeground,
        isNot(p.theme.searchHitBackground),
        reason: '${p.name} search hits would be unreadable',
      );
    }
  });

  test('the view theme keeps typed text visible under the cursor', () {
    for (final p in TerminalPalette.all) {
      final view = p.viewTheme;
      expect(view.cursor.a, closeTo(TerminalPalette.cursorOpacity, 0.01),
          reason: p.id);
      // Only the cursor changes.
      expect(view.foreground, p.theme.foreground, reason: p.id);
      expect(view.background, p.theme.background, reason: p.id);
      expect(view.brightWhite, p.theme.brightWhite, reason: p.id);
      expect(view.searchHitForeground, p.theme.searchHitForeground,
          reason: p.id);
      expect(identical(view, p.viewTheme), isTrue,
          reason: 'cached, so the terminal is not repainted for nothing');
    }
  });
}
