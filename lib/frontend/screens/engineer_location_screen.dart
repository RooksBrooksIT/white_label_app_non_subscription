import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart';

class EngineerLocationScreen extends StatefulWidget {
  final String engineerName;

  const EngineerLocationScreen({
    super.key,
    required this.engineerName,
  });

  @override
  State<EngineerLocationScreen> createState() => _EngineerLocationScreenState();
}

class _EngineerLocationScreenState extends State<EngineerLocationScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<QuerySnapshot>? _locationSubscription;
  
  latlong.LatLng? _currentLocation;
  String _specialization = 'Engineer';
  bool _isOnline = false;
  bool _isCheckedIn = false;
  bool _autoFollow = true;

  @override
  void initState() {
    super.initState();
    _listenToLocation();
  }

  String _sanitizePath(String path) {
    return path.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
  }

  void _listenToLocation() {
    final tenantId = ThemeService.instance.databaseName;
    
    _locationSubscription = FirestoreService.instance
        .collection('EngineerLogin', tenantId: tenantId)
        .where('Username', isEqualTo: widget.engineerName)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      final data = snapshot.docs.first.data();
      
      if (mounted) {
        setState(() {
          _isOnline = data['isOnline'] ?? false;
          _isCheckedIn = data['isCheckedIn'] ?? false;
          _specialization = data['Specialization'] ?? 'Engineer';
          
          if (data['latitude'] != null && data['longitude'] != null) {
            final lat = (data['latitude'] as num).toDouble();
            final lng = (data['longitude'] as num).toDouble();
            final newPos = latlong.LatLng(lat, lng);
            
            // Only move if significantly changed or first time
            if (_currentLocation == null || _currentLocation != newPos) {
              _currentLocation = newPos;
              
              if (_autoFollow) {
                _mapController.move(newPos, _mapController.camera.zoom);
              }
            }
          }
        });
      }
    });
  }

  void _centerOnMe() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 17.0);
      setState(() => _autoFollow = true);
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfessionalTheme.background(context),
      body: Stack(
        children: [
          _buildMap(),
          _buildTopOverlay(),
          _buildFloatingControls(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final center = _currentLocation ?? const latlong.LatLng(12.9716, 77.5946); // Fallback to Bangalore if null

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 17.0,
        onPositionChanged: (pos, hasGesture) {
          if (hasGesture && _autoFollow) {
            setState(() => _autoFollow = false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rooks.charity_app',
        ),
        if (_currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLocation!,
                width: 120,
                height: 120,
                child: _buildAnimatedMarker(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAnimatedMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ProfessionalTheme.surface(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: ProfessionalTheme.elevatedShadow,
            border: Border.all(color: ProfessionalTheme.primary(context).withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isOnline ? Icons.circle : Icons.circle_outlined,
                size: 10,
                color: _isOnline ? ProfessionalTheme.success : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                widget.engineerName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ProfessionalTheme.primary(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ProfessionalTheme.primary(context).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: ProfessionalTheme.primary(context),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: ProfessionalTheme.primary(context).withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: ProfessionalTheme.cardDecoration(context),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ProfessionalTheme.primaryExtraLight(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.speed, color: ProfessionalTheme.primary(context)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCheckedIn ? 'Checked In' : 'Not Checked In',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: ProfessionalTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _specialization,
                      style: TextStyle(
                        color: ProfessionalTheme.textSecondary(context),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isOnline)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ProfessionalTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ProfessionalTheme.success.withOpacity(0.2)),
                  ),
                  child: Text(
                    'ON',
                    style: TextStyle(
                      color: ProfessionalTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Positioned(
      bottom: 24,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: 'center_map',
            onPressed: _centerOnMe,
            backgroundColor: _autoFollow 
                ? ProfessionalTheme.primary(context) 
                : ProfessionalTheme.surface(context),
            foregroundColor: _autoFollow 
                ? ProfessionalTheme.textInverse(context) 
                : ProfessionalTheme.primary(context),
            elevation: 4,
            child: Icon(_autoFollow ? Icons.my_location : Icons.location_searching),
          ),
        ],
      ),
    );
  }
}
