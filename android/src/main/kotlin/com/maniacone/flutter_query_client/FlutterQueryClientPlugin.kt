package com.maniacone.flutter_query_client

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

private const val METHOD_CHANNEL_NAME = "flutter_query_client/connectivity"
private const val EVENT_CHANNEL_NAME = "flutter_query_client/connectivity/events"

/**
 * Default TCP reachability probe targets, used when the Dart side does not
 * supply its own. Port 443 (HTTPS) is allowed outbound on virtually every
 * network — corporate firewalls, captive portals, and censored regions almost
 * always permit it, whereas DNS port 53 is frequently blocked or hijacked.
 * The first that connects wins; only if all fail is the device reported
 * offline. Consumers should override these with their own backend host via
 * `QueryDefaults.connectivityProbeTargets`.
 */
private val DEFAULT_PROBE_TARGETS = listOf(
    "1.1.1.1" to 443,
    "1.0.0.1" to 443,
)

private const val PROBE_TIMEOUT_MS = 1500

/**
 * Reports device internet connectivity to the Dart side.
 *
 * Exposes two channels:
 *
 * - A **method channel** with a single `isConnected` call. It first checks the
 *   OS route ([ConnectivityManager.activeNetwork]); if a route exists it opens
 *   a short-lived TCP connection to a reliable host to confirm *real* internet.
 *   This catches "connected to Wi-Fi/emulator but no actual internet", which
 *   `NET_CAPABILITY_VALIDATED` alone reports too slowly. The probe runs off the
 *   platform thread so it never blocks the UI.
 *
 * - An **event channel** that emits a lightweight hint whenever the OS network
 *   path changes (via [ConnectivityManager.NetworkCallback]). The Dart side
 *   re-probes on each hint, so detection is instant and event-driven while the
 *   probe remains the single source of truth — a stale/spurious event can only
 *   trigger a fresh probe, never set a wrong value.
 */
class FlutterQueryClientPlugin : FlutterPlugin, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var connectivityManager: ConnectivityManager

    private val mainHandler = Handler(Looper.getMainLooper())
    private var probeExecutor: ExecutorService = Executors.newCachedThreadPool()

    private var eventSink: EventChannel.EventSink? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        connectivityManager =
            binding.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE)
                    as ConnectivityManager

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler { call, result ->
            if (call.method == "isConnected") {
                val targets = parseTargets(call.argument("targets"))
                // Probe off the platform thread; never block it on a socket.
                probeExecutor.execute {
                    val connected = currentlyConnected(targets)
                    mainHandler.post { result.success(connected) }
                }
            } else {
                result.notImplemented()
            }
        }

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        unregisterNetworkCallback()
        probeExecutor.shutdownNow()
    }

    // ── EventChannel.StreamHandler ───────────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = sendHint()
            override fun onLost(network: Network) = sendHint()
            override fun onUnavailable() = sendHint()
            override fun onCapabilitiesChanged(
                network: Network,
                capabilities: NetworkCapabilities,
            ) = sendHint()
        }
        networkCallback = callback

        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        try {
            connectivityManager.registerNetworkCallback(request, callback)
        } catch (_: Exception) {
            // Registration can throw on some OEM devices — polling backstop
            // on the Dart side still covers detection.
        }
    }

    override fun onCancel(arguments: Any?) {
        unregisterNetworkCallback()
        eventSink = null
    }

    /** Emit a hint (payload is meaningless — Dart re-probes on receipt). */
    private fun sendHint() {
        mainHandler.post { eventSink?.success(true) }
    }

    private fun unregisterNetworkCallback() {
        networkCallback?.let {
            try {
                connectivityManager.unregisterNetworkCallback(it)
            } catch (_: Exception) {
                // Already unregistered.
            }
        }
        networkCallback = null
    }

    // ── Active reachability probe ────────────────────────────────────────

    /** Convert the Dart `targets` argument into host/port pairs. */
    private fun parseTargets(raw: List<Map<String, Any?>>?): List<Pair<String, Int>> {
        if (raw.isNullOrEmpty()) return DEFAULT_PROBE_TARGETS
        val parsed = raw.mapNotNull { entry ->
            val host = entry["host"] as? String ?: return@mapNotNull null
            val port = (entry["port"] as? Number)?.toInt() ?: 443
            host to port
        }
        return parsed.ifEmpty { DEFAULT_PROBE_TARGETS }
    }

    private fun currentlyConnected(targets: List<Pair<String, Int>>): Boolean {
        // Fast path: no active network at all → definitively offline, no probe.
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities =
            connectivityManager.getNetworkCapabilities(network) ?: return false
        if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            return false
        }

        // A route exists — confirm *real* reachability with a short TCP connect.
        return canReachAnyProbeTarget(targets)
    }

    private fun canReachAnyProbeTarget(targets: List<Pair<String, Int>>): Boolean {
        for ((host, port) in targets) {
            try {
                Socket().use { socket ->
                    socket.connect(InetSocketAddress(host, port), PROBE_TIMEOUT_MS)
                }
                return true
            } catch (_: IOException) {
                // Unreachable — try the next target.
            } catch (_: Exception) {
                // Any other failure — treat this target as unreachable.
            }
        }
        return false
    }
}
