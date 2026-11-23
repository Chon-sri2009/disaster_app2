import 'dart:async';
import 'dart:convert';
import 'dart:io';

// One deadline for the whole request: connect, headers and the full body. Under the 30 s poll
// tick, so a stalled server frees the refresh guard before the next beat.
const requestTimeout = Duration(seconds: 15);

// Downloads a text body over HTTP(S); anything but 200 is an error. A server that connects
// and then stalls (or trickles bytes) ends in a TimeoutException, like any failed fetch.
Future<String> httpGetText(Uri url, {Duration timeout = requestTimeout}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    return await _get(client, url).timeout(
      timeout,
      onTimeout: () {
        // Force-close drops the half-open socket; the inner future then fails and is ignored.
        client.close(force: true);
        throw TimeoutException('request timed out', timeout);
      },
    );
  } finally {
    client.close(force: true);
  }
}

Future<String> _get(HttpClient client, Uri url) async {
  final res = await (await client.getUrl(url)).close();
  if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
  return utf8.decodeStream(res);
}
