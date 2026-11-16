import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

/// When each saved host was last connected (host id → epoch ms), kept on this
/// device only. Drives the "Recent" section at the top of the host list: most
/// people connect to the same few servers every day, and finding them in an
/// alphabetical list each time is the slowest part of connecting.
class RecentHostsController extends Notifier<Map<String, int>> {
  static const _kRecent = 'hosts.recent';

  /// More than the list shows, so deleting a host still leaves a full list.
  static const _keep = 20;

  @override
  Map<String, int> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_kRecent);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries)
          if (e.value is int) e.key: e.value as int,
      };
    } catch (_) {
      // Corrupt value: start over rather than fail the host list.
      return const {};
    }
  }

  Future<void> markUsed(String hostId, {DateTime? at}) async {
    final next = {...state, hostId: (at ?? DateTime.now()).millisecondsSinceEpoch};
    if (next.length > _keep) {
      final oldestFirst = next.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final e in oldestFirst.take(next.length - _keep)) {
        next.remove(e.key);
      }
    }
    state = next;
    await _save();
  }

  Future<void> forget(String hostId) async {
    if (!state.containsKey(hostId)) return;
    state = {...state}..remove(hostId);
    await _save();
  }

  Future<void> _save() => ref
      .read(sharedPreferencesProvider)
      .setString(_kRecent, jsonEncode(state));
}

final recentHostsProvider =
    NotifierProvider<RecentHostsController, Map<String, int>>(
  RecentHostsController.new,
);

/// The [limit] most recently connected ids among [existingIds], newest first.
List<String> recentIds(
  Map<String, int> recent,
  Iterable<String> existingIds, {
  int limit = 5,
}) {
  final existing = existingIds.toSet();
  final entries = recent.entries.where((e) => existing.contains(e.key)).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in entries.take(limit)) e.key];
}
