import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fdc_cache.dart';
import 'fdc_models.dart';
import 'fdc_source.dart';

/// Thrown for a non-2xx FDC response. [message] never includes the
/// request URL — that would leak the API key into logs.
class FdcApiException implements Exception {
  FdcApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'FdcApiException($statusCode): $message';
}

/// A thin client for the parts of the USDA FoodData Central API this
/// pipeline needs: search and food-details. Build-time only — never
/// bundled into the app (AP-1, no network at runtime).
///
/// The [apiKey] is read by the CLI entry point from the `FDC_API_KEY`
/// environment variable and passed in here; it is never hardcoded,
/// written to a file, or included in any exception/log message this
/// client produces.
class FdcClient implements FdcSource {
  FdcClient({required String apiKey, http.Client? httpClient})
    : _apiKey = apiKey,
      _http = httpClient ?? http.Client();

  final String _apiKey;
  final http.Client _http;

  static final _base = Uri.parse('https://api.nal.usda.gov/fdc/v1');

  /// Measured/lab-analysed data (not survey estimates or branded
  /// products) — the `dataType` filter matching the catalog's preferred
  /// `quality_tier` (§19.11).
  static const preferredDataTypes = FdcClientDataTypes.preferred;

  /// Searches FDC for [query]. Pass `dataType: null` to search all FDC
  /// data types, for items (e.g. jaggery) absent from [preferredDataTypes].
  @override
  Future<List<FdcFood>> search(
    String query, {
    int pageSize = 5,
    String? dataType = preferredDataTypes,
  }) async {
    final uri = _base.replace(
      path: '${_base.path}/foods/search',
      queryParameters: {
        'api_key': _apiKey,
        'query': query,
        'pageSize': '$pageSize',
        if (dataType != null) 'dataType': dataType,
      },
    );

    final response = await _http.get(uri);
    _checkStatus(response, context: 'search "$query"');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final foods = (body['foods'] as List?) ?? const [];
    return [for (final f in foods) FdcFood.fromJson(f as Map<String, dynamic>)];
  }

  /// Fetches full nutrient detail for a specific food by its FDC id.
  @override
  Future<FdcFood> getDetails(int fdcId) async {
    final uri = _base.replace(
      path: '${_base.path}/food/$fdcId',
      queryParameters: {'api_key': _apiKey},
    );

    final response = await _http.get(uri);
    _checkStatus(response, context: 'food details for fdcId $fdcId');

    return FdcFood.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _checkStatus(http.Response response, {required String context}) {
    if (response.statusCode ~/ 100 != 2) {
      throw FdcApiException(
        response.statusCode,
        'FDC request failed ($context)',
      );
    }
  }

  @override
  void close() => _http.close();
}
