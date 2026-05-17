/// Controls whether a query requires network connectivity to execute.
enum NetworkMode {
  /// Only fetch when online. Pauses if offline and resumes on reconnect.
  /// Use for API calls and network-dependent queries.
  online,

  /// Always fetch regardless of network status.
  /// Use for local database reads, file I/O, or other non-network queries.
  always,

  /// Execute queryFn once regardless of connectivity (e.g. from local cache),
  /// then require network for subsequent refetches.
  offlineFirst,
}
