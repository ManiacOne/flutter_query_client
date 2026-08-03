import 'dart:async';
import 'dart:io';

/// Whether [error] looks like a **device-level network failure** (no
/// connectivity, DNS failure, connection dropped) rather than a server-side
/// error such as an HTTP 4xx/5xx.
///
/// Used by the controllers to decide whether a failed query should ask the
/// connectivity observer to re-check reachability. The distinction matters
/// because in this package a confirmed `offline→online` transition triggers a
/// refetch of every registered controller — so a plain server error must not
/// be mistaken for "the network went down". This check is deliberately
/// conservative: a false negative merely defers to the OS event / probe
/// backstop, and a false positive only triggers a harmless confirmation probe.
bool isNetworkError(Object error) {
  if (error is SocketException) return true;
  if (error is TimeoutException) return true;
  if (error is HttpException) return true;
  if (error is HandshakeException) return true;

  final message = error.toString();
  return message.contains('SocketException') ||
      message.contains('Failed host lookup') ||
      message.contains('Network is unreachable') ||
      message.contains('Connection refused') ||
      message.contains('Connection closed') ||
      message.contains('Connection reset') ||
      message.contains('Connection timed out') ||
      message.contains('Software caused connection abort');
}
