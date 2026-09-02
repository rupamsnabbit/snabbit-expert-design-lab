import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/server_requests/maps_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/error_handler.dart';

class LocationTester extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onFailure;

  const LocationTester({super.key,
    required this.onSuccess,
    required this.onFailure,
  });

  @override
  State<LocationTester> createState() => _LocationTesterState();
}

class _LocationTesterState extends State<LocationTester> {
  String? _address;
  bool _loading = true;
  bool _error = false;
  GeocodingAddress? address;

  late LanguageProvider languageProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }


  @override
  void initState() {
    super.initState();
    _fetchLocationAndAddress();
  }

  Future<void> _fetchLocationAndAddress() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = true;
          _loading = false;
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = true;
            _loading = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = true;
          _loading = false;
        });
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _getAddressFromLatLng(LatLng(position.latitude, position.longitude));
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final url =
          'api/v1/geos/locations/details?lat=${position.latitude}&lng=${position.longitude}&skip_serviceability_check=true';

      final response = await MapsHttp.fetchUrl(url);
      if (response != null && response.statusCode == 200) {
        final data = response.data;
        final addressMap = data['address'];
        if(addressMap != null) {
          address = GeocodingAddress.fromJson(addressMap);

          setState(() {
            // _position = position;
            _address = address?.toJson().values.join(', ');
            _loading = false;
          });
        } else {
          setState(() {
            _error = true;
            _loading = false;
          });
          widget.onFailure();
        }
      } else {
       ErrorHandler.handleResponseError(response: response, context: context, onError: (context, responseError) {
         showSnackbar(context, responseError.errors?.first.message ?? '',);
       },);
       widget.onFailure();
      }
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
      showSnackbar(context, "Something went wrong");
      widget.onFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Card with address
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.symmetric(vertical: 24.h,horizontal: 37.w,),
          // width: 296,
          // height: 132,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(11.r),
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error
                  ? const Center(child: Text('Could not fetch location'))
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          _address ?? '',
                          textAlign: TextAlign.center,
                          style: textTheme.labelMedium?.copyWith(
                            fontSize: 16.sp,
                            color: Color(0xFF4E5969),
                          ),
                        ),
                      ),
                    ),
        ),
        SizedBox(height: 20.h),
        // Buttons row
        Padding(
          padding: EdgeInsets.only(left: 47.w, right: 47.w, top: 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // No Button
              Flexible(
                child: GestureDetector(
                  onTap:!_loading? widget.onFailure : null,
                  child: Container(
                    width: 111.w,
                    height: 32.h,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      child: Text(
                        languageProvider.getMessage('no','No'),
                        style: textTheme.labelMedium?.copyWith(
                          fontSize: 16.sp,
                          letterSpacing: -1,
                          color: Color(0xFF4E5969),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w,),
              // Yes Button
              Flexible(
                child: GestureDetector(
                  onTap: !_loading? widget.onSuccess:null,
                  child: Container(
                    width: 111,
                    height: 32,
                    // padding:
                    //     const EdgeInsets.symmetric(vertical: 6, horizontal: 42),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      child: Text(
                        languageProvider.getMessage('yes','Yes'),
                        style: textTheme.displayMedium?.copyWith(
                          fontSize: 16.sp,
                          letterSpacing: -1,
                          color: AppColors.n0, // White color for the text
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class GeocodingAddress {
  final String? name;
  final String? addressText;
  final String? city;
  final String? state;
  final String? country;
  final String? pinCode;

  GeocodingAddress({
    this.name,
    this.addressText,
    this.city,
    this.state,
    this.country,
    this.pinCode,
  });

  factory GeocodingAddress.fromJson(Map<String, dynamic> json) {
    return GeocodingAddress(
      name: json['name'],
      addressText: json['address_text'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      pinCode: json['pin_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address_text': addressText,
      'city': city,
      'state': state,
      'country': country,
      'pin_code': pinCode,
    };
  }
}