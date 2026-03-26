import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../models/group_model.dart';
import '../../services/location_service.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';

class MapScreen extends StatefulWidget {
  final Group? selectedGroup;
  final Map<String, dynamic>? focusLocation; // e.g. {'lat': 27.7, 'lng': 85.3, 'name': 'John'}

  const MapScreen({super.key, this.selectedGroup, this.focusLocation});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _mapReady = false;

  final LocationService _locationService = LocationService();
  final GroupService _groupService = GroupService();
  final AuthService _authService = AuthService();
  StreamSubscription? _locationSubscription;
  final List<Marker> _markers = [];
  List<Map<String, dynamic>> _groupMembers = [];
  
  String _currentLayer = 'Satellite';
  
  final Map<String, String> _layerUrls = {
    'Street': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'Satellite': 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
    'Terrain': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
  };

  @override
  void initState() {
    super.initState();
    _determinePosition();
    if (widget.selectedGroup != null) {
      _listenToGroupLocations();
      _fetchGroupMembers();
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedGroup?.id != oldWidget.selectedGroup?.id) {
      _locationSubscription?.cancel();
      if (widget.selectedGroup != null) {
        _listenToGroupLocations();
        _fetchGroupMembers();
      } else {
        setState(() {
          _markers.clear();
          _groupMembers.clear();
        });
      }
    }

    // Move map if a new focus location is provided
    if (widget.focusLocation != oldWidget.focusLocation && widget.focusLocation != null) {
      final lat = widget.focusLocation!['lat'] as double;
      final lng = widget.focusLocation!['lng'] as double;
      _moveToPosition(lat, lng);
    }
  }

  Future<void> _fetchGroupMembers() async {
    if (widget.selectedGroup == null) return;
    final members = await _groupService.getGroupMembers(widget.selectedGroup!.id);
    if (mounted) {
      setState(() {
        _groupMembers = members;
      });
    }
  }

  void _listenToGroupLocations() {
    _locationSubscription = _locationService
        .streamGroupLocations(widget.selectedGroup!.id)
        .listen((locations) {
      final newMarkers = <Marker>[];
      final currentUserId = _authService.currentUserId;

      for (var loc in locations) {
        final userId = loc['user_id'] as String?;
        // Skip current user because we have a specialized 'You' marker
        if (userId == null || userId == currentUserId) continue;

        final lat = (loc['lat'] as num?)?.toDouble();
        final lng = (loc['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          final member = _groupMembers.firstWhere(
            (m) => m['user_id'] == userId,
            orElse: () => <String, dynamic>{},
          );
          final displayName = member['display_name'] as String? ?? 'User';
          final profileImage = member['profile_image'] as String?;
          final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

          newMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 180,
              height: 70,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.red.shade100,
                          backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                          child: profileImage == null ? Text(
                            initial,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                          ) : null,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 36,
                  ),
                ],
              ),
            ),
          );
        }
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
        _moveToPosition(position.latitude, position.longitude);
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

  Future<void> _locateMe() async {
    setState(() => _isLoadingLocation = true);
    await _determinePosition();
  }

  void _moveToPosition(double lat, double lng) {
    if (_mapReady) {
      _mapController.move(LatLng(lat, lng), 17.0);
    } else {
      // Fallback for when map is not ready yet
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_mapReady) {
          _mapController.move(LatLng(lat, lng), 17.0);
        }
      });
    }
  }

  void _onMapReady() {
    _mapReady = true;
    if (widget.focusLocation != null) {
      final lat = widget.focusLocation!['lat'] as double;
      final lng = widget.focusLocation!['lng'] as double;
      _moveToPosition(lat, lng);
    } else if (_currentPosition != null) {
      _moveToPosition(_currentPosition!.latitude, _currentPosition!.longitude);
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

    final initialCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(27.7172, 85.3240); // Kathmandu as default

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 15.0,
            onMapReady: _onMapReady,
          ),
          children: [
            TileLayer(
              urlTemplate: _layerUrls[_currentLayer]!,
              userAgentPackageName: 'com.subin.theinner_circle',
            ),
            // Current user location marker
            if (_currentPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    width: 180,
                    height: 70,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.red.shade100,
                                backgroundImage: _authService.currentUserProfileImage != null ? NetworkImage(_authService.currentUserProfileImage!) : null,
                                child: _authService.currentUserProfileImage == null ? const Icon(Icons.person, size: 12, color: Colors.red) : null,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'You',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 36,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            // Group member markers
            if (_markers.isNotEmpty) MarkerLayer(markers: _markers),
          ],
        ),
        // Group Display Name & Members Dropdown
        if (widget.selectedGroup != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Theme(
                  // Remove divider lines from ExpansionTile
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: widget.selectedGroup?.avatarUrl != null
                        ? CircleAvatar(
                            radius: 12,
                            backgroundImage: NetworkImage(widget.selectedGroup!.avatarUrl!),
                          )
                        : const Icon(Icons.group, color: Color(0xFF0050A4), size: 24),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.selectedGroup!.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${_groupMembers.length}',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  children: [
                    if (_groupMembers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No members found'),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _groupMembers.length,
                          itemBuilder: (context, index) {
                            final member = _groupMembers[index];
                            final displayName = member['display_name'] as String? ?? 'Unknown';
                            final lastLocation = member['last_location'];
                            final hasLocation = lastLocation != null &&
                                lastLocation is Map &&
                                lastLocation['lat'] != null &&
                                lastLocation['lng'] != null;

                             return ListTile(
                               leading: CircleAvatar(
                                 radius: 18,
                                 backgroundImage: member['profile_image'] != null
                                     ? NetworkImage(member['profile_image'])
                                     : null,
                                 child: member['profile_image'] == null
                                     ? const Icon(Icons.person, color: Colors.grey)
                                     : null,
                               ),
                              title: Text(displayName),
                              subtitle: Text(
                                hasLocation ? 'Location Available' : 'No Location',
                                style: TextStyle(
                                  color: hasLocation ? Colors.green : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.my_location,
                                  color: hasLocation ? const Color(0xFF0050A4) : Colors.grey.shade300,
                                ),
                                onPressed: hasLocation
                                    ? () {
                                        final lat = (lastLocation['lat'] as num).toDouble();
                                        final lng = (lastLocation['lng'] as num).toDouble();
                                        _moveToPosition(lat, lng);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Locating $displayName...'),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                              onTap: hasLocation
                                  ? () {
                                      final lat = (lastLocation['lat'] as num).toDouble();
                                      final lng = (lastLocation['lng'] as num).toDouble();
                                      _moveToPosition(lat, lng);
                                    }
                                  : null,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Layer Selection Button
        Positioned(
          bottom: 100,
          right: 16,
          child: PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  )
                ],
              ),
              child: const Icon(Icons.layers, color: Color(0xFF0050A4), size: 28),
            ),
            onSelected: (String layer) {
              setState(() => _currentLayer = layer);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Street', child: Text('Street Map')),
              const PopupMenuItem(value: 'Satellite', child: Text('Satellite View')),
              const PopupMenuItem(value: 'Terrain', child: Text('Terrain View')),
            ],
          ),
        ),
        // Locate Me Button
        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton(
            onPressed: _locateMe,
            backgroundColor: Colors.white,
            mini: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.my_location,
              color: Color(0xFF0050A4),
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}
