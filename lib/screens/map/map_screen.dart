import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/group_model.dart';
import '../../services/location_service.dart';

class MapScreen extends StatefulWidget {
  final Group? selectedGroup;

  const MapScreen({super.key, this.selectedGroup});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoadingLocation = true;

  final LocationService _locationService = LocationService();
  StreamSubscription? _locationSubscription;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _determinePosition();
    if (widget.selectedGroup != null) {
      _listenToGroupLocations();
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedGroup?.id != oldWidget.selectedGroup?.id) {
      _locationSubscription?.cancel();
      if (widget.selectedGroup != null) {
        _listenToGroupLocations();
      } else {
        setState(() {
          _markers.clear();
        });
      }
    }
  }

  void _listenToGroupLocations() {
    _locationSubscription = _locationService
        .streamGroupLocations(widget.selectedGroup!.id)
        .listen((locations) {
          final newMarkers = <Marker>{};
          for (var loc in locations) {
            newMarkers.add(
              Marker(
                markerId: MarkerId(loc['user_id']),
                position: LatLng(loc['lat'], loc['lng']),
                infoWindow: InfoWindow(
                  title: 'Member',
                  snippet:
                      'Last updated: ${DateTime.parse(loc['timestamp']).toLocal()}',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
              ),
            );
          }
          if (mounted) {
            setState(() {
              _markers.clear();
              _markers.addAll(newMarkers);
            });
          }
        });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        setState(() => _isLoadingLocation = false);
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          setState(() => _isLoadingLocation = false);
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
        setState(() => _isLoadingLocation = false);
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15.0,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint("Error getting location: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get your location: $e')),
        );
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Getting current location...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (widget.selectedGroup != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.blue.shade50,
            width: double.infinity,
            child: Text(
              'Viewing Group: ${widget.selectedGroup!.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: _currentPosition != null
                ? CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 15.0,
                  )
                : const CameraPosition(target: LatLng(0, 0), zoom: 2.0),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            markers: _markers,
          ),
        ),
      ],
    );
  }
}
