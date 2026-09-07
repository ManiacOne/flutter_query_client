import 'package:flutter_query_client/src/helpers.dart' show serializeParams;

export 'package:flutter_query_client/src/helpers.dart' show serializeParams;

/// Flattens a `(baseKey, serializedParams)` pair into the single string used as
/// the key for every per-query registry (stale timers, GC timers, cache-change
/// and reconnect subscriptions, observer counts).
///
/// This is the one place that owns the flat-key format, so the format lives in
/// exactly one location (SRP).
String serializeKey(String baseKey, String? params) {
  if (params == null || params.isEmpty) return baseKey;
  return '$baseKey:$params';
}

/// Convenience: serialize typed [params] and flatten with [baseKey] in one step.
String serializeKeyWithParams(String baseKey, Object? params) =>
    serializeKey(baseKey, serializeParams(params));
