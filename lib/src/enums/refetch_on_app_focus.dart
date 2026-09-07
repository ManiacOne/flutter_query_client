/// Controls whether a query refetches when the app returns to the foreground
/// (the mobile analogue of TanStack Query's `refetchOnWindowFocus`).
///
/// Backgrounding suspends `Timer.periodic`, so data can go stale while the app
/// is away; on resume this decides whether to catch up.
enum RefetchOnAppFocus {
  /// Always refetch on app resume.
  always,

  /// Refetch on resume only if the data is stale (default).
  ifStale,

  /// Never auto-refetch on resume.
  never,
}
