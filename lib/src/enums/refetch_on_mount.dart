/// Controls whether a query refetches when its widget mounts with cached data.
enum RefetchOnMount {
  /// Always refetch when mounting with cached data.
  always,

  /// Only refetch if cached data is stale (based on `staleTime`).
  stale,

  /// Never refetch on mount — show cached data as-is.
  never,
}
