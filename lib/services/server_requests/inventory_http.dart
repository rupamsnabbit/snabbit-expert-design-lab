import 'package:dio/dio.dart';
import 'package:snabbit_runner/models/inventory_item.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';

class InventoryHttp {
  static Future<Response?> getInventoryItems({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/inventory/inventory_items"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> setInventoryItems(int runnerId,{
    Map<String, dynamic>? headers,
    required List<InventoryItem> inventoryItems,
    bool confirmStockOut = false,
  }) async {
    try {
      final items= inventoryItems.map((item) => item.toJson()).toList();
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/inventory/inventory_items/$runnerId"),
        headers: headers ?? {},
        data: {
          "items": items,
          "confirm_stockout": confirmStockOut,
        },
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}