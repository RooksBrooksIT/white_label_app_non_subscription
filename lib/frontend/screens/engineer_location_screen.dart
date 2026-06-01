import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/attendance_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart';

class EngineerLocationScreen extends StatefulWidget {
  final String engineerName;

  const EngineerLocationScreen({super.key, required this.engineerName});

  @override
  State<EngineerLocationScreen> createState() => _EngineerLocationScreenState();
}

class _EngineerLocationScreenState extends State<EngineerLocationScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<QuerySnapshot>? _locationSubscription;
  StreamSubscription<Position>? _navPositionSubscription;

  latlong.LatLng? _currentLocation;
  latlong.LatLng? _navDestination;
  List<latlong.LatLng> _routePoints = [];
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  String? _navigatingBookingId;
  bool _isFetchingRoute = false;
  DateTime? _lastRouteFetchAt;
  latlong.LatLng? _lastRouteFetchOrigin;

  String _specialization = 'Engineer';
  bool _isOnline = false;
  bool _autoFollow = true;
  bool _isTogglingStatus = false;

  @override
  void initState() {
    super.initState();
    _listenToLocation();
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
              _specialization = data['Specialization'] ?? 'Engineer';

              if (!_isOnline) {
                _currentLocation = null;
                _autoFollow = false;
                return;
              }

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
    if (_isOnline && _currentLocation != null) {
      _mapController.move(_currentLocation!, 17.0);
      setState(() => _autoFollow = true);
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _navPositionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: ProfessionalTheme.primary(context),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: ProfessionalTheme.background(context),
        body: Stack(
          children: [
            _buildMap(),
            // Status bar background (time/battery area)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).padding.top,
                color: ProfessionalTheme.primary(context),
              ),
            ),
            _buildTopOverlay(),
            _buildNavigationInfoOverlay(),
            _buildAssignedTicketsSheet(),
            _buildFloatingControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final center =
        _currentLocation ??
        const latlong.LatLng(12.9716, 77.5946); // Fallback to Bangalore if null

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
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 5,
                color: ProfessionalTheme.primary(
                  context,
                ).withValues(alpha: 0.7),
              ),
            ],
          ),
        if (_navDestination != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _navDestination!,
                width: 120,
                height: 120,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: ProfessionalTheme.elevatedShadow,
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        'Destination',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.location_pin, color: Colors.red, size: 40),
                  ],
                ),
              ),
            ],
          ),
        if (_isOnline && _currentLocation != null)
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
            border: Border.all(
              color: ProfessionalTheme.primary(context).withValues(alpha: 0.2),
            ),
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
            color: ProfessionalTheme.primary(context).withValues(alpha: 0.15),
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
                    color: ProfessionalTheme.primary(
                      context,
                    ).withValues(alpha: 0.5),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isOnline ? _refreshLocation : null,
                      icon: Icon(Icons.refresh),
                      label: Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ProfessionalTheme.primary(context),
                        foregroundColor: ProfessionalTheme.textInverse(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isTogglingStatus ? null : _toggleOnlineStatus,
                      icon: Icon(_isOnline ? Icons.logout : Icons.check_circle),
                      label: Text(_isOnline ? 'Check Out' : 'Check In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isOnline
                            ? Colors.red
                            : ProfessionalTheme.success,
                        foregroundColor: ProfessionalTheme.textInverse(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Existing status info row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ProfessionalTheme.primaryExtraLight(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.speed,
                      color: ProfessionalTheme.primary(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline ? 'Online' : 'Offline',
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (_isOnline ? ProfessionalTheme.success : Colors.red)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            (_isOnline ? ProfessionalTheme.success : Colors.red)
                                .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        color: _isOnline
                            ? ProfessionalTheme.success
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<DocumentReference<Map<String, dynamic>>?> _getEngineerDocRef() async {
    final tenantId = ThemeService.instance.databaseName;
    final tenantCollection = FirestoreService.instance.collection(
      'EngineerLogin',
      tenantId: tenantId,
    );

    final query = await tenantCollection
        .where('Username', isEqualTo: widget.engineerName)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return tenantCollection.doc(query.docs.first.id);
  }

  Future<void> _updateBackendOnlineStatus(bool isOnline) async {
    final docRef = await _getEngineerDocRef();
    if (docRef == null) {
      throw Exception('Engineer record not found');
    }

    await docRef.update({
      'isOnline': isOnline,
      'isCheckedIn': isOnline,
      'lastStatusUpdate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleOnlineStatus() async {
    setState(() => _isTogglingStatus = true);
    final nextIsOnline = !_isOnline;

    try {
      if (nextIsOnline) {
        await AttendanceService.instance.checkIn(widget.engineerName);
      }

      await _updateBackendOnlineStatus(nextIsOnline);

      if (!mounted) return;
      setState(() {
        _isOnline = nextIsOnline;
        if (!nextIsOnline) {
          _currentLocation = null;
          _autoFollow = false;
        } else {
          _autoFollow = true;
        }
      });

      if (nextIsOnline) {
        await _refreshLocation();
        _showSnackBar('Checked in successfully', ProfessionalTheme.success);
      } else {
        _showSnackBar('Checked out successfully', ProfessionalTheme.error);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Status update failed: $e', ProfessionalTheme.error);
      }
    } finally {
      if (mounted) setState(() => _isTogglingStatus = false);
    }
  }

  // Refresh location and update Firestore fields
  Future<void> _refreshLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final tenantId = ThemeService.instance.databaseName;
      final tenantCollection = FirestoreService.instance.collection(
        'EngineerLogin',
        tenantId: tenantId,
      );
      final query = await tenantCollection
          .where('Username', isEqualTo: widget.engineerName)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        _showSnackBar('Engineer record not found', ProfessionalTheme.error);
        return;
      }
      final docId = query.docs.first.id;
      final now = FieldValue.serverTimestamp();
      // Use the same tenant-namespaced collection for the update (matches query path)
      await tenantCollection.doc(docId).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lastUpdatedTime': now,
        'lastStatusUpdate': now,
        'isLocationEnabled': true,
        'isOnline': _isOnline,
      });
      _showSnackBar('Location refreshed', ProfessionalTheme.success);
    } catch (e) {
      _showSnackBar('Refresh failed: $e', ProfessionalTheme.error);
    }
  }

  // Helper method to display snackbars
  void _showSnackBar(String message, Color backgroundColor) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
            child: Icon(
              _autoFollow ? Icons.my_location : Icons.location_searching,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationInfoOverlay() {
    if (_navigatingBookingId == null) return const SizedBox.shrink();

    final distanceKm = _routeDistanceMeters == null
        ? null
        : (_routeDistanceMeters! / 1000.0);
    final durationMin = _routeDurationSeconds == null
        ? null
        : (_routeDurationSeconds! / 60.0);

    return Positioned(
      left: 16,
      right: 16,
      bottom: 280,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ProfessionalTheme.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ProfessionalTheme.borderLight(context)),
            boxShadow: ProfessionalTheme.elevatedShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ProfessionalTheme.primaryExtraLight(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.navigation_rounded,
                  color: ProfessionalTheme.primary(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Navigation active',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: ProfessionalTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (distanceKm != null)
                          '${distanceKm.toStringAsFixed(1)} km',
                        if (durationMin != null)
                          '${durationMin.round()} min ETA',
                        if (_isFetchingRoute) 'Updating route…',
                      ].join(' • '),
                      style: TextStyle(
                        color: ProfessionalTheme.textSecondary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _stopNavigation,
                style: TextButton.styleFrom(
                  foregroundColor: ProfessionalTheme.error,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: const Text('Stop'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignedTicketsSheet() {
    final stream = FirestoreService.instance
        .collection('Admin_details')
        .where('assignedEmployee', isEqualTo: widget.engineerName)
        .snapshots();

    return DraggableScrollableSheet(
      initialChildSize: 0.22,
      minChildSize: 0.16,
      maxChildSize: 0.58,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: ProfessionalTheme.surface(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sheetHandle(),
                    const SizedBox(height: 12),
                    Text(
                      'Assigned Tickets',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ProfessionalTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ],
                );
              }

              final docs = snapshot.data!.docs;
              final assignedDocs = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final status = (data['engineerStatus'] ?? '')
                    .toString()
                    .toLowerCase();
                return status != 'completed';
              }).toList();

              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                itemCount: assignedDocs.isEmpty ? 1 : (assignedDocs.length + 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetHandle(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Assigned Tickets',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: ProfessionalTheme.textPrimary(context),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: ProfessionalTheme.primaryExtraLight(
                                  context,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: ProfessionalTheme.borderLight(context),
                                ),
                              ),
                              child: Text(
                                '${assignedDocs.length}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: ProfessionalTheme.primary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (assignedDocs.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: ProfessionalTheme.primaryExtraLight(
                                context,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: ProfessionalTheme.borderLight(context),
                              ),
                            ),
                            child: Text(
                              'No assigned tickets right now.',
                              style: TextStyle(
                                color: ProfessionalTheme.textSecondary(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    );
                  }

                  final doc = assignedDocs[index - 1];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildTicketCard(data);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 46,
        height: 5,
        decoration: BoxDecoration(
          color: ProfessionalTheme.borderMedium(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> data) {
    final customerName = (data['customerName'] ?? 'Customer').toString();
    final serviceName =
        (data['deviceBrand'] ??
                data['serviceName'] ??
                data['workName'] ??
                data['deviceType'] ??
                'Service')
            .toString();
    final address = (data['address'] ?? 'Address not available').toString();
    final status = (data['engineerStatus'] ?? data['adminStatus'] ?? 'Assigned')
        .toString();
    final bookingId = (data['bookingId'] ?? '').toString();

    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    final hasDest = lat != null && lng != null;
    final isThisNavigating = _navigatingBookingId == bookingId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ProfessionalTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProfessionalTheme.borderLight(context)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ProfessionalTheme.primaryExtraLight(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  color: ProfessionalTheme.primary(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: ProfessionalTheme.textPrimary(context),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      serviceName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ProfessionalTheme.textSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ProfessionalTheme.primaryExtraLight(context),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: ProfessionalTheme.borderLight(context),
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: ProfessionalTheme.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.place_rounded,
                size: 18,
                color: ProfessionalTheme.textTertiary(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    color: ProfessionalTheme.textSecondary(context),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (!hasDest) ...[
            const SizedBox(height: 10),
            Text(
              'Destination location not available for this ticket.',
              style: TextStyle(
                color: ProfessionalTheme.error,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasDest
                      ? () => _previewDestination(latlong.LatLng(lat, lng))
                      : null,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ProfessionalTheme.primary(context),
                    side: BorderSide(
                      color: ProfessionalTheme.borderLight(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (!_isOnline || !hasDest)
                      ? null
                      : () => _startNavigation(
                          bookingId: bookingId,
                          destination: latlong.LatLng(lat, lng),
                        ),
                  icon: Icon(
                    isThisNavigating
                        ? Icons.navigation_rounded
                        : Icons.directions_rounded,
                  ),
                  label: Text(
                    isThisNavigating ? 'Navigating' : 'Start Navigation',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ProfessionalTheme.primary(context),
                    foregroundColor: ProfessionalTheme.textInverse(context),
                    disabledBackgroundColor: ProfessionalTheme.borderLight(
                      context,
                    ).withValues(alpha: 0.7),
                    disabledForegroundColor: ProfessionalTheme.textSecondary(
                      context,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _previewDestination(latlong.LatLng destination) {
    setState(() {
      _navDestination = destination;
      _autoFollow = false;
    });
    _mapController.move(destination, 15.5);
  }

  Future<void> _startNavigation({
    required String bookingId,
    required latlong.LatLng destination,
  }) async {
    if (!_isOnline) {
      _showSnackBar('Go online to start navigation', ProfessionalTheme.warning);
      return;
    }

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      _showSnackBar(
        'Location permission required for navigation',
        ProfessionalTheme.error,
      );
      return;
    }

    setState(() {
      _navigatingBookingId = bookingId;
      _navDestination = destination;
      _routePoints = [];
      _routeDistanceMeters = null;
      _routeDurationSeconds = null;
      _autoFollow = true;
    });

    await _navPositionSubscription?.cancel();
    _navPositionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 8,
          ),
        ).listen((pos) async {
          final origin = latlong.LatLng(pos.latitude, pos.longitude);
          if (!mounted) return;

          setState(() {
            _currentLocation = origin;
          });

          if (_autoFollow) {
            _mapController.move(origin, _mapController.camera.zoom);
          }

          await _maybeRefreshRoute(origin: origin, destination: destination);
        });

    // immediate route fetch
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
    final origin = latlong.LatLng(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() {
      _currentLocation = origin;
    });
    await _refreshRoute(origin: origin, destination: destination);
  }

  void _stopNavigation() {
    _navPositionSubscription?.cancel();
    _navPositionSubscription = null;
    if (!mounted) return;
    setState(() {
      _navigatingBookingId = null;
      _navDestination = null;
      _routePoints = [];
      _routeDistanceMeters = null;
      _routeDurationSeconds = null;
      _isFetchingRoute = false;
      _lastRouteFetchAt = null;
      _lastRouteFetchOrigin = null;
    });
  }

  Future<void> _maybeRefreshRoute({
    required latlong.LatLng origin,
    required latlong.LatLng destination,
  }) async {
    final now = DateTime.now();
    final lastAt = _lastRouteFetchAt;
    final lastOrigin = _lastRouteFetchOrigin;

    final shouldTimeRefresh =
        lastAt == null || now.difference(lastAt).inSeconds >= 12;

    final movedEnough = lastOrigin == null
        ? true
        : const latlong.Distance().as(
                latlong.LengthUnit.Meter,
                lastOrigin,
                origin,
              ) >=
              25;

    if (shouldTimeRefresh && movedEnough) {
      await _refreshRoute(origin: origin, destination: destination);
    }
  }

  Future<void> _refreshRoute({
    required latlong.LatLng origin,
    required latlong.LatLng destination,
  }) async {
    if (_isFetchingRoute) return;
    setState(() => _isFetchingRoute = true);

    try {
      final route = await _fetchOsrmRoute(
        origin: origin,
        destination: destination,
      );
      if (!mounted) return;
      setState(() {
        _routePoints = route.points;
        _routeDistanceMeters = route.distanceMeters;
        _routeDurationSeconds = route.durationSeconds;
        _lastRouteFetchAt = DateTime.now();
        _lastRouteFetchOrigin = origin;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Route fetch failed: $e', ProfessionalTheme.error);
      }
    } finally {
      if (mounted) setState(() => _isFetchingRoute = false);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return false;
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<_RouteResult> _fetchOsrmRoute({
    required latlong.LatLng origin,
    required latlong.LatLng destination,
  }) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=false';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('OSRM ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = (json['routes'] as List?) ?? [];
    if (routes.isEmpty) {
      throw Exception('No route found');
    }

    final first = routes.first as Map<String, dynamic>;
    final distance = (first['distance'] as num?)?.toDouble() ?? 0;
    final duration = (first['duration'] as num?)?.toDouble() ?? 0;
    final geometry = first['geometry'] as Map<String, dynamic>;
    final coords = (geometry['coordinates'] as List).cast<List>();

    final points = coords
        .map(
          (c) => latlong.LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ),
        )
        .toList();

    return _RouteResult(
      points: points,
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }
}

class _RouteResult {
  final List<latlong.LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const _RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}
