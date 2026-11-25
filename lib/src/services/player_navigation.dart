/// External destinations are untrusted. Do not dispatch executable/custom
/// schemes or credential-bearing/local/IP URLs to another app.
Uri? playerHttpsDestination(String input) {
  final uri = Uri.tryParse(input);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (!RegExp(
        r'^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$',
      ).hasMatch(host) ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.endsWith('.internal')) {
    return null;
  }
  return uri;
}
