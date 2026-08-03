/// A host/port the native reachability probe attempts a TCP connection to.
///
/// Defaults to port `443` (HTTPS), which is allowed outbound on virtually
/// every network — corporate firewalls, captive portals, and censored
/// regions almost always permit `443`, whereas DNS port `53` is frequently
/// blocked or hijacked.
///
/// For the most accurate result, point this at **your own backend** (the host
/// your app actually needs to reach). A reachable backend means "online" for
/// your app's purposes and sidesteps region-specific blocking of third-party
/// anchors (e.g. Google DNS being unreachable in mainland China). Configure it
/// via [QueryDefaults.connectivityProbeTargets].
class ProbeTarget {
  final String host;
  final int port;

  const ProbeTarget(this.host, [this.port = 443]);

  Map<String, dynamic> toMap() => {'host': host, 'port': port};

  @override
  String toString() => '$host:$port';
}
