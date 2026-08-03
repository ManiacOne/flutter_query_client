import Flutter
import Network
import UIKit

private let methodChannelName = "flutter_query_client/connectivity"
private let eventChannelName = "flutter_query_client/connectivity/events"

/// Reports device internet connectivity to the Dart side.
///
/// Exposes two channels:
///
/// - A **method channel** with a single `isConnected` call. It first checks the
///   OS route (`NWPathMonitor`); if a route is satisfied it opens a short-lived
///   TCP connection to a reliable host to confirm *real* internet. iOS has no
///   equivalent of Android's `NET_CAPABILITY_VALIDATED` — `.satisfied` only
///   means a route exists, not that the internet is reachable — so the active
///   probe is what actually distinguishes "connected but no internet" (dead
///   router, captive portal, Simulator whose host is offline) from online.
///
/// - An **event channel** that emits a lightweight hint whenever the OS network
///   path changes (via a long-lived `NWPathMonitor`). The Dart side re-probes
///   on each hint, so detection is instant and event-driven while the probe
///   remains the single source of truth. Because the hint only *triggers* a
///   fresh probe and never carries authoritative state, the stale/reversed
///   `NWPathMonitor` values that plagued earlier event-driven designs can no
///   longer set a wrong value.
public class FlutterQueryClientPlugin: NSObject, FlutterPlugin {
  private let hintStreamHandler = NetworkHintStreamHandler()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FlutterQueryClientPlugin()

    let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance.hintStreamHandler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isConnected":
      let targets = ConnectivityChecker.parseTargets(call.arguments)
      ConnectivityChecker.checkOnce(targets: targets) { isConnected in
        result(isConnected)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Performs a single authoritative connectivity read: a fast OS route check,
/// then — only if a route exists — a short-lived TCP probe to a reliable host
/// to confirm real internet reachability.
private enum ConnectivityChecker {
  typealias Target = (host: String, port: UInt16)

  /// Default TCP probe targets, used when the Dart side supplies none. Port
  /// 443 (HTTPS) is allowed outbound on virtually every network — far more
  /// universally reachable than DNS port 53 — and connecting to a public IP
  /// does not trigger iOS's local-network permission prompt. The first that
  /// connects wins.
  private static let defaultTargets: [Target] = [
    ("1.1.1.1", 443),
    ("1.0.0.1", 443),
  ]

  private static let routeTimeout: TimeInterval = 2
  private static let probeTimeout: TimeInterval = 1.5

  /// Convert the Dart `targets` argument into host/port pairs.
  static func parseTargets(_ arguments: Any?) -> [Target] {
    guard
      let args = arguments as? [String: Any],
      let raw = args["targets"] as? [[String: Any]]
    else {
      return defaultTargets
    }
    let parsed: [Target] = raw.compactMap { entry in
      guard let host = entry["host"] as? String else { return nil }
      let port = UInt16((entry["port"] as? NSNumber)?.intValue ?? 443)
      return (host, port)
    }
    return parsed.isEmpty ? defaultTargets : parsed
  }

  static func checkOnce(targets: [Target], completion: @escaping (Bool) -> Void) {
    routeAvailable { hasRoute in
      guard hasRoute else {
        DispatchQueue.main.async { completion(false) }
        return
      }
      probeReachability(targets: targets, index: 0) { reachable in
        DispatchQueue.main.async { completion(reachable) }
      }
    }
  }

  /// Reads the current OS path once via a fresh, short-lived `NWPathMonitor`.
  private static func routeAvailable(_ completion: @escaping (Bool) -> Void) {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "com.maniacone.flutter_query_client.route")
    var didComplete = false

    func finish(_ satisfied: Bool) {
      guard !didComplete else { return }
      didComplete = true
      monitor.cancel()
      completion(satisfied)
    }

    monitor.pathUpdateHandler = { path in
      finish(path.status == .satisfied)
    }
    monitor.start(queue: queue)

    // Safety net in case the handler never fires.
    queue.asyncAfter(deadline: .now() + routeTimeout) {
      finish(monitor.currentPath.status == .satisfied)
    }
  }

  /// Attempts a TCP connection to each probe target in order, succeeding on
  /// the first that becomes `.ready`.
  private static func probeReachability(
    targets: [Target],
    index: Int,
    completion: @escaping (Bool) -> Void
  ) {
    guard index < targets.count else {
      completion(false)
      return
    }

    let target = targets[index]
    let queue = DispatchQueue(label: "com.maniacone.flutter_query_client.probe")
    let connection = NWConnection(
      host: NWEndpoint.Host(target.host),
      port: NWEndpoint.Port(rawValue: target.port)!,
      using: .tcp
    )
    var didComplete = false

    func finish(reachable: Bool) {
      guard !didComplete else { return }
      didComplete = true
      connection.cancel()
      if reachable {
        completion(true)
      } else {
        // Try the next target before declaring the device offline.
        probeReachability(targets: targets, index: index + 1, completion: completion)
      }
    }

    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        finish(reachable: true)
      case .failed, .cancelled:
        finish(reachable: false)
      default:
        break
      }
    }
    connection.start(queue: queue)

    queue.asyncAfter(deadline: .now() + probeTimeout) {
      finish(reachable: false)
    }
  }
}

/// Emits a hint on every OS network path change via a long-lived
/// `NWPathMonitor`. The payload is meaningless — Dart re-probes on receipt.
private class NetworkHintStreamHandler: NSObject, FlutterStreamHandler {
  private var monitor: NWPathMonitor?
  private let queue = DispatchQueue(label: "com.maniacone.flutter_query_client.hints")

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    let monitor = NWPathMonitor()
    self.monitor = monitor
    monitor.pathUpdateHandler = { _ in
      DispatchQueue.main.async { events(true) }
    }
    monitor.start(queue: queue)
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    monitor?.cancel()
    monitor = nil
    return nil
  }
}
