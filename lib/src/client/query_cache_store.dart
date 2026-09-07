import 'package:flutter_query_client/src/models/cached_query_data.dart';

/// Owns the two-level in-memory cache: `baseKey → { serializedParams → data }`.
///
/// Pure storage — no timers, notifications, or GC. Those responsibilities live
/// in their own collaborators; this class only reads and writes entries (SRP).
class QueryCacheStore {
  final Map<String, Map<String?, CachedQueryData>> _cache = {};

  CachedQueryData<T>? get<T>(String baseKey, [String? params]) {
    return _cache[baseKey]?[params] as CachedQueryData<T>?;
  }

  /// Raw (untyped) read — used for metadata lookups like `gcTime`.
  CachedQueryData? raw(String baseKey, String? params) => _cache[baseKey]?[params];

  void put<T>(String baseKey, String? params, CachedQueryData<T> value) {
    _cache.putIfAbsent(baseKey, () => {})[params] = value;
  }

  /// Remove a single entry; drops the base map when it becomes empty.
  void remove(String baseKey, String? params) {
    final paramMap = _cache[baseKey];
    if (paramMap == null) return;
    paramMap.remove(params);
    if (paramMap.isEmpty) _cache.remove(baseKey);
  }

  /// Remove and return every entry under [baseKey] (null if there were none).
  Map<String?, CachedQueryData>? removeBase(String baseKey) =>
      _cache.remove(baseKey);

  /// The param sub-keys currently cached under [baseKey].
  List<String?> paramKeys(String baseKey) =>
      _cache[baseKey]?.keys.toList() ?? const [];

  Map<String?, CachedQueryData>? baseMap(String baseKey) => _cache[baseKey];

  void clear() => _cache.clear();

  int get entryCount => _cache.values.fold(0, (sum, map) => sum + map.length);
}
