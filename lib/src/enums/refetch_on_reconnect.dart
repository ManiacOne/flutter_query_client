/// Controls whether active queries refetch when network connectivity is restored.
enum RefetchOnReconnect {
  /// Always refetch all active queries when connection is restored.
  always,

  /// Only refetch queries whose data is stale.
  ifStale,

  /// Never auto-refetch on reconnect.
  never,
}
