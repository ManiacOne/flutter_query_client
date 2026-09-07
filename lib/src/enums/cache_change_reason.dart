/// Why a cache entry changed, delivered to active controllers so they can
/// re-derive their state from the cache (the single source of truth for data).
enum CacheChangeReason {
  /// Data was written or replaced for this key (`set`, `update`,
  /// `updateInfiniteQuery`, or another controller's successful fetch).
  updated,

  /// The entry was invalidated (`invalidate`, `invalidateAll`,
  /// `invalidateQueries`). Active controllers refetch.
  invalidated,

  /// The whole cache was wiped via `clear()`. Active controllers drop their
  /// data to empty/idle without refetching (e.g. logout/reset).
  cleared,

  /// The entry was garbage-collected after its `gcTime` elapsed with no
  /// active observers. Treated like an empty cache.
  evicted,

  /// Only the fetch lifecycle (status/fetchStatus/error) changed for this key —
  /// data is unchanged. Fired by the fetch engine so observers reflect
  /// loading/refetching/error transitions (e.g. per-param loading).
  statusChanged,
}
