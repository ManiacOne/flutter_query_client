import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_test/flutter_test.dart';

const _methodChannelName = 'flutter_query_client/connectivity';
const _methodChannel = MethodChannel(_methodChannelName);

const _eventChannelName = 'flutter_query_client/connectivity/events';
// Same channel name, used only to install a mock handler for the EventChannel's
// `listen`/`cancel` control calls.
const _eventControlChannel = MethodChannel(_eventChannelName);

/// Mocks the native connectivity channels so tests can drive
/// [NetworkConnectivityObserver] without a real platform implementation.
///
/// - the **method channel** returns [isConnected] for the one-shot probe;
/// - the **event channel** captures the sink so a test can [emitHint] an OS
///   path-change hint and assert the observer re-probes immediately.
class _FakeNativeConnectivity {
  bool isConnected = true;

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void install() {
    _messenger.setMockMethodCallHandler(_methodChannel, (call) async {
      if (call.method == 'isConnected') return isConnected;
      return null;
    });
    // Accept the EventChannel's `listen`/`cancel` control calls so stream
    // activation succeeds; events are pushed manually via [emitHint].
    _messenger.setMockMethodCallHandler(
      _eventControlChannel,
      (call) async => null,
    );
  }

  /// Simulate the native side reporting an OS network path change by
  /// dispatching a success envelope on the event channel.
  void emitHint() {
    _messenger.handlePlatformMessage(
      _eventChannelName,
      const StandardMethodCodec().encodeSuccessEnvelope(true),
      (_) {},
    );
  }

  void uninstall() {
    _messenger.setMockMethodCallHandler(_methodChannel, null);
    _messenger.setMockMethodCallHandler(_eventControlChannel, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNativeConnectivity fakeNative;

  setUp(() {
    NetworkConnectivityObserver.testMode = false;
    // Poll fast in tests instead of waiting on the real backstop cadence.
    NetworkConnectivityObserver.pollInterval = const Duration(milliseconds: 20);
    NetworkConnectivityObserver.hintDebounce = const Duration(milliseconds: 5);
    fakeNative = _FakeNativeConnectivity()..install();
  });

  tearDown(() {
    fakeNative.uninstall();
    NetworkConnectivityObserver.instance.dispose();
    NetworkConnectivityObserver.pollInterval = const Duration(seconds: 15);
    NetworkConnectivityObserver.hintDebounce = const Duration(milliseconds: 250);
    NetworkConnectivityObserver.testMode = true;
  });

  group('NetworkConnectivityObserver (native probe + event hints)', () {
    test('reads initial status from the native isConnected probe', () async {
      fakeNative.isConnected = false;

      await NetworkConnectivityObserver.instance.initialize();

      expect(NetworkConnectivityObserver.instance.isOnline, isFalse);
    });

    test('a backstop poll detects a change in the probe result', () async {
      await NetworkConnectivityObserver.instance.initialize();
      expect(NetworkConnectivityObserver.instance.isOnline, isTrue);

      final events = <bool>[];
      NetworkConnectivityObserver.instance.onStatusChange.listen(events.add);

      fakeNative.isConnected = false;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(NetworkConnectivityObserver.instance.isOnline, isFalse);
      expect(events, contains(false));
    });

    test('an OS change hint triggers an immediate re-probe', () async {
      // Disable the backstop poll so only the hint path can flip the status.
      NetworkConnectivityObserver.pollInterval = const Duration(seconds: 30);

      await NetworkConnectivityObserver.instance.initialize();
      expect(NetworkConnectivityObserver.instance.isOnline, isTrue);

      final events = <bool>[];
      NetworkConnectivityObserver.instance.onStatusChange.listen(events.add);

      fakeNative.isConnected = false;
      fakeNative.emitHint();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(NetworkConnectivityObserver.instance.isOnline, isFalse);
      expect(events, contains(false));
    });

    test('detects reconnect after a disconnect', () async {
      await NetworkConnectivityObserver.instance.initialize();

      fakeNative.isConnected = false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(NetworkConnectivityObserver.instance.isOnline, isFalse);

      fakeNative.isConnected = true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(NetworkConnectivityObserver.instance.isOnline, isTrue);
    });

    test('reportReachable flips offline→online instantly and emits', () async {
      // Backstop off; only a request outcome can move the status.
      NetworkConnectivityObserver.pollInterval = const Duration(seconds: 30);
      final observer = NetworkConnectivityObserver.instance;

      // Start offline (probe says false).
      fakeNative.isConnected = false;
      await observer.initialize();
      expect(observer.isOnline, isFalse);

      final events = <bool>[];
      observer.onStatusChange.listen(events.add);

      // A real request succeeded — authoritative proof we're online.
      observer.reportReachable();
      expect(observer.isOnline, isTrue);

      // Broadcast delivery is async — let the emit propagate.
      await Future<void>.delayed(Duration.zero);
      expect(events, contains(true));
    });

    test('a request success overrides an in-flight offline probe', () async {
      NetworkConnectivityObserver.pollInterval = const Duration(seconds: 30);
      final observer = NetworkConnectivityObserver.instance;
      await observer.initialize();
      expect(observer.isOnline, isTrue);

      // The probe would report offline, but a real success races in and wins.
      fakeNative.isConnected = false;
      observer.reportUnreachable(); // schedules a confirmation probe
      observer.reportReachable(); // a request succeeded first

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The stale probe result must not clobber the confirmed-online status.
      expect(observer.isOnline, isTrue);
    });

    test('reportUnreachable alone does not flip offline without a probe '
        'confirmation', () async {
      NetworkConnectivityObserver.pollInterval = const Duration(seconds: 30);
      final observer = NetworkConnectivityObserver.instance;
      await observer.initialize();
      expect(observer.isOnline, isTrue);

      // Network error reported, but the probe still says we're online
      // (e.g. it was just one dead endpoint) → stay online.
      fakeNative.isConnected = true;
      observer.reportUnreachable();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(observer.isOnline, isTrue);
    });
  });

  group('QueryClientProvider.onConnectivityChanged', () {
    testWidgets('fires ConnectivityStatus when a probe detects a change', (
      tester,
    ) async {
      final changes = <ConnectivityStatus>[];

      await tester.pumpWidget(
        QueryClientProvider(
          onConnectivityChanged: changes.add,
          child: const SizedBox.shrink(),
        ),
      );

      // Allow the fire-and-forget ensureConnectivityInitialized() to settle.
      await tester.pump(const Duration(milliseconds: 20));

      // The OS reports a path change → the observer re-probes and finds we're
      // offline (this is the instant, event-driven path).
      fakeNative.isConnected = false;
      fakeNative.emitHint();
      await tester.pump(const Duration(milliseconds: 100));

      expect(changes, contains(ConnectivityStatus.offline));

      QueryClient.instance.dispose();
    });
  });
}
