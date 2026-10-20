import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:icebreaker/assets/geoloc.dart';
import 'package:logger/logger.dart';  

final _logger = Logger();

class MapDialog extends StatefulWidget {
  final String? initialLocation;
  const MapDialog({super.key, this.initialLocation});

  @override
  MapDialogState createState() => MapDialogState();
}

class MapDialogState extends State<MapDialog> {
  late GoogleMapController _mapController;
  LatLng? _selectedLatLng;
  String _address = "location";
  LatLng _initialPosition = const LatLng(26.306188175031327, -98.17458523021418); // Default position
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
        // Try to geocode the initial location
        List<Location> locations = await locationFromAddress(widget.initialLocation!);
        if (locations.isNotEmpty) {
          final location = LatLng(locations.first.latitude, locations.first.longitude);
          if (mounted) {
            setState(() {
              _selectedLatLng = location;
              _initialPosition = location;
              _isLoading = false;
            });
          }
          _updateAddress(location);
        } else {
          // If geocoding fails, fall back to current location
          await _getCurrentLocation();
        }
      } else {
        // No initial location provided, get current location
        await _getCurrentLocation();
      }
    } catch (e) {
      _logger.e("Error initializing location: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final currentLocation = await GeoLocatorService.getCurrentLatLng();
      if (currentLocation != null) {
        if (mounted) {
          setState(() {
            _selectedLatLng = currentLocation;
            _initialPosition = currentLocation;
            _isLoading = false;
          });
        }
        _updateAddress(currentLocation);
      }
    } catch (e) {
      _logger.e("Error getting current location: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        if (mounted) {
          setState(() {
            _address = "${place.street}, ${place.locality}";
          });
        }
      }
    } catch (e) {
      _logger.e("Error getting address: $e");
    }
  }

  void _onMapTap(LatLng position) async {
    if (mounted) {
      setState(() {
        _selectedLatLng = position;
      });
    }
    await _updateAddress(position);
  }

  void _onConfirmLocation() {
    if (_selectedLatLng != null) {
      Navigator.pop(context, {
        'lat': _selectedLatLng!.latitude,
        'lng': _selectedLatLng!.longitude,
        'address': _address,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _initialPosition,
                        zoom: 14,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (_selectedLatLng != null) {
                          controller.animateCamera(
                            CameraUpdate.newLatLngZoom(_selectedLatLng!, 14),
                          );
                        }
                      },
                      markers: _selectedLatLng != null
                          ? {
                              Marker(
                                markerId: const MarkerId("selected"),
                                position: _selectedLatLng!,
                              ),
                            }
                          : {},
                      onTap: _onMapTap,
                    ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      heroTag: "locationButton",
                      onPressed: () => GeoLocatorService.getCurrentLocation(context, _mapController),
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(_address, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _selectedLatLng != null ? _onConfirmLocation : null,
              
              child: const Text("Confirm Location"),
            ),
          ],
        ),
      ),
    );
  }
} 