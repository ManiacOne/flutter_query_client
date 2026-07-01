import 'package:flutter/widgets.dart';
import 'package:flutter_query_client/src/client/query_client.dart';

/// Manages stale-listener registration/unregistration for a cache key.
///
/// Encapsulates the pattern of subscribing to stale notifications from
/// [QueryClient] and cleaning up on disposal.
class StaleListenerHandle {
  final QueryClient _client;
  final String _cacheKey;

  String? _listenedParams;
  VoidCallback? _staleCallback;

  StaleListenerHandle({
    required QueryClient client,
    required String cacheKey,
  })  : _client = client,
        _cacheKey = cacheKey;

  /// Register a stale listener for the given [params].
  /// Automatically unregisters any previous listener.
  bool get isRegistered => _staleCallback != null;
  String? get registeredParams => _listenedParams;

  void register(String? params, VoidCallback onStale) {
    if (_staleCallback != null && _listenedParams == params) return;
    unregister();
    _staleCallback = onStale;
    _listenedParams = params;
    _client.addStaleListener(_cacheKey, params, _staleCallback!);
  }

  /// Unregister the currently active stale listener, if any.
  void unregister() {
    if (_staleCallback != null) {
      _client.removeStaleListener(_cacheKey, _listenedParams, _staleCallback!);
      _staleCallback = null;
      _listenedParams = null;
    }
  }
}
