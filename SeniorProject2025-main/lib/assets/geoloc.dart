import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeoLocatorService {
  static const double defaultZoom = 16.0;
  static const double maxZoom = 20.0;
  static const double minZoom = 3.0;

  static Future<void> getCurrentLocation(BuildContext context, GoogleMapController? mapController) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!context.mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable location services in your device settings.'),
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openLocationSettings,
            ),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!context.mounted) return;
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Location permissions are required to show your location on the map'),
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!context.mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in your device settings.'),
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
        return;
      }

      // When permissions are granted, get the position of the device
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );
      
      if (!context.mounted) return;
      
      // Get current zoom level if possible
      double currentZoom = await mapController?.getZoomLevel() ?? defaultZoom;
      
      // Ensure zoom level is within bounds
      currentZoom = currentZoom.clamp(minZoom, maxZoom);
      
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          currentZoom,
        ),
      );
      
    } catch (e) {
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString()}'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  static void openLocationSettings() {
    Geolocator.openLocationSettings();
  }

  static void openAppSettings() {
    Geolocator.openAppSettings();
  }

  static Future<LatLng?> getCurrentLatLng() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );
      
      return LatLng(position.latitude, position.longitude);
      
    } catch (e) {
      return null;
    }
  }
}
