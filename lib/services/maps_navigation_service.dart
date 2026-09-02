import 'package:url_launcher/url_launcher.dart';

class MapsNavigationService {
  MapsNavigationService._();

  /// Launch Google Maps walking navigation to the given coordinates.
  /// Validates coordinate ranges before launching to guard against
  /// malformed API data.
  static Future<void> launchNavigation(double lat, double lng) async {
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return;
    }
    // Try Google Maps navigation intent first
    final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=w');
    if (await canLaunchUrl(navUri)) {
      await launchUrl(navUri);
    } else {
      // Fallback: open in browser
      final browserUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking',
      );
      await launchUrl(browserUri, mode: LaunchMode.externalApplication);
    }
  }
}
