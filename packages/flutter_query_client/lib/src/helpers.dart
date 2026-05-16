import 'dart:convert';

String? serializeParams(Object? params) {
  if (params == null) return null;
  return _canonicalize(params);
}

String _canonicalize(Object? value) {
  if (value == null) return 'null';
  if (value is num || value is bool) return value.toString();
  if (value is String) return jsonEncode(value);
  if (value is List) {
    return '[${value.map(_canonicalize).join(',')}]';
  }
  if (value is Map) {
    final sortedEntries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    final parts = sortedEntries
        .map((e) => '${_canonicalize(e.key)}:${_canonicalize(e.value)}');
    return '{${parts.join(',')}}';
  }
  try {
    final json = (value as dynamic).toJson();
    return _canonicalize(json);
  } catch (_) {
    return jsonEncode(value.toString());
  }
}
