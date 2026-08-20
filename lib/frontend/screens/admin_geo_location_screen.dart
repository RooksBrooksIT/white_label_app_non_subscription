import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminGeoLocationScreen extends StatefulWidget {
  final String engineerId;
  final String engineerName;
  final String? bookingDocId;
  final double? customerLat;
  final double? customerLng;
  final String? customerAddress;
  final String? bookingId;
  final String? customerName;
  final String? jobType;
  final String? deviceType;
  final String? deviceBrand;
  final String? assignedEmployee;
  final String? customerStatus;

  const AdminGeoLocationScreen({
    super.key,
    required this.engineerId,
    required this.engineerName,
    this.bookingDocId,
    this.customerLat,
    this.customerLng,
    this.customerAddress,
    this.bookingId,
    this.customerName,
    this.jobType,
    this.deviceType,
    this.deviceBrand,
    this.assignedEmployee,
    this.customerStatus,
  });

  @override
  State<AdminGeoLocationScreen> createState() => _AdminGeoLocationScreenState();
}

class _AdminGeoLocationScreenState extends State<AdminGeoLocationScreen> {
  // State variables
  latlong.LatLng? _lastLocation;
  bool _isOnline = false;
  DateTime? _lastUpdateTime;
  bool _autoFollow = true;
  String? _assignedEmployeeName;
  String? _currentTicketStatus;

  // Customer location variables
  latlong.LatLng? _customerLocation;
  String? _customerAddress;
  bool _isGeocoding = false;

  StreamSubscription<firestore.QuerySnapshot<Map<String, dynamic>>>?
  _engineerFirestoreSubscription;
  StreamSubscription<firestore.QuerySnapshot<Map<String, dynamic>>>?
  _engineersListSubscription;
  StreamSubscription<firestore.QuerySnapshot<Map<String, dynamic>>>?
  _adminSubscription;
  StreamSubscription<firestore.QuerySnapshot<Map<String, dynamic>>>?
  _updatesSubscription;
  final MapController _mapController = MapController();
  final List<latlong.LatLng> _pathHistory = [];
  final List<Map<String, dynamic>> _jobUpdatePoints = [];
  String? _currentTrackingId;
  String? _currentTrackingName;

  // New variable to store engineers list
  List<Map<String, dynamic>> _engineersList = [];
  bool _isLoadingEngineers = false;

  // Sliding Directory Drawer State
  bool _isDrawerExpanded = true;
  String _activeTabFilter = 'ALL'; // 'ALL', 'ONLINE', 'TRACKING'
  String _drawerSearchQuery = '';

  // All engineers' real-time data
  final Map<String, Map<String, dynamic>> _allEngineersData = {};
  final Map<
    String,
    StreamSubscription<firestore.QuerySnapshot<Map<String, dynamic>>>
  >
  _allEngineerSubscriptions = {};

  // Flag to track if we've done the initial map fit
  bool _hasDoneInitialFit = false;

  String _sanitizePath(String path) {
    return path.replaceAll(RegExp(r'[.#$\[\]]'), '_');
  }

  @override
  void initState() {
    super.initState();
    // Listen for ThemeService changes
    ThemeService.instance.addListener(_onThemeChanged);
    _currentTrackingId = widget.engineerId;
    _currentTrackingName = widget.engineerName;
    _customerAddress = widget.customerAddress;

    // If in customer location mode, disable auto-follow for engineer
    final isCustomerLocationMode =
        widget.customerAddress != null ||
        (widget.customerLat != null && widget.customerLng != null);
    if (isCustomerLocationMode) {
      _autoFollow = false;
    }

    _initializeCustomerLocation();
    _checkAuthAndListen();
    _startListeningToEngineersList();
  }

  Future<void> _initializeCustomerLocation() async {
    if (widget.customerLat != null && widget.customerLng != null) {
      setState(() {
        _customerLocation = latlong.LatLng(
          widget.customerLat!,
          widget.customerLng!,
        );
      });
      // Center map on customer location
      Future.delayed(Duration.zero, () {
        if (_customerLocation != null && mounted) {
          _mapController.move(_customerLocation!, 16.5);
        }
      });
    } else if (widget.customerAddress != null &&
        widget.customerAddress!.isNotEmpty) {
      await _geocodeAddress();
    }
  }

