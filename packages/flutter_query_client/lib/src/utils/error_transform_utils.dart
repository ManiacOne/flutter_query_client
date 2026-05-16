import 'package:flutter_query_client/src/models/query_defaults.dart';

/// Applies the provided [transformError] (or global default) to [error].
///
/// Falls back to returning the original [error] if the transform itself throws.
Object applyErrorTransform({
  required Object error,
  ErrorTransformer? controllerTransform,
  ErrorTransformer? globalTransform,
}) {
  final transform = controllerTransform ?? globalTransform;
  if (transform == null) return error;
  try {
    return transform(error);
  } catch (_) {
    return error;
  }
}
