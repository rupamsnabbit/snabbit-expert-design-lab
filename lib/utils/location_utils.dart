import 'package:flutter/foundation.dart';
import 'package:location/location.dart' as loc;

class LocationUtils{
  static Future<loc.LocationData?> getLocation() async {
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;
    loc.LocationData locationData;
    final loc.Location location = loc.Location();

    // Check if location services are enabled
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return null;
      }
    }

    // Check for location permissions
    permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        return null;
      }
    }

    // Get the current location
    locationData = await location.getLocation();
    // getPlaceId(locationData.latitude!, locationData.longitude!);
    debugPrint(locationData.latitude!.toString());
    debugPrint(locationData.longitude!.toString());
    return locationData;
  }
}