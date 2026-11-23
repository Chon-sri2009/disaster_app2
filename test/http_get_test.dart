import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:disaster_app2/services/http_get.dart';

void main() {
  late HttpServer server;
  final sockets = <Socket>[];
  late Uri url;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = Uri.parse('http://127.0.0.1:${server.port}/x');
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('requestTimeout_is_well_under_the_30s_poll_tick', () {
    expect(requestTimeout, lessThan(const Duration(seconds: 30)));
  });

  test('server_that_accepts_and_never_answers_times_out_and_is_closed', () async {
    final closed = Completer<void>();
    server.listen((req) async {
      final socket = await req.response.detachSocket(writeHeaders: false);
      sockets.add(socket);
      socket.listen((_) {}, onDone: () {
        if (!closed.isCompleted) closed.complete();
      }, onError: (_) {
        if (!closed.isCompleted) closed.complete();
      });
    });
    final sw = Stopwatch()..start();
    await expectLater(
      httpGetText(url, timeout: const Duration(milliseconds: 200)),
      throwsA(isA<TimeoutException>()),
    );
    expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    await closed.future.timeout(const Duration(seconds: 3));
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('server_that_sends_headers_then_stalls_the_body_times_out', () async {
    final closed = Completer<void>();
    server.listen((req) async {
      final socket = await req.response.detachSocket(writeHeaders: false);
      socket.add('HTTP/1.1 200 OK\r\nContent-Length: 1000\r\n\r\nabc'.codeUnits);
      await socket.flush();
      socket.listen((_) {}, onDone: () {
        if (!closed.isCompleted) closed.complete();
      }, onError: (_) {
        if (!closed.isCompleted) closed.complete();
      });
    });
    await expectLater(
      httpGetText(url, timeout: const Duration(milliseconds: 200)),
      throwsA(isA<TimeoutException>()),
    );
    await closed.future.timeout(const Duration(seconds: 3));
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('normal_response_still_returns_the_body', () async {
    server.listen((req) {
      req.response
        ..statusCode = 200
        ..write('hello');
      req.response.close();
    });
    expect(await httpGetText(url), 'hello');
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('non_200_is_an_error', () async {
    server.listen((req) {
      req.response
        ..statusCode = 500
        ..close();
    });
    await expectLater(httpGetText(url), throwsA(isA<HttpException>()));
  }, timeout: const Timeout(Duration(seconds: 10)));
}
