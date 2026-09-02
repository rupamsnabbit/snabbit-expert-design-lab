import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../utils/colors.dart';

class MapJobLocation extends StatelessWidget {
  final LatLng markerPosition;
  final String? adm;
  // Optional per-screen tap hook. Lets each parent fire its own
  // analytics event (e.g. hotspot_show_directions_cta_click vs
  // arrival_show_directions_cta_click) without conflating them
  // inside this shared widget.
  final VoidCallback? onDirectionsTap;
  const MapJobLocation({
    super.key,
    required this.markerPosition,
    this.adm = "walking",
    this.onDirectionsTap,
  });

  void openMapWithCoordinates(
      double latitude, double longitude, BuildContext context) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=${adm ?? "walking"}';

    try {
      await launchUrlString(url);
    } catch (e) {
      if (context.mounted) {
        showSnackbar(context, "Error occurred. $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          GoogleMap(
            liteModeEnabled: true, // Reduce GPU usage for better stability
            scrollGesturesEnabled: false,
            zoomControlsEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            initialCameraPosition: CameraPosition(
              target: markerPosition,
              zoom: 15,
            ),
            myLocationButtonEnabled: false,
            myLocationEnabled: true,
            // markers: markers,
            markers: {
              Marker(
                markerId: MarkerId("job_location"),
                position: markerPosition,
              ),
            },
          ),
          Positioned.fill(
            bottom: 13,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 156,
                height: 34,
                child: ElevatedButton(
                  onPressed: () async {
                    openMapWithCoordinates(markerPosition.latitude,
                        markerPosition.longitude, context);
                    await ClevertapSetup.logEvent(TrackingEvents.clickedOnMap,
                        {"action": "clicked on map"});
                    onDirectionsTap?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.n0,
                    foregroundColor: AppColors.n90,
                    textStyle: Theme.of(context).textTheme.labelMedium,
                    padding: EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 0,
                    ),
                  ),
                  child: FittedBox(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions),
                        SizedBox(width: 8),
                        Text("Show directions"),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