  Future<void> _geocodeAddress() async {
    if (_customerAddress == null || _customerAddress!.isEmpty) return;

    setState(() {
      _isGeocoding = true;
    });

    try {
      List<Location> locations = [];

      // Attempt 1: Full raw address
      try {
        locations = await locationFromAddress(_customerAddress!);
      } catch (_) {}

      // Attempt 2: Strip door number prefix (e.g. "79e7, ", "79/7, ", "Door 12, ")
      if (locations.isEmpty) {
        final cleaned = _customerAddress!.replaceAll(RegExp(r'^\s*[\w\d/-]+[\s,]+'), '').trim();
        if (cleaned.isNotEmpty) {
          try {
            locations = await locationFromAddress(cleaned);
          } catch (_) {}
        }
      }

      // Attempt 3: Progressive fallback by dropping initial comma-separated parts
      if (locations.isEmpty) {
        final parts = _customerAddress!.split(',');
        for (int i = 1; i < parts.length; i++) {
          final subAddress = parts.sublist(i).join(',').trim();
          if (subAddress.isNotEmpty) {
            try {
              locations = await locationFromAddress(subAddress);
              if (locations.isNotEmpty) break;
            } catch (_) {}
          }
        }
      }

      if (locations.isNotEmpty) {
        setState(() {
          _customerLocation = latlong.LatLng(
            locations.first.latitude,
            locations.first.longitude,
          );
        });
        // Center map on customer location after geocoding
        Future.delayed(Duration.zero, () {
          if (_customerLocation != null && mounted) {
            _mapController.move(_customerLocation!, 16.5);
          }
        });
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  // Function to listen to engineers list from Firestore in real-time
  void _startListeningToEngineersList() {
    if (mounted) {
      setState(() {
        _isLoadingEngineers = true;
      });
    }

    final query = FirestoreService.instance
        .collection('EngineerLogin')
        .where('Username', isNotEqualTo: null);

    _engineersListSubscription = query.snapshots().listen(
      (snapshot) {
        final engineers = <Map<String, dynamic>>[];

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final username = data['Username']?.toString();

          if (username != null && username.isNotEmpty) {
            // Extract status fields
            final bool isOnline = data['isOnline'] ?? false;
            final bool isCheckedIn = data['isCheckedIn'] ?? false;
            final bool isLocationEnabled = data['isLocationEnabled'] ?? false;
            final bool engineerIsOnline =
                isOnline && isCheckedIn && isLocationEnabled;

            final engineerData = {
              'id': username,
              'username': username,
              'data': data,
              'isOnline': engineerIsOnline,
              'specialization': data['Specialization']?.toString(),
              'employeeId': data['EmployeeID']?.toString(),
            };

            engineers.add(engineerData);

            // Start listening to this engineer's real-time data
            _listenToSingleEngineer(username);
          }
        }

        // Remove duplicates based on username
        final uniqueEngineers = <Map<String, dynamic>>[];
        final seenUsernames = <String>{};

        for (final engineer in engineers) {
          final username = engineer['username'] as String;
          if (!seenUsernames.contains(username)) {
            seenUsernames.add(username);
            uniqueEngineers.add(engineer);
          }
        }

        if (mounted) {
          setState(() {
            _engineersList = uniqueEngineers;
            _isLoadingEngineers = false;
          });
        }

        debugPrint('Loaded ${_engineersList.length} engineers');
      },
      onError: (e) {
        debugPrint('Error listening to engineers list: $e');
        if (mounted) {
          setState(() {
            _isLoadingEngineers = false;
          });
        }
      },
    );
  }

  // Listen to a single engineer's real-time data
  void _listenToSingleEngineer(String username) {
    debugPrint('Starting to listen to engineer: $username');
    // Cancel existing subscription if any
    _allEngineerSubscriptions[username]?.cancel();

    final query = FirestoreService.instance
        .collection('EngineerLogin')
        .where('Username', isEqualTo: username)
        .limit(1);

    _allEngineerSubscriptions[username] = query.snapshots().listen(
      (snapshot) {
        debugPrint(
          'Received snapshot for engineer $username: ${snapshot.docs.length} docs',
        );
        if (snapshot.docs.isEmpty) return;
        final data = snapshot.docs.first.data();
        final bool isOnlineVal = data['isOnline'] ?? false;
        final bool isCheckedInVal = data['isCheckedIn'] ?? false;
        final bool isLocationEnabledVal = data['isLocationEnabled'] ?? false;
        final bool engineerIsOnline =
            isOnlineVal && isCheckedInVal && isLocationEnabledVal;

        // Get location
        latlong.LatLng? location;
        final dynamic latVal = data['latitude'];
        final dynamic lngVal = data['longitude'];
        if (latVal != null && lngVal != null) {
          location = latlong.LatLng(
            (latVal as num).toDouble(),
            (lngVal as num).toDouble(),
          );
        }
        debugPrint('Engineer $username location: $location');

        // Get last updated time
        DateTime? lastUpdatedTime;
        final lastUpdatedTimeVal = data['lastUpdatedTime'];
        if (lastUpdatedTimeVal is firestore.Timestamp) {
          lastUpdatedTime = lastUpdatedTimeVal.toDate();
        } else if (lastUpdatedTimeVal is String) {
          lastUpdatedTime = DateTime.tryParse(lastUpdatedTimeVal);
        }

        if (mounted) {
          setState(() {
            _allEngineersData[username] = {
              'username': username,
              'isOnline': engineerIsOnline,
              'location': location,
              'lastUpdatedTime': lastUpdatedTime,
              'data': data,
            };
          });
          debugPrint(
            'Updated _allEngineersData for $username: ${_allEngineersData[username]}',
          );
          debugPrint(
            'Total engineers in _allEngineersData: ${_allEngineersData.length}',
          );
        }

        // Auto-fit map if we have valid engineer locations and haven't fitted yet AND we're not in customer location mode
        final isCustomerMode = _customerLocation != null;
        final validLocations = _allEngineersData.values
            .where((data) => data['location'] != null)
            .toList();
        debugPrint(
          'Valid locations count: ${validLocations.length}, isCustomerMode: $isCustomerMode, _hasDoneInitialFit: $_hasDoneInitialFit',
        );
        if (!_hasDoneInitialFit &&
            validLocations.isNotEmpty &&
            !isCustomerMode) {
          debugPrint('Fitting map to all engineers');
          _fitMapToAllEngineers();
          _hasDoneInitialFit = true;
        }
      },
      onError: (e) {
        debugPrint('Error listening to engineer $username: $e');
      },
    );
  }

  // Fit map to include all engineers
  void _fitMapToAllEngineers() {
    final validLocations = _allEngineersData.values
        .where((data) => data['location'] != null)
        .map((data) => data['location'] as latlong.LatLng)
        .toList();

    if (validLocations.isEmpty) return;

    double minLat = validLocations.first.latitude;
    double maxLat = validLocations.first.latitude;
    double minLng = validLocations.first.longitude;
    double maxLng = validLocations.first.longitude;

    for (final loc in validLocations) {
      if (loc.latitude < minLat) minLat = loc.latitude;
      if (loc.latitude > maxLat) maxLat = loc.latitude;
      if (loc.longitude < minLng) minLng = loc.longitude;
      if (loc.longitude > maxLng) maxLng = loc.longitude;
    }

    // Add padding
    const padding = 0.005;
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    // Move map
    Future.delayed(Duration.zero, () {
      if (mounted) {
        final centerLat = (minLat + maxLat) / 2;
        final centerLng = (minLng + maxLng) / 2;
        _mapController.move(latlong.LatLng(centerLat, centerLng), 14);
      }
    });
  }

  // Function to load engineers from Firestore (for manual refresh)
  Future<void> _loadEngineersList() async {
    _startListeningToEngineersList();
  }

  Future<void> _checkAuthAndListen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint(
          'AdminGeoLocationScreen: No session. Attempting Anonymous Auth...',
        );
        final cred = await FirebaseAuth.instance.signInAnonymously();
        debugPrint(
          'AdminGeoLocationScreen: Anonymous Auth successful. UID: ${cred.user?.uid}',
        );
      } else {
        debugPrint(
          'AdminGeoLocationScreen: Already authenticated as ${user.uid}',
        );
      }
    } catch (e) {
      debugPrint('AdminGeoLocationScreen: Anonymous Auth FATAL ERROR: $e');
      debugPrint(
        'Please check if "Anonymous" sign-in provider is enabled in Firebase Console.',
      );
    }
    _listenForUpdates();
  }

  void _listenForUpdates() {
    _engineerFirestoreSubscription?.cancel();
    _adminSubscription?.cancel();

    if (_currentTrackingId != null && _currentTrackingId!.isNotEmpty) {
      _listenToEngineerLocation();
    }
    _listenToAdminDetails();
    _listenToBookingUpdates();
  }

  void _switchEngineer(String id, String name) {
    if (mounted) {
      setState(() {
        _currentTrackingId = id;
        _currentTrackingName = name;
        _lastLocation = null;
        _pathHistory.clear();
        _jobUpdatePoints.clear();
        _isOnline = false;
        _lastUpdateTime = null;
        _assignedEmployeeName = null;
        _currentTicketStatus = null;
        _autoFollow = true;
      });
      _listenForUpdates();

      // Show snackbar feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Now tracking: $name'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _listenToAdminDetails() {
    _adminSubscription?.cancel();

    firestore.Query<Map<String, dynamic>> query;

    if (widget.bookingDocId != null && widget.bookingDocId!.isNotEmpty) {
      // If we have a specific booking, prioritize listening to it
      query = FirestoreService.instance
          .collection('Admin_ticket_entry')
          .where(
            firestore.FieldPath.documentId,
            isEqualTo: widget.bookingDocId,
          );
    } else if (_currentTrackingId != null && _currentTrackingId!.isNotEmpty) {
      // Otherwise, track the latest record for the selected engineer
      query = FirestoreService.instance
          .collection('Admin_ticket_entry')
          .where('assignedEmployee', isEqualTo: _currentTrackingId)
          .orderBy('timestamp', descending: true)
          .limit(1);
    } else {
      return;
    }

    _adminSubscription = query.snapshots().listen(
      (snapshot) {
        if (snapshot.docs.isEmpty) {
          debugPrint(
            'AdminGeoLocationScreen: No Admin_ticket_entry found for tracking',
          );
          return;
        }

        final data = snapshot.docs.first.data();
        final String? assignedEmployee = data['assignedEmployee']?.toString();
        final String? adminStatus = data['adminStatus']?.toString();

        if (mounted) {
          // If the assigned employee changes in the booking document, update tracking
          if (assignedEmployee != null &&
              assignedEmployee.isNotEmpty &&
              assignedEmployee != _currentTrackingId) {
            debugPrint(
              'AdminGeoLocationScreen: assignedEmployee changed from $_currentTrackingId to $assignedEmployee',
            );
            setState(() {
              _currentTrackingId = assignedEmployee;
              _currentTrackingName = assignedEmployee;
              _lastLocation = null;
              _pathHistory.clear();
              _isOnline = false;
              _lastUpdateTime = null;
            });

            // Restart the engineer location listener
            _listenToEngineerLocation();

            // Notify user of the change
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-switched tracking to: $assignedEmployee'),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          setState(() {
            _assignedEmployeeName = assignedEmployee;
            _currentTicketStatus = adminStatus;
          });
        }
      },
      onError: (error) {
        debugPrint(
          'AdminGeoLocationScreen: Error listening to Admin_details: $error',
        );
      },
    );
  }

  void _listenToEngineerLocation() {
    _engineerFirestoreSubscription?.cancel();
    if (_currentTrackingId == null || _currentTrackingId!.isEmpty) return;

    // Query EngineerLogin collection for the selected engineer
    final query = FirestoreService.instance
        .collection('EngineerLogin')
        .where('Username', isEqualTo: _currentTrackingId)
        .limit(1);

    _engineerFirestoreSubscription = query.snapshots().listen(
      (snapshot) {
        if (snapshot.docs.isEmpty) {
          debugPrint('No engineer data found for $_currentTrackingId');
          return;
        }

        final data = snapshot.docs.first.data();
        debugPrint('Received engineer data: $data');

        if (mounted) {
          setState(() {
            // Determine online status
            final bool isOnline = data['isOnline'] ?? false;
            final bool isCheckedIn = data['isCheckedIn'] ?? false;
            final bool isLocationEnabled = data['isLocationEnabled'] ?? false;
            _isOnline = isOnline && isCheckedIn && isLocationEnabled;

            // Handle location
            final dynamic latVal = data['latitude'];
            final dynamic lngVal = data['longitude'];
            if (latVal != null && lngVal != null) {
              final double lat = (latVal as num).toDouble();
              final double lng = (lngVal as num).toDouble();
              final newPos = latlong.LatLng(lat, lng);

              // Check if position changed
              if (_lastLocation == null || _lastLocation != newPos) {
                _lastLocation = newPos;
                _pathHistory.add(newPos);
                if (_pathHistory.length > 200) _pathHistory.removeAt(0);

                // Auto-follow logic
                final isCustomerMode = _customerLocation != null;
                if (_autoFollow && !isCustomerMode) {
                  _mapController.move(newPos, _mapController.camera.zoom);
                }
              }
            }

            // Update last update time
            final lastUpdatedTime = data['lastUpdatedTime'];
            if (lastUpdatedTime is firestore.Timestamp) {
              _lastUpdateTime = lastUpdatedTime.toDate();
            } else if (lastUpdatedTime is String) {
              _lastUpdateTime = DateTime.tryParse(lastUpdatedTime);
            }
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to engineer location: $error');
      },
    );
  }

  void _listenToBookingUpdates() {
    _updatesSubscription?.cancel();
    if (_currentTrackingId == null || _currentTrackingId!.isEmpty) return;

    // Build the query:
    // If we have a booking ID, we might want updates specifically for that booking.
    // However, the user wants to "track my engineer", so we'll look for all updates by this engineer
    // to build a better path history.
    firestore.Query<Map<String, dynamic>> query = FirestoreService.instance
        .collection('Engineer_updates')
        .where('updatedBy', isEqualTo: _currentTrackingId)
        .orderBy('updatedAt', descending: true)
        .limit(20); // Get last 20 captured points for history

    _updatesSubscription = query.snapshots().listen(
      (snapshot) {
        if (snapshot.docs.isEmpty) return;

        // Collect all valid points from the history
        final List<latlong.LatLng> historicalCoords = [];
        final List<Map<String, dynamic>> updateDetails = [];
        firestore.Timestamp? latestTimestamp;
        latlong.LatLng? latestPos;

        for (final doc in snapshot.docs.reversed) {
          final data = doc.data();
          final dynamic latVal = data['lat'];
          final dynamic lngVal = data['lng'];
          final dynamic timestamp = data['updatedAt'];
          final String? status = data['engineerStatus']?.toString();

          if (latVal != null && lngVal != null) {
            final double lat = (latVal as num).toDouble();
            final double lng = (lngVal as num).toDouble();
            final pos = latlong.LatLng(lat, lng);
            historicalCoords.add(pos);
            updateDetails.add({
              'pos': pos,
              'status': status ?? 'Update',
              'time': timestamp is firestore.Timestamp
                  ? timestamp.toDate()
                  : null,
            });

            if (timestamp is firestore.Timestamp) {
              if (latestTimestamp == null ||
                  timestamp.toDate().isAfter(latestTimestamp.toDate())) {
                latestTimestamp = timestamp;
                latestPos = pos;
              }
            }
          }
        }

        if (mounted && historicalCoords.isNotEmpty) {
          setState(() {
            // Merge historical Firestore points into path history
            for (final point in historicalCoords) {
              if (!_pathHistory.contains(point)) {
                _pathHistory.add(point);
              }
            }
            if (_pathHistory.length > 300) {
              _pathHistory.removeRange(0, _pathHistory.length - 300);
            }

            // Update specific job update points
            _jobUpdatePoints.clear();
            _jobUpdatePoints.addAll(updateDetails);

            // If the latest Firestore update is newer than what we Have from RTDB, update position
            final bool isNewer =
                _lastUpdateTime == null ||
                (latestTimestamp != null &&
                    latestTimestamp.toDate().isAfter(_lastUpdateTime!));

            if (isNewer && latestPos != null) {
              _lastLocation = latestPos;

              if (_autoFollow) {
                _mapController.move(latestPos, _mapController.camera.zoom);
              }
              _lastUpdateTime = latestTimestamp?.toDate() ?? DateTime.now();
            }
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to Engineer_updates: $error');
      },
    );
  }

  void _centerOnEngineer() {
    if (_lastLocation != null) {
      _mapController.move(_lastLocation!, 16.5);
      setState(() => _autoFollow = true);
    }
  }

  void _zoomIn() => _mapController.move(
    _mapController.camera.center,
    _mapController.camera.zoom + 1,
  );
  void _zoomOut() => _mapController.move(
    _mapController.camera.center,
    _mapController.camera.zoom - 1,
  );

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    _engineerFirestoreSubscription?.cancel();
    _engineersListSubscription?.cancel();
    _adminSubscription?.cancel();
    _updatesSubscription?.cancel();
    // Cancel all engineer subscriptions
    for (final subscription in _allEngineerSubscriptions.values) {
      subscription.cancel();
    }
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEngineerSelected =
        _currentTrackingId != null && _currentTrackingId!.isNotEmpty;
    final bool isCustomerLocationMode =
        widget.customerAddress != null ||
        (widget.customerLat != null && widget.customerLng != null);
    final primaryColor = ThemeService.instance.primaryColor;
    final isDark = ThemeService.instance.isDarkMode;

    // Full screen Customer Location view without background map
    if (isCustomerLocationMode) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Customer Location Workspace',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          backgroundColor: primaryColor,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: _buildCustomerLocationWorkspaceCard(primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFF1F5F9),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          isEngineerSelected
              ? "Tracking: $_currentTrackingName"
              : "Live Geo Tracking",
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFF1F5F9),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A), size: 18),
                onPressed: _loadEngineersList,
                tooltip: 'Refresh engineers list',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 6, bottom: 6),
            child: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: IconButton(
                    icon: Icon(Icons.person_pin_circle_rounded, color: primaryColor, size: 20),
                    onPressed: _showEngineerSelectionSheet,
                    tooltip: 'Select Engineer',
                  ),
                ),
                if (_engineersList.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        _engineersList.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          _buildTopHeaderSegmentedBar(primaryColor),
          _buildFloatingControls(),
          _buildSlidingDirectoryDrawer(primaryColor),
        ],
      ),
    );
  }

  Widget _buildTopHeaderSegmentedBar(Color primaryColor) {
    final onlineCount = _engineersList.where((e) => e['isOnline'] == true).length;
    return Positioned(
      top: 14,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Floating Top Segmented Bar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildTabSegmentPill('ALL', _activeTabFilter == 'ALL', primaryColor),
                _buildTabSegmentPill('ONLINE', _activeTabFilter == 'ONLINE', const Color(0xFF10B981)),
                _buildTabSegmentPill('TRACKING', _activeTabFilter == 'TRACKING', const Color(0xFF6366F1)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Floating "CHECK IN" / "FOCUS" Pill Button (Reference Style)
          GestureDetector(
            onTap: _centerOnEngineer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gps_fixed_rounded, size: 14, color: primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'FOCUS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E293B),
                      letterSpacing: 1.1,
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

  Widget _buildTabSegmentPill(String label, bool isSelected, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTabFilter = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingDirectoryDrawer(Color primaryColor) {
    final filteredList = _engineersList.where((eng) {
      final name = (eng['username'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_drawerSearchQuery.toLowerCase());
      final isOnline = eng['isOnline'] ?? false;

      if (_activeTabFilter == 'ONLINE') return matchesSearch && isOnline;
      if (_activeTabFilter == 'TRACKING') return matchesSearch && (eng['username'] == _currentTrackingId);
      return matchesSearch;
    }).toList();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 320),
      curve: Curves.fastOutSlowIn,
      bottom: 0,
      left: 0,
      right: 0,
      height: _isDrawerExpanded ? 340 : 65,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Floating Center Handle Downward / Upward Arrow Button
            GestureDetector(
              onTap: () {
                setState(() => _isDrawerExpanded = !_isDrawerExpanded);
              },
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isDrawerExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                  color: const Color(0xFF0F172A),
                  size: 24,
                ),
              ),
            ),

            if (_isDrawerExpanded) ...[
              // Directory Header & Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _drawerSearchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Search field engineer by name...',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Engineer Directory List
              Expanded(
                child: filteredList.isEmpty
                    ? const Center(
                        child: Text(
                          'No engineers available in this filter',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredList.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          thickness: 0.8,
                          color: Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (context, index) {
                          final eng = filteredList[index];
                          final username = (eng['username'] ?? 'Staff').toString();
                          final isOnline = eng['isOnline'] ?? false;
                          final isSelected = username == _currentTrackingId;

                          return InkWell(
                            onTap: () {
                              _switchEngineer(username, username);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor.withValues(alpha: 0.06)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  // Avatar with status ring
                                  Stack(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isSelected ? primaryColor : const Color(0xFF1E293B),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            username.isNotEmpty ? username[0].toUpperCase() : 'E',
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isOnline)
                                        Positioned(
                                          right: 1,
                                          bottom: 1,
                                          child: Container(
                                            width: 11,
                                            height: 11,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          username.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isOnline ? 'Online • Field Active' : 'Offline • Last Location Saved',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: isOnline ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        isOnline ? 'Active' : 'Offline',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                        color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerLocationWorkspaceCard(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Customer Profile Avatar
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.location_on_rounded,
                      color: primaryColor,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.customerName != null && widget.customerName!.isNotEmpty
                      ? widget.customerName!
                      : "Customer Location Details",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.bookingId != null && widget.bookingId!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Booking ID: #${widget.bookingId}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 16),

          // 2-Column Grid Alignment details
          _buildDetailRow("Service Type", widget.jobType, const Color(0xFF64748B), const Color(0xFF0F172A)),
          const Divider(color: Color(0xFFF1F5F9), height: 16),
          _buildDetailRow("Device Type", widget.deviceType, const Color(0xFF64748B), const Color(0xFF0F172A)),
          const Divider(color: Color(0xFFF1F5F9), height: 16),
          _buildDetailRow("Device Brand", widget.deviceBrand, const Color(0xFF64748B), const Color(0xFF0F172A)),
          const Divider(color: Color(0xFFF1F5F9), height: 16),
          _buildDetailRow("Assigned Engineer", widget.assignedEmployee, const Color(0xFF64748B), const Color(0xFF0F172A)),
          if (widget.customerStatus != null && widget.customerStatus!.isNotEmpty) ...[
            const Divider(color: Color(0xFFF1F5F9), height: 16),
            _buildDetailRow("Status", widget.customerStatus, const Color(0xFF64748B), primaryColor, isHighlight: true),
          ],

          const SizedBox(height: 16),

          // Address Container Box
          if (widget.customerAddress != null && widget.customerAddress!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place_rounded, size: 16, color: primaryColor),
                      const SizedBox(width: 6),
                      const Text(
                        "FULL CUSTOMER ADDRESS",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.customerAddress!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Open & Pin in Google Maps Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final Uri googleMapsUrl;
                if (widget.customerLat != null && widget.customerLng != null) {
                  googleMapsUrl = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${widget.customerLat},${widget.customerLng}',
                  );
                } else if (_customerLocation != null) {
                  googleMapsUrl = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${_customerLocation!.latitude},${_customerLocation!.longitude}',
                  );
                } else if (widget.customerAddress != null && widget.customerAddress!.isNotEmpty) {
                  googleMapsUrl = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.customerAddress!)}',
                  );
                } else {
                  return;
                }

                if (await canLaunchUrl(googleMapsUrl)) {
                  await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open Google Maps')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.map_rounded, size: 20, color: Colors.white),
              label: const Text(
                'Open & Pin in Google Maps',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerAddressOverlay({double bottomPadding = 20}) {
    final primaryColor = ThemeService.instance.primaryColor;
    final isDark = ThemeService.instance.isDarkMode;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Positioned(
      bottom: bottomPadding,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle Indicator
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Customer Location Workspace",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        "Live Dispatch & Address View",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: labelColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.customerStatus != null && widget.customerStatus!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.customerStatus!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 12),

            // Ticket details in strict 2-column grid alignment
            _buildDetailRow("Booking ID", widget.bookingId != null ? "#${widget.bookingId}" : null, labelColor, textColor, isHighlight: true),
            _buildDetailRow("Customer", widget.customerName, labelColor, textColor),
            _buildDetailRow("Service Type", widget.jobType, labelColor, textColor),
            _buildDetailRow("Device Type", widget.deviceType, labelColor, textColor),
            _buildDetailRow("Device Brand", widget.deviceBrand, labelColor, textColor),
            _buildDetailRow("Assigned Engineer", widget.assignedEmployee, labelColor, textColor),

            const SizedBox(height: 8),

            // Formatted Address Container Box
            if (widget.customerAddress != null && widget.customerAddress!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place_rounded, size: 14, color: primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          "FULL ADDRESS",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: labelColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.customerAddress!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.4,
                      ),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Open & Pin in Google Maps Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final Uri googleMapsUrl;
                  if (_customerLocation != null) {
                    googleMapsUrl = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${_customerLocation!.latitude},${_customerLocation!.longitude}',
                    );
                  } else if (widget.customerAddress != null && widget.customerAddress!.isNotEmpty) {
                    googleMapsUrl = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.customerAddress!)}',
                    );
                  } else {
                    return;
                  }

                  if (await canLaunchUrl(googleMapsUrl)) {
                    await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open Google Maps')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.map_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Open & Pin in Google Maps',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String? value,
    Color labelColor,
    Color textColor, {
    bool isHighlight = false,
  }) {
    if (value == null || value.isEmpty || value == "N/A") {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                color: isHighlight ? ThemeService.instance.primaryColor : textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final isCustomerMode = _customerLocation != null;
    final center = isCustomerMode
        ? _customerLocation!
        : (_lastLocation ?? const latlong.LatLng(12.9716, 77.5946));
    final primaryColor = ThemeService.instance.primaryColor;
    final isDark = ThemeService.instance.isDarkMode;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16.5,
        onPositionChanged: (pos, hasGesture) {
          if (hasGesture && _autoFollow) {
            setState(() => _autoFollow = false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rooks.charity_app',
        ),
        if (_customerLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _customerLocation!,
                width: 64,
                height: 76,
                child: _buildCustomerTeardropMarker(primaryColor: primaryColor),
              ),
            ],
          ),
        // All engineers' markers (Teardrop profile pins matching reference screenshot)
        MarkerLayer(
          markers: _allEngineersData.entries
              .where((entry) => entry.value['location'] != null)
              .map((entry) {
                final data = entry.value;
                final username = data['username'] as String;
                final location = data['location'] as latlong.LatLng;
                final isOnline = data['isOnline'] as bool;
                final isSelected = username == _currentTrackingId;

                return Marker(
                  point: location,
                  width: 72,
                  height: 84,
                  child: GestureDetector(
                    onTap: () {
                      _switchEngineer(username, username);
                    },
                    child: _buildTeardropMarker(
                      username: username,
                      isOnline: isOnline,
                      isSelected: isSelected,
                      primaryColor: primaryColor,
                    ),
                  ),
                );
              })
              .toList(),
        ),
        if (_jobUpdatePoints.isNotEmpty)
          MarkerLayer(
            markers: _jobUpdatePoints.map((item) {
              final pos = item['pos'] as latlong.LatLng;
              final status = item['status'] as String;
              return Marker(
                point: pos,
                width: 32,
                height: 32,
                child: Tooltip(
                  message: 'Job Update: $status',
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  /// Authentic teardrop map marker with avatar and ground pulse circle
  Widget _buildTeardropMarker({
    required String username,
    required bool isOnline,
    required bool isSelected,
    required Color primaryColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Teardrop Pin Housing
        SizedBox(
          width: 54,
          height: 64,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Custom Teardrop Pin Shape
              CustomPaint(
                size: const Size(54, 64),
                painter: TeardropPinPainter(
                  pinColor: Colors.white,
                  borderColor: isSelected
                      ? primaryColor
                      : (isOnline ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
                  borderWidth: isSelected ? 3.0 : 2.0,
                ),
              ),
              // Circular Avatar
              Positioned(
                top: 4,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : const Color(0xFF1E293B),
                  ),
                  child: Center(
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'E',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              // Green Online Dot
              if (isOnline)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Ground Translucent Shadow Pulse beneath teardrop tip
        Container(
          width: 22,
          height: 6,
          decoration: BoxDecoration(
            color: (isSelected ? primaryColor : const Color(0xFF6366F1))
                .withValues(alpha: 0.28),
            borderRadius: const BorderRadius.all(Radius.elliptical(22, 6)),
          ),
        ),
      ],
    );
  }

  /// Pink Teardrop Home Pin for Customer Destination (Reference Style)
  Widget _buildCustomerTeardropMarker({required Color primaryColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 54,
          height: 64,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              CustomPaint(
                size: const Size(54, 64),
                painter: TeardropPinPainter(
                  pinColor: const Color(0xFFEC4899),
                  borderColor: Colors.white,
                  borderWidth: 2.2,
                ),
              ),
              Positioned(
                top: 4,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEC4899),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.home_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 22,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFEC4899).withValues(alpha: 0.35),
            borderRadius: const BorderRadius.all(Radius.elliptical(22, 6)),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingControls() {
    final primaryColor = ThemeService.instance.primaryColor;
    final isDark = ThemeService.instance.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF374151);
    return Positioned(
      right: 14,
      top: 130,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildMapButton(Icons.add_rounded, _zoomIn, textColor: textColor),
                Divider(height: 1, color: Colors.grey.shade200),
                _buildMapButton(Icons.remove_rounded, _zoomOut, textColor: textColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_lastLocation != null)
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildMapButton(
                Icons.my_location_rounded,
                _centerOnEngineer,
                color: _autoFollow ? primaryColor : null,
                textColor: textColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapButton(
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
    required Color textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: color ?? textColor, size: 24),
        ),
      ),
    );
  }

  void _showEngineerSelectionSheet() {
    final primaryColor = ThemeService.instance.primaryColor;
    final isDark = ThemeService.instance.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black;
    final surfaceColor = isDark ? Colors.grey.shade900 : Colors.white;
    final selectedColor = isDark
        ? Colors.grey.shade800
        : primaryColor.withValues(alpha: 0.1);
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final selectedBorderColor = isDark
        ? primaryColor
        : primaryColor.withValues(alpha: 0.4);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          color: surfaceColor,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Select Engineer to Track",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: isDark ? Colors.grey.shade700 : null),
              if (_isLoadingEngineers)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_engineersList.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        "No engineers found",
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Make sure engineers have logged in",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadEngineersList,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _engineersList.length,
                    itemBuilder: (context, index) {
                      final engineer = _engineersList[index];
                      final username = engineer['username'] as String;
                      final bool isOnline = engineer['isOnline'] ?? false;
                      final String? specialization = engineer['specialization'];
                      final String? employeeId = engineer['employeeId'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _currentTrackingId == username
                              ? selectedColor
                              : surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _currentTrackingId == username
                                ? selectedBorderColor
                                : borderColor,
                          ),
                          boxShadow: [
                            if (_currentTrackingId == username)
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withValues(alpha: 0.8),
                                  primaryColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                username.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  username,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _currentTrackingId == username
                                        ? primaryColor
                                        : (isDark
                                              ? Colors.white
                                              : const Color(0xFF1E3A8A)),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isOnline ? "Online" : "Offline",
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isOnline
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (specialization != null &&
                                  specialization.isNotEmpty)
                                Text(
                                  "Specialization: $specialization",
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              if (employeeId != null && employeeId.isNotEmpty)
                                Text(
                                  "Employee ID: $employeeId",
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (_currentTrackingId == username)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    "ACTIVE",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade400,
                                ),
                            ],
                          ),
                          onTap: () {
                            _switchEngineer(username, username);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              if (!_isLoadingEngineers && _engineersList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "${_engineersList.length} engineer(s) found",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEngineerOverlay() {
    final primaryColor = ThemeService.instance.primaryColor;
    final isDark = ThemeService.instance.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final String name = _assignedEmployeeName ?? _currentTrackingName ?? "Field Engineer";

    return Positioned(
      bottom: 20,
      left: 14,
      right: 14,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle Indicator
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'E',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _isOnline
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : const Color(0xFF64748B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _isOnline ? "● Online" : "○ Offline",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _isOnline ? const Color(0xFF059669) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            _lastUpdateTime != null
                                ? "Updated ${DateFormat('HH:mm:ss').format(_lastUpdateTime!)}"
                                : "Live Tracking Active",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _centerOnEngineer,
                    icon: const Icon(Icons.my_location_rounded, size: 16),
                    label: const Text('Recenter Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _showEngineerSelectionSheet,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Switch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for authentic teardrop map pin matching modern tracking apps (e.g. Life360/Circle)
class TeardropPinPainter extends CustomPainter {
  final Color pinColor;
  final Color borderColor;
  final double borderWidth;

  TeardropPinPainter({
    required this.pinColor,
    required this.borderColor,
    this.borderWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = pinColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final path = Path();
    final double radius = size.width / 2;
    final double centerX = size.width / 2;
    final double centerY = radius;

    // Draw teardrop pin shape: circular top + pointed bottom tail
    path.moveTo(centerX, size.height);
    path.lineTo(centerX - 8, centerY + radius * 0.72);
    path.arcToPoint(
      Offset(centerX + 8, centerY + radius * 0.72),
      radius: Radius.circular(radius),
      clockwise: true,
      largeArc: true,
    );
    path.close();

    // Draw drop shadow
    canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);
    // Draw pin fill
    canvas.drawPath(path, paint);
    // Draw pin border
    if (borderWidth > 0) {
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TeardropPinPainter oldDelegate) =>
      oldDelegate.pinColor != pinColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth;
}
