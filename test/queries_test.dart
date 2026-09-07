import 'dart:async';

import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_test/flutter_test.dart';

// A QueriesController whose fetches are gated by a Completer per param, so
// per-param loading is observable deterministically.
class GatedQueries extends QueriesController<String, int> {
  GatedQueries(String key) : super(key);
  final Map<int, Completer<String>> gates = {};
  final Map<int, int> fetchCounts = {};

  @override
  NetworkMode get networkMode => NetworkMode.always;

  @override
  int get retryCount => 1;

  @override
  Future<String> queryFn(int params) {
    fetchCounts[params] = (fetchCounts[params] ?? 0) + 1;
    return (gates[params] ??= Completer<String>()).future;
  }

  void resolve(int p, String value) {
    gates[p]!.complete(value);
    gates.remove(p);
  }
}

void main() {
  setUp(() {
    NetworkConnectivityObserver.testMode = true;
    QueryClient.instance.clear();
    QueryClient.instance.setDefaults(const QueryDefaults());
  });

  group('Query engine (fetchQuery / stateFor)', () {
    test('dedup: concurrent fetches for the same key run queryFn once',
        () async {
      var calls = 0;
      final gate = Completer<String>();
      final client = QueryClient.instance;

      final f1 = client.fetchQuery<String>('dedup', 1,
          networkMode: NetworkMode.always, queryFn: () async {
        calls++;
        return gate.future;
      });
      final f2 = client.fetchQuery<String>('dedup', 1,
          networkMode: NetworkMode.always, queryFn: () async {
        calls++;
        return 'second';
      });

      gate.complete('first');
      final r1 = await f1;
      final r2 = await f2;

      expect(calls, 1, reason: 'the second call joined the in-flight request');
      expect(r1, 'first');
      expect(r2, 'first');
    });

    test('stateFor reflects loading → success for a param', () async {
      final client = QueryClient.instance;
      final gate = Completer<String>();

      expect(client.stateFor<String>('s', 9).isIdle, isTrue);

      final fut = client.fetchQuery<String>('s', 9,
          networkMode: NetworkMode.always, queryFn: () => gate.future);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(client.stateFor<String>('s', 9).isLoading, isTrue);

      gate.complete('done');
      await fut;
      final state = client.stateFor<String>('s', 9);
      expect(state.isSuccess, isTrue);
      expect(state.data, 'done');
      expect(state.params, 9);
    });
  });

  group('QueriesController (useQueries analogue)', () {
    test('drives per-param loading from ONE instance', () async {
      final c = GatedQueries('nums');
      c.setParams([1, 2, 3]);
      await Future.delayed(const Duration(milliseconds: 10));

      // All three are independently loading.
      expect(c.stateFor(1).isLoading, isTrue);
      expect(c.stateFor(2).isLoading, isTrue);
      expect(c.stateFor(3).isLoading, isTrue);
      expect(c.state.length, 3);

      // Resolve one — only that param becomes success; the others stay loading.
      c.resolve(2, 'v-2');
      await Future.delayed(const Duration(milliseconds: 10));
      expect(c.stateFor(2).isSuccess, isTrue);
      expect(c.stateFor(2).data, 'v-2');
      expect(c.stateFor(1).isLoading, isTrue);
      expect(c.stateFor(3).isLoading, isTrue);

      c.resolve(1, 'v-1');
      c.resolve(3, 'v-3');
      await Future.delayed(const Duration(milliseconds: 10));
      expect(c.state[1]!.data, 'v-1');
      expect(c.state[3]!.data, 'v-3');

      await c.close();
    });

    test('refetch(param) refetches only that param', () async {
      final c = GatedQueries('nums2');
      c.setParams([1, 2]);
      c.resolve(1, 'a');
      c.resolve(2, 'b');
      await Future.delayed(const Duration(milliseconds: 10));
      expect(c.fetchCounts[1], 1);
      expect(c.fetchCounts[2], 1);

      unawaited(c.refetch(1));
      await Future.delayed(const Duration(milliseconds: 5));
      c.resolve(1, 'a2');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(c.fetchCounts[1], 2, reason: 'param 1 refetched');
      expect(c.fetchCounts[2], 1, reason: 'param 2 untouched');
      expect(c.stateFor(1).data, 'a2');

      await c.close();
    });

    test('two controllers on the same key + param share one fetch (dedup)',
        () async {
      final a = GatedQueries('shared');
      final b = GatedQueries('shared');
      a.setParams([7]);
      b.setParams([7]);
      await Future.delayed(const Duration(milliseconds: 10));

      // Only the first controller's queryFn ran; b joined the in-flight fetch.
      final totalCalls = (a.fetchCounts[7] ?? 0) + (b.fetchCounts[7] ?? 0);
      expect(totalCalls, 1);

      a.resolve(7, 'shared-value');
      await Future.delayed(const Duration(milliseconds: 10));

      // Both controllers observe the same resolved data (shared cache entry).
      expect(a.stateFor(7).data, 'shared-value');
      expect(b.stateFor(7).data, 'shared-value');

      await a.close();
      await b.close();
    });

    test('invalidateQueries refetches every observed param', () async {
      final c = GatedQueries('invq');
      c.setParams([1, 2]);
      c.resolve(1, 'a');
      c.resolve(2, 'b');
      await Future.delayed(const Duration(milliseconds: 10));
      expect(c.fetchCounts[1], 1);
      expect(c.fetchCounts[2], 1);

      QueryClient.instance.invalidateQueries(['invq']);
      await Future.delayed(const Duration(milliseconds: 5));
      c.resolve(1, 'a2');
      c.resolve(2, 'b2');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(c.fetchCounts[1], 2, reason: 'param 1 refetched on invalidate');
      expect(c.fetchCounts[2], 2, reason: 'param 2 refetched on invalidate');
      expect(c.stateFor(1).data, 'a2');
      expect(c.stateFor(2).data, 'b2');

      await c.close();
    });

    test('invalidate keeps previous data visible until new data arrives',
        () async {
      final c = GatedQueries('keepdata');
      c.setParams([1]);
      c.resolve(1, 'first');
      await Future.delayed(const Duration(milliseconds: 10));
      expect(c.stateFor(1).data, 'first');
      expect(c.stateFor(1).isSuccess, isTrue);

      // Invalidate → a background refetch starts, but the OLD data stays put
      // with a refetching + stale indicator (not wiped to empty).
      QueryClient.instance.invalidate('keepdata', serializeParams(1));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(c.stateFor(1).data, 'first',
          reason: 'previous data retained during refetch');
      expect(c.stateFor(1).isRefetching, isTrue);
      expect(c.stateFor(1).isStale, isTrue);

      // New data arrives → replaces, indicators clear.
      c.resolve(1, 'second');
      await Future.delayed(const Duration(milliseconds: 10));
      expect(c.stateFor(1).data, 'second');
      expect(c.stateFor(1).isRefetching, isFalse);
      expect(c.stateFor(1).isStale, isFalse);

      await c.close();
    });

    test('setParams removes params no longer observed', () async {
      final c = GatedQueries('nums3');
      c.setParams([1, 2, 3]);
      c.resolve(1, 'a');
      c.resolve(2, 'b');
      c.resolve(3, 'c');
      await Future.delayed(const Duration(milliseconds: 10));
      expect(c.state.length, 3);

      c.setParams([1]);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(c.state.length, 1);
      expect(c.state.containsKey(1), isTrue);

      await c.close();
    });
  });
}
