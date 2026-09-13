import 'fdc_models.dart';

/// The two FoodData Central operations this pipeline needs, as an interface
/// so a cache can stand in for the live client.
///
/// [FdcClient] is the live implementation; [CachingFdcSource] wraps one (or
/// stands alone, reading only what is already on disk). `fetch_catalog`
/// talks to this type and never knows which it has.
abstract interface class FdcSource {
  /// Searches FDC for [query]. Pass `dataType: null` to search all data
  /// types, for items absent from [FdcClient.preferredDataTypes].
  Future<List<FdcFood>> search(String query, {int pageSize, String? dataType});

  /// Full nutrient detail for one food by its FDC id.
  Future<FdcFood> getDetails(int fdcId);

  void close();
}
