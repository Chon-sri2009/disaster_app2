import 'dart:convert';
import 'dart:io';

// Downloads a text body over HTTP(S); anything but 200 is an error.
Future<String> httpGetText(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final res = await (await client.getUrl(url)).close();
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
    return await utf8.decodeStream(res);
  } finally {
    client.close();
  }
}
