import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/hostel_model.dart';
import '../../utils/app_colors.dart';
import 'hostel_detail_screen.dart';

class HostelMapScreen extends StatefulWidget {
  final List<HostelModel> hostels;

  const HostelMapScreen({super.key, required this.hostels});

  @override
  State<HostelMapScreen> createState() => _HostelMapScreenState();
}

class _HostelMapScreenState extends State<HostelMapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  HostelModel? _selectedHostel;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Get user's current location
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      // Center map on user location
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        13.0,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  // Calculate distance from user to hostel
  String _calculateDistance(HostelModel hostel) {
    if (_currentPosition == null) return '';

    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      hostel.latitude,
      hostel.longitude,
    );

    return '${(distance / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hostels.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Hostel Map"),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(
          child: Text("No hostels to show on map."),
        ),
      );
    }

    final firstHostel = widget.hostels.first;
    final LatLng initialPosition = LatLng(firstHostel.latitude, firstHostel.longitude);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "Hostels Map View",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.list, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back to List',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : initialPosition,
              initialZoom: 13.0,
              onTap: (_, _) {
                setState(() => _selectedHostel = null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.hostel_app',
              ),
              MarkerLayer(
                markers: [
                  // User location marker
                  if (_currentPosition != null)
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Icon(Icons.my_location, color: Colors.green, size: 35),
                        ],
                      ),
                    ),
                  // Hostel markers
                  ...widget.hostels.map((hostel) {
                    final isSelected = _selectedHostel?.name == hostel.name;
                    return Marker(
                      point: LatLng(hostel.latitude, hostel.longitude),
                      width: isSelected ? 120 : 100,
                      height: isSelected ? 120 : 100,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedHostel = hostel);
                          _mapController.move(
                            LatLng(hostel.latitude, hostel.longitude),
                            15.0,
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent : AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                'Rs ${hostel.price}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Icon(
                              hostel.gender == "Boys" ? Icons.boy : Icons.girl,
                              color: isSelected ? AppColors.accent : AppColors.primary,
                              size: isSelected ? 45 : 40,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // My Location Button (Top Right)
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              backgroundColor: Colors.white,
              child: _isLoadingLocation
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
                  : Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          // Selected Hostel Card (Bottom)
          if (_selectedHostel != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedHostel!.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_city,
                                    size: 14,
                                    color: AppColors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedHostel!.city,
                                    style: TextStyle(color: AppColors.grey),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.star, size: 14, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedHostel!.rating.toString(),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (_currentPosition != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.directions_walk,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _calculateDistance(_selectedHostel!),
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs ${_selectedHostel!.price}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                            Text(
                              'per month',
                              style: TextStyle(fontSize: 11, color: AppColors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _selectedHostel = null);
                            },
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Close'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.grey,
                              side: BorderSide(color: AppColors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HostelDetailScreen(hostel: _selectedHostel!),
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('View Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Hostel Count Badge (Top Left)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.home, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.hostels.length} Hostels',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}