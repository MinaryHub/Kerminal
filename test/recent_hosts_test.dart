import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/application/recent_hosts.dart';
import 'package:kerminal/application/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ]);
}

void main() {
  test('most recently connected first, deleted hosts left out', () {
    final ids = recentIds(
      {'a': 1, 'b': 3, 'c': 2, 'gone': 9},
      ['a', 'b', 'c'],
    );
    expect(ids, ['b', 'c', 'a']);
  });

  test('limit caps the list', () {
    expect(recentIds({'a': 1, 'b': 2, 'c': 3}, ['a', 'b', 'c'], limit: 2),
        ['c', 'b']);
  });

  test('markUsed persists and survives a restart', () async {
    final c = await _container();
    addTearDown(c.dispose);
    await c
        .read(recentHostsProvider.notifier)
        .markUsed('h1', at: DateTime.fromMillisecondsSinceEpoch(1000));
    expect(c.read(recentHostsProvider), {'h1': 1000});

    final prefs = c.read(sharedPreferencesProvider);
    final again = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(again.dispose);
    expect(again.read(recentHostsProvider), {'h1': 1000});
  });

  test('a corrupt stored value starts empty instead of failing', () async {
    final c = await _container({'hosts.recent': 'not json'});
    addTearDown(c.dispose);
    expect(c.read(recentHostsProvider), isEmpty);
  });

  test('keeps at most 20 entries, dropping the oldest', () async {
    final c = await _container();
    addTearDown(c.dispose);
    final notifier = c.read(recentHostsProvider.notifier);
    for (var i = 0; i < 25; i++) {
      await notifier.markUsed('h$i', at: DateTime.fromMillisecondsSinceEpoch(i));
    }
    final state = c.read(recentHostsProvider);
    expect(state.length, 20);
    expect(state.containsKey('h0'), isFalse);
    expect(state.containsKey('h24'), isTrue);
  });
}
