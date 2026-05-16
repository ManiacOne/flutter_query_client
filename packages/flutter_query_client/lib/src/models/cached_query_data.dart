class CachedQueryData<T> {
  final T data;
  final DateTime fetchTime;
  final Duration? staleTime;
  final Duration? gcTime;

  CachedQueryData({
    required this.data,
    required this.fetchTime,
    this.staleTime,
    this.gcTime,
  });

  bool get isStale {
    if (staleTime == null) return false;
    return DateTime.now().isAfter(fetchTime.add(staleTime!));
  }

  bool get isValid {
    return data != null;
  }
}
