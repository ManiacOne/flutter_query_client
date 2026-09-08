import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controller that OVERRIDES refetchOnMount => always. Pre-seed its cache,
/// then create it: on a fresh cache hit it background-refetches only if the
/// resolved refetchOnMount is `always`.
class MountAlwaysController extends QueryController<List<String>, void> {
  int fetchCount = 0;
  MountAlwaysController() : super('prec-mount');
  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.always;
  @override
  Duration? get staleTime => const Duration(minutes: 10); // stays fresh
  @override
  int get retryCount => 1;
  @override
  Future<List<String>> queryFn(void _) async {
    fetchCount++;
    return ['fetched'];
  }
}

/// A controller with NO refetchOnMount override — should follow the global.
class MountDefaultController extends QueryController<List<String>, void> {
  int fetchCount = 0;
  MountDefaultController() : super('prec-mount');
  @override
  Duration? get staleTime => const Duration(minutes: 10);
  @override
  int get retryCount => 1;
  @override
  Future<List<String>> queryFn(void _) async {
    fetchCount++;
    return ['fetched'];
  }
}

/// Overrides retryCount => 1; queryFn always fails counting attempts.
class RetryOneController extends QueryController<String, void> {
  int attempts = 0;
  RetryOneController() : super('prec-retry');
  @override
  int get retryCount => 1;
  @override
  Duration get retryDelay => const Duration(milliseconds: 1);
  @override
  NetworkMode get networkMode => NetworkMode.always;
  @override
  Future<String> queryFn(void _) async {
    attempts++;
    throw Exception('boom');
  }
}

void main() {
  setUp(() {
    NetworkConnectivityObserver.testMode = true;
    QueryClient.instance.clear();
    QueryClient.instance.setDefaults(const QueryDefaults());
  });

  test('controller refetchOnMount:always WINS over global refetchOnMount:never',
      () async {
    QueryClient.instance
        .setDefaults(const QueryDefaults(refetchOnMount: RefetchOnMount.never));
    // Pre-seed a fresh cache entry so mount takes the cache-hit branch.
    QueryClient.instance.set<List<String>>(
      'prec-mount',
      null,
      CachedQueryData<List<String>>(
        data: ['seed'],
        fetchTime: DateTime.now(),
        staleTime: const Duration(minutes: 10),
      ),
    );

    final c = MountAlwaysController();
    await Future.delayed(const Duration(milliseconds: 80));

    expect(c.fetchCount, 1,
        reason: 'controller override must beat the global default');
    await c.close();
  });

  test('no controller override → global refetchOnMount:never applies', () async {
    QueryClient.instance
        .setDefaults(const QueryDefaults(refetchOnMount: RefetchOnMount.never));
    QueryClient.instance.set<List<String>>(
      'prec-mount',
      null,
      CachedQueryData<List<String>>(
        data: ['seed'],
        fetchTime: DateTime.now(),
        staleTime: const Duration(minutes: 10),
      ),
    );

    final c = MountDefaultController();
    await Future.delayed(const Duration(milliseconds: 80));

    expect(c.fetchCount, 0,
        reason: 'global default applies when the controller does not override');
    await c.close();
  });

  test('controller retryCount:1 WINS over global retryCount:5', () async {
    QueryClient.instance.setDefaults(const QueryDefaults(retryCount: 5));

    final c = RetryOneController();
    await Future.delayed(const Duration(milliseconds: 120));

    expect(c.attempts, 1,
        reason: 'controller retryCount override must beat the global default');
    await c.close();
  });
}
