import 'dart:convert';

import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('FdcClient', () {
    test('search sends the api key and query as URL parameters', () async {
      late Uri capturedUri;
      final client = FdcClient(
        apiKey: 'test-key-not-a-real-secret',
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({'foods': <Map<String, dynamic>>[]}),
            200,
          );
        }),
      );

      await client.search('toor dal');

      expect(capturedUri.path, '/fdc/v1/foods/search');
      expect(
        capturedUri.queryParameters['api_key'],
        'test-key-not-a-real-secret',
      );
      expect(capturedUri.queryParameters['query'], 'toor dal');
      client.close();
    });

    test('search parses the returned foods list', () async {
      final client = FdcClient(
        apiKey: 'k',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'foods': [
                {
                  'fdcId': 169414,
                  'description': 'Rice, white, cooked',
                  'dataType': 'SR Legacy',
                  'foodNutrients': [
                    {
                      'nutrientName': 'Energy',
                      'unitName': 'KCAL',
                      'value': 130,
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );

      final results = await client.search('rice');

      expect(results, hasLength(1));
      expect(results.single.description, 'Rice, white, cooked');
      client.close();
    });

    test('getDetails requests the exact fdcId path', () async {
      late Uri capturedUri;
      final client = FdcClient(
        apiKey: 'k',
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({'fdcId': 169414, 'description': 'Rice'}),
            200,
          );
        }),
      );

      await client.getDetails(169414);

      expect(capturedUri.path, '/fdc/v1/food/169414');
      client.close();
    });

    test(
      'a non-2xx response throws FdcApiException without leaking the api key',
      () async {
        final client = FdcClient(
          apiKey: 'super-secret-key',
          httpClient: MockClient(
            (request) async => http.Response('rate limited', 429),
          ),
        );

        try {
          await client.search('rice');
          fail('expected FdcApiException');
        } on FdcApiException catch (e) {
          expect(e.statusCode, 429);
          expect(e.toString(), isNot(contains('super-secret-key')));
        } finally {
          client.close();
        }
      },
    );
  });
}
