import 'dart:async';
import 'dart:io';

import 'package:badges_bar/src/pub_client.dart';
import 'package:sentry/sentry.dart';

import 'sentry.dart';
import 'base.dart';
import 'svg.dart';

Future<void> start() async {
  Sentry.init(
      "https://09a6dc7f166e467793a5d2bc7c7a7df2@o117736.ingest.sentry.io/1857674",
      (SentryClient sentry) => _run(sentry));
}

Future<void> _run(SentryClient sentry) async {
  final httpClient = new HttpClient();
  httpClient.idleTimeout = Duration(minutes: 2);

  var client = PubClient(httpClient);

  var server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    31337,
  );

  print('Listening on localhost:${server.port}');

  int counter = 0;
  await for (final request in server) {
    try {
      final current = counter++;
      print('Starting to serving request: $current');
      _serve(request, client)
          .whenComplete(() => print('Done serving request: $current'));
    } catch (e, s) {
      await sentry.captureException(exception: e, stackTrace: s);
    }
  }
}

Future<void> _serve(HttpRequest request, PubClient client) async {
  if (request.method != 'GET' ||
      request.requestedUri.pathSegments.length < 2 ||
      !scoreTypes.contains(request.requestedUri.pathSegments.last)) {
    request.response.statusCode = 400;
    await request.response.close();
    return;
  }

  final response = request.response;

  response.headers.add('Cache-Control', 'max-age=3600');

  final scoreType = request.requestedUri.pathSegments.last;
  final package = request.requestedUri.pathSegments.reversed.skip(1).first;

  request.response.headers.contentType = contentTypeSvg;

  final score = await client.getScore(package);
  request.response
      .write(svg(scoreType, score.getValueByType(scoreType).toString()));

  await request.response.close();
}

final contentTypeSvg = new ContentType("image", "svg+xml");