/// The overall status of a query or mutation.
enum QueryStatus {
  /// No fetch has started yet.
  idle,

  /// The initial fetch is in progress (no data available).
  loading,

  /// Data was fetched successfully.
  success,

  /// The fetch failed with an error.
  error,
}

/// The background fetch status of a query.
///
/// Orthogonal to [QueryStatus] — a query can be in [QueryStatus.success]
/// while simultaneously [FetchStatus.refetching] in the background.
enum FetchStatus {
  /// No background fetch is running.
  idle,

  /// A fetch is in progress (generic — used internally).
  fetching,

  /// A background refetch is running while existing data is still displayed.
  refetching,

  /// The query wants to fetch but is waiting for network connectivity.
  ///
  /// Only emitted when [NetworkMode.online] is set and the device is offline.
  /// Cached data (if any) remains visible alongside this status.
  paused,
}
