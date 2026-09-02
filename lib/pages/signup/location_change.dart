// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/personal_details.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/gap.dart';

import '../../utils/colors.dart';

// enum MapModes {
//   mapMode,
//   searchMode,
// }

class LocationChange extends StatefulWidget {
  static const String routeName = "map";

  const LocationChange({super.key});

  @override
  State<LocationChange> createState() => _LocationChangeState();
}

class _LocationChangeState extends State<LocationChange>
    with WidgetsBindingObserver {
  bool init = true;

  // late UserProfileProvider userProfileProvider;
  // late AddressProvider addressProvider;
  int mapFlexValue = 74;

  // MapModes mapMode = MapModes.mapMode;
  // List<String> addressTags = ["Home", "Home 2", "Custom"];
  // TODO maybe use `Persistent Bottom sheet` (check demo.dart) for address details for better UX

  // static const LatLng _loc1 = LatLng(19.1164, 72.90471);
  // static const LatLng _loc2 = LatLng(19.226662, 72.983833);

  bool loading = true;
  bool buttonLoading = false;
  late GoogleMapController mapController;
  Location locationController = Location();
  LatLng? currentPosition;
  double zoomValue = 19;
  String? address;
  String? addressMainLine;
  String? selectedPlaceId;
  TextEditingController add1TextController = TextEditingController();
  TextEditingController add2TextController = TextEditingController();
  TextEditingController customAddTagTextController = TextEditingController();
  final FocusNode add1FocusNode = FocusNode();
  final FocusNode add2FocusNode = FocusNode();
  final FocusNode customAddTagFocusNode = FocusNode();
  bool isKeyboardVisible = false;
  bool isCustomSelected = false;
  String? placeId;
  Address? currentAddress;
  bool isCameraMoveStarted = false;

//
  late UserProfileProvider userProfileProvider;

  // late UserProfile userProfile;

  // Set<Marker> markers = {};

  // final Completer<GoogleMapController> mapController =
  //     Completer<GoogleMapController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    add1FocusNode.addListener(() {
      if (!add1FocusNode.hasFocus &&
          !add2FocusNode.hasFocus &&
          !customAddTagFocusNode.hasFocus) {
        setState(() {
          isKeyboardVisible = false;
        });
      }
    });
    add2FocusNode.addListener(() {
      if (!add1FocusNode.hasFocus &&
          !add2FocusNode.hasFocus &&
          !customAddTagFocusNode.hasFocus) {
        setState(() {
          isKeyboardVisible = false;
        });
      }
    });
    customAddTagFocusNode.addListener(() {
      if (!add1FocusNode.hasFocus &&
          !add2FocusNode.hasFocus &&
          !customAddTagFocusNode.hasFocus) {
        setState(() {
          isKeyboardVisible = false;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      // userProfile = userProfileProvider.user!;
      currentAddress = userProfileProvider.getCurrentAddress();

      placeId = currentAddress?.placeId;
      initProcess().then((_) {
        loading = false;
        // if autofocus = true on prev screen, then add below in postFrameCallback
        // add1FocusNode.unfocus();
        // add2FocusNode.unfocus();
        if (mounted) {
          setState(() {});
        }
      });
    }
    super.didChangeDependencies();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    final newValue = bottomInset > 0.0;

    if (isKeyboardVisible != newValue) {
      if (mounted) {
        setState(() {
          isKeyboardVisible = newValue;
        });
      }
    }
  }

  Future<void> initProcess() async {
    await getLocationUpdates();
    if (placeId != null) {
      await fetchPlaceDetails(placeId!);
    } else if (currentPosition != null) {
      await _getAddressFromLatLng(currentPosition!);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // Load the custom marker bitmap descriptor
    // BitmapDescriptor.fromAssetImage(
    //   ImageConfiguration(size: Size(100, 100), devicePixelRatio: 5),
    //   "assets/pngs/map_marker.png",
    // ).then((bitmapDescriptor) {
    //   // Create a marker with the custom bitmap descriptor
    //   Marker marker = Marker(
    //     markerId: MarkerId("custom_marker"),
    //     position: currentPosition!,
    //     icon: bitmapDescriptor,
    //   );
    //   setState(() {
    //     markers.add(marker);
    //   });
    // });
  }

  Future<void> getLocationUpdates() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await locationController.serviceEnabled();
    if (serviceEnabled) {
      serviceEnabled = await locationController.requestService();
    } else {
      // location service is not available.
      return;
    }
    permissionGranted = await locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await locationController.requestPermission();
      // TODO check grantedLimited thoroughly as its not tested
      if (permissionGranted != PermissionStatus.granted &&
          permissionGranted != PermissionStatus.grantedLimited) {
        return;
      }
    }
    LocationData currentLocation = await locationController.getLocation();
    if (currentLocation.latitude != null && currentLocation.longitude != null) {
      // setState(() {
      currentPosition =
          LatLng(currentLocation.latitude!, currentLocation.longitude!);
      // });
    }
    // locationController.onLocationChanged.listen((LocationData currentLocation) {
    //
    // });
  }

  Future<void> locateMe() async {
    LocationData currentLocation = await locationController.getLocation();
    if (currentLocation.latitude != null && currentLocation.longitude != null) {
      try {
        await mapController
            .animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(currentLocation.latitude!, currentLocation.longitude!),
          zoom: zoomValue,
        )));
      } catch (_) {
        // DO NOTHING
      }
      currentPosition =
          LatLng(currentLocation.latitude!, currentLocation.longitude!);
      setState(() {});
    }
  }

  Future<void> locateSelectedPlace(double lat, double lng) async {
    // if (currentLocation.latitude != null && currentLocation.longitude != null) {
    try {
      await mapController
          .animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(lat, lng),
        zoom: zoomValue,
      )));
    } catch (_) {
      // DO NOTHING
    }
    currentPosition = LatLng(lat, lng);
    setState(() {});
    // }
  }

  // Future<void> _getAddressFromCoordinates() async {
  //   // double latitude = double.parse(_latitudeController.text);
  //   // double longitude = double.parse(_longitudeController.text);
  //
  //   try {
  //     List<geocoding.Placemark> placemarks =
  //         await geocoding.placemarkFromCoordinates(
  //             currentPosition!.latitude, currentPosition!.longitude);
  //     if (placemarks.isNotEmpty) {
  //       geocoding.Placemark placemark = placemarks[0];
  //       setState(() {
  //         address = placemark;
  //       });
  //     } else {
  //       setState(() {
  //         address = null;
  //       });
  //     }
  //   } catch (e) {
  //     print('Error: $e');
  //     setState(() {
  //       address = null;
  //     });
  //   }
  // }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    if (selectedPlaceId == null) {
      try {
        final url = GlobalState().serverPath(
            'api/v1/geos/locations/details?lat=${position.latitude}&lng=${position.longitude}&skip_serviceability_check=true');

        final response = await HttpService().get(url, headers: {});
        if (response.statusCode == 200) {
          final data = response.data;
          // if (data['status'] == 'OK') {
          final addressMap = data['address'];
          address = addressMap["address_text"];
          addressMainLine = addressMap["name"];

          currentAddress?.placeId = data['place_id'];
          userProfileProvider.notifyUserListeners();

          // TODO maybe call this only on confirm location using places api for better info on all the elements
          // addressProvider.address.lat = position.latitude;
          // addressProvider.address.lng = position.longitude;
          // addressProvider.address.geoAddress = data['results'][0]["formatted_address"];
          // addressProvider.address.placeId = data['results'][0]["place_id"];
          // addressProvider.address.city = data['results'][0]["address_components"][6]["long_name"];
          // addressProvider.address.state = data['results'][0]["address_components"][8]["long_name"];
          // addressProvider.address.country = data['results'][0]["address_components"][9]["long_name"];
          // addressProvider.address.pinCode = data['results'][0]["address_components"][10]["long_name"];
          // } else {
          //   print('Geocoder failed due to: ${data['status']}');
          //   // return null;
          // }
        } else {
          print('Request failed with status: ${response.statusCode}');
          // return null;
        }
      } catch (_) {
        // TODO something went wrong. handle it ui wise
      }
    }
  }

  Future<void> fetchPlaceDetails(String placeId) async {
    selectedPlaceId = placeId;
    final String url = GlobalState()
        .serverPath('api/v1/geos/locations/place?place_id=$placeId');

    try {
      final response = await HttpService().get(url, headers: {});
      final data = response.data;
      // if (response != null) {
      if (response.statusCode == 200) {
        // TODO get other address details like city, pincode here
        await locateSelectedPlace(
            data['location']['lat'], data['location']['lng']);
        selectedPlaceId = placeId;
        // setState(() {
        address = data["address"]["address_text"];
        addressMainLine = data["address"]["name"];
        // });

        currentAddress?.placeId = data['place_id'];
        userProfileProvider.notifyUserListeners();
      } else {
        // throw Exception('Failed to fetch place details: ${data['status']}');
      }
    } catch (_) {

    }
    // }
    // else {
    //   // throw Exception('Failed to fetch place details: ${data['status']}');
    // }
  }

  @override
  void dispose() {
    add1TextController.dispose();
    add2TextController.dispose();
    add1FocusNode.dispose();
    add2FocusNode.dispose();
    customAddTagTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Column(
          children: [
            Expanded(
              flex: mapFlexValue,
              child: loading || currentPosition == null
                  ? const Center(
                      child: CupertinoActivityIndicator(),
                    )
                  : Stack(
                      children: [
                        GoogleMap(
                          liteModeEnabled: true, // Reduce GPU usage for better stability
                          onMapCreated: _onMapCreated,
                          // onMapCreated: ((GoogleMapController controller) =>
                          //     mapController.complete(controller)),
                          onCameraMoveStarted: () {
                            selectedPlaceId = null;
                            isCameraMoveStarted = true;
                          },
                          onCameraIdle: () async {
                            // zoomValue = position.zoom;
                            // _onMapCreated(mapController);
                            if (currentPosition != null && isCameraMoveStarted) {
                              await _getAddressFromLatLng(currentPosition!);
                            }
                            setState(() {
                              // currentPosition = position.target;
                            });
                          },
                          scrollGesturesEnabled: true,
                          zoomControlsEnabled: true,
                          rotateGesturesEnabled: true,
                          tiltGesturesEnabled: true,
                          onCameraMove: (CameraPosition position) async {
                            // zoomValue = position.zoom;
                            // _onMapCreated(mapController);
                            // address = await _getAddressFromLatLng(position.target);
                            // setState(() {
                            currentPosition = position.target;
                            // });
                          },
                          initialCameraPosition: CameraPosition(
                            target: currentPosition!,
                            zoom: zoomValue,
                          ),
                          myLocationButtonEnabled: false,
                          myLocationEnabled: true,
                          // markers: markers,
                          // markers: mapMode ==
                          //     MapModes.confirmedAddressMode
                          //     ? {
                          //   Marker(
                          //     markerId: MarkerId("confirmed_location"),
                          //     // icon: BitmapDescriptor.defaultMarker,
                          //     icon: BitmapDescriptor
                          //         .defaultMarkerWithHue(210),
                          //     position: currentPosition!,
                          //     // infoWindow: InfoWindow(
                          //     //   title: "Move the pin to place accurately ",
                          //     //   anchor: Offset(1,-2),
                          //     // ),
                          //   ),
                          // }
                          //     : {},
                        ),
                        // if (mapMode == MapModes.mapMode)
                        Positioned.fill(
                          bottom: 8,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: InkWell(
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.35,
                                // height: 34,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 16),
                                decoration: BoxDecoration(
                                    // color: AppColors.n0,
                                    borderRadius: BorderRadius.circular(8)),
                                child: InkWell(
                                  onTap: () async {
                                    await Future.delayed(
                                        const Duration(milliseconds: 100));
                                    await locateMe();
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.my_location),
                                      Gap.gap8w,
                                      Text(
                                        "Locate me",
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(color: Colors.black),
                                      ),
                                      // TODO color not present
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 18,
                          left: 17,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: const Icon(
                              Icons.arrow_back_ios_rounded,
                              color: AppColors.n80,
                            ),
                          ),
                        ),
                        if (!loading)
                          Positioned.fill(
                            // top: MediaQuery.of(context).size.height *
                            //     (1 - mapFlexValue / 100) *
                            //     -1.06,
                            top: -20,
                            child: Align(
                              alignment: Alignment.center,
                              child: Image.asset("assets/pngs/map_marker.png"),
                            ),
                          ),
                        if (!loading)
                          Positioned.fill(
                            top: 200,
                            // Add vertical offset for separation
                            child: Align(
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  "Move the pin to place accurately",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            Expanded(
              flex: 100 - mapFlexValue - 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Gap.gap8h,
                      Container(
                        height: 4.h,
                        width: 35.w,
                        decoration: BoxDecoration(
                            color: const Color(0xffD1D1D1),
                            // TODO color not found
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      SizedBox(height: 12.h),
                      if (addressMainLine != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 11,
                              child: Text(
                                addressMainLine!,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: TextButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      constraints: BoxConstraints(
                                        maxHeight: 0.8.sh,
                                        minHeight: 0.8.sh,
                                      ),
                                      builder: (_) {
                                        return PlaceSearch(
                                          fetchPlaceDetails: (val) async {
                                            await fetchPlaceDetails(val ?? "");
                                          },
                                          locateMe: locateMe,
                                        );
                                      });
                                  // if (mapMode == MapModes.confirmedAddressMode) {
                                  //   mapFlexValue = 74;
                                  //   mapMode = MapModes.mapMode;
                                  //   customAddTagTextController.clear();
                                  //   // addressProvider.address.tag = null;
                                  //   setState(() {});
                                  // } else {
                                  // mapMode = MapModes.searchMode;
                                  // setState(() {});
                                  // }
                                },
                                child: FittedBox(
                                  child: Text(
                                    "Change",
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: AppColors.brand),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      // SizedBox(height: 12),
                      if (address != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 11,
                              child: Text(
                                // "${address?.street}, ${address?.subLocality}, ${address?.locality}, ${address?.administrativeArea}, ${address?.country}, ${address?.postalCode}",
                                address!,
                                textAlign: TextAlign.start,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            const Expanded(
                              flex: 3,
                              child: SizedBox(),
                            ),
                          ],
                        ),
                      // if (mapMode ==
                      //     MapModes.confirmedAddressMode) ...[
                      //   SizedBox(height: 24),
                      //   TextFormField(
                      //     autofocus: false,
                      //     maxLines: 1,
                      //     decoration: InputDecoration(
                      //       hintText: "House / Flat / Floor Number",
                      //     ),
                      //     controller: add1TextController,
                      //     focusNode: add1FocusNode,
                      //   ),
                      //   SizedBox(height: 20),
                      //   TextFormField(
                      //     autofocus: false,
                      //     maxLines: 1,
                      //     decoration: InputDecoration(
                      //       hintText: "Apartment / Road / Area",
                      //     ),
                      //     controller: add2TextController,
                      //     focusNode: add2FocusNode,
                      //   ),
                      //   SizedBox(height: 16),
                      //   Align(
                      //       alignment: Alignment.centerLeft,
                      //       child: Text("Save as",
                      //           style: Theme.of(context)
                      //               .textTheme
                      //               .labelMedium)),
                      //
                      // ],
                      // SizedBox(
                      //   width: MediaQuery.of(context).size.width,
                      //   child: ElevatedButton(
                      //     style: Theme.of(context)
                      //         .elevatedButtonTheme
                      //         .style
                      //         ?.copyWith(
                      //       padding: WidgetStateProperty.all(
                      //         EdgeInsets.symmetric(
                      //           horizontal: 16,
                      //           vertical: 17,
                      //         ),
                      //       ),
                      //     ),
                      //     onPressed: !loading && (mapMode == MapModes.mapMode || (add1TextController.text.isNotEmpty && add2TextController.text.isNotEmpty))
                      //         ? () {
                      //       setState(() {
                      //         mapFlexValue = 48;
                      //         mapMode = MapModes.confirmedAddressMode;
                      //       });
                      //       // Navigator.of(context)
                      //       //     .pushNamed(HomeInfoScreen.routeName);
                      //     } : null,
                      //     child: Text(mapMode == MapModes.mapMode ? "Confirm Location" : "Save Address Details"),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
            if (!isKeyboardVisible)
              Expanded(
                flex: 8,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: FloatingActionButton.extended(
                      backgroundColor: AppColors.brand,
                      elevation: 0.0,
                      onPressed: loading == true
                          ? null
                          : () async {
                              setState(() {
                                buttonLoading = true;
                              });

                              Navigator.of(context)
                                  .pushNamed(PersonalDetails.routeName);
                            },
                      label: buttonLoading
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "Confirm Location",
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PlaceSearch extends StatefulWidget {
  // await fetchPlaceDetails(
  // placePredictions![index]["place_id"]);
  final Function(String? placeId) fetchPlaceDetails;
  final VoidCallback locateMe;

  const PlaceSearch({
    super.key,
    required this.fetchPlaceDetails,
    required this.locateMe,
  });

  @override
  State<PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends State<PlaceSearch> {
  TextEditingController placeTextController = TextEditingController();
  List<dynamic>? placePredictions;

  Future<void> placeAutocomplete(String query) async {
    // Response? response = await MapsHttp.fetchUrl("https://maps.googleapis.com/maps/api/place/autocomplete/json", headers: {
    final response = await HttpService().get(
        GlobalState()
            .serverPath('api/v1/geos/locations/suggestion?search_term=$query'),
        headers: {});
    final data = response.data;
    // if (response != null) {
    placePredictions = data;
    // print("^^^^^^^^ ${data}");
    // }
    // else {
    //   print("----------------------");
    //   // TODO fetch failed. handle ui wise
    // }
    setState(() {});
  }

  @override
  void dispose() {
    placeTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
        ),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: CommonBottomSheetSetup(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: 32.h),
            Column(
              children: [
                TextFormField(
                  autofocus: true,
                  controller: placeTextController,
                  maxLines: 1,
                  onChanged: (val) async {
                    // TODO loading in the list of places
                    await placeAutocomplete(val);
                    // TODO loading = false
                  },
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    suffixIcon: placeTextController.text.isNotEmpty
                        ? InkWell(
                            onTap: () {
                              setState(() {
                                placeTextController.text = "";
                                placePredictions?.clear();
                              });
                            },
                            child: Transform.scale(
                              scale: 0.4,
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(
                                      0xffEAEAF1), // TODO color doesn't exist
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.brand,
                                  size: 40,
                                ),
                              ),
                            ),
                          )
                        : null,
                    hintText: "Search for your location",
                  ),
                ),
                // TextFormField(
                //   onChanged: (String val) async {
                //   },
                // ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          setState(() {
                            // isMapMode = true;
                            Navigator.of(context).pop();
                            // mapMode = MapModes.mapMode;
                          });
                          await Future.delayed(
                              const Duration(milliseconds: 100));
                          widget.locateMe();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.my_location),
                              Gap.gap8w,
                              Text(
                                "Current Location",
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            // isMapMode = true;
                            Navigator.of(context).pop();
                            // mapMode = MapModes.mapMode;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.map_outlined),
                              Gap.gap8w,
                              Text(
                                "Locate on Map",
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Gap.gap8h,
            if (placePredictions != null)
              SizedBox(
                width: MediaQuery.of(context).size.width,
                // color: Colors.white,
                child: ListView.separated(
                  separatorBuilder: (BuildContext context, int index) {
                    return const Divider(
                      color: Color(0xffD8D8D8), // TODO color not found
                      // indent:
                      //     MediaQuery.of(context).size.width * 0.17,
                    );
                  },
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: placePredictions!.length,
                  itemBuilder: (BuildContext context, int index) {
                    return InkWell(
                      onTap: () async {
                        placeTextController.clear();
                        // setState(() {
                        // isMapMode = true;
                        // mapMode = MapModes.mapMode;
                        // });
                        final pId = placePredictions?[index]["place_id"];
                        widget.fetchPlaceDetails(pId);
                        placePredictions?.clear();
                        Navigator.of(context).pop();
                      },
                      child: ListTile(
                        leading: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            // color: AppColors.n20,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xff969696),
                            size: 25,
                          ),
                        ),
                        // TODO color not found
                        title: Text(
                          placePredictions![index]["name"],
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        subtitle: Text(
                          placePredictions![index]["description"],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
