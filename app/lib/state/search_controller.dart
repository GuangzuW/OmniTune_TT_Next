import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/data/models/track.dart';
import 'package:app/state/providers.dart';

/// Holds the latest Audius search results as an AsyncValue.
class SearchController extends Notifier<AsyncValue<List<Track>>> {
  @override
  AsyncValue<List<Track>> build() => const AsyncValue.data([]);

  String _lastQuery = '';
  String get lastQuery => _lastQuery;

  Future<void> search(String query) async {
    _lastQuery = query.trim();
    if (_lastQuery.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final api = ref.read(apiClientProvider);
      final results = await api.searchTracks(_lastQuery);
      state = AsyncValue.data(results.map(Track.fromAudius).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clear() {
    _lastQuery = '';
    state = const AsyncValue.data([]);
  }
}

final searchControllerProvider =
    NotifierProvider<SearchController, AsyncValue<List<Track>>>(SearchController.new);
