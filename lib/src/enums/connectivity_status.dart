/// Device internet connectivity status, reported by this package's native
/// Android/iOS connectivity signal.
///
/// An enum (rather than a `bool`) so future states — e.g. a captive-portal
/// or "checking" status — can be added without breaking the
/// [QueryClientProvider.onConnectivityChanged] callback signature.
enum ConnectivityStatus {
  online,
  offline;

  bool get isOnline => this == ConnectivityStatus.online;
}
