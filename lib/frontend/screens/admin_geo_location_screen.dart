import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:geocoding/geocoding.dart';

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
      List<Location> locations = await locationFromAddress(_customerAddress!);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not geocode address: $_customerAddress'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
          .collection('Admin_details')
          .where(
            firestore.FieldPath.documentId,
            isEqualTo: widget.bookingDocId,
          );
    } else if (_currentTrackingId != null && _currentTrackingId!.isNotEmpty) {
      // Otherwise, track the latest record for the selected engineer
      query = FirestoreService.instance
          .collection('Admin_details')
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
            'AdminGeoLocationScreen: No Admin_details found for tracking',
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
    final bool isCustomerLocationMode = _customerLocation != null;
    final bool showBothOverlays =
        isEngineerSelected && widget.customerAddress != null;
    final primaryColor = ThemeService.instance.primaryColor;
    final isDark = ThemeService.instance.isDarkMode;
    // Determine if we need white or black foreground for AppBar
    final appBarForegroundColor =
        (isDark || primaryColor.computeLuminance() < 0.5)
        ? Colors.white
        : Colors.black;

    return Scaffold(
      appBar: AppBar(
        foregroundColor: appBarForegroundColor,
        backgroundColor: primaryColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCustomerLocationMode
                  ? "Customer Location"
                  : (isEngineerSelected
                        ? "Tracking: $_currentTrackingName"
                        : "Select an Engineer"),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: appBarForegroundColor,
              ),
            ),
            if (!isCustomerLocationMode && isEngineerSelected)
              Text(
                _isOnline ? "Online" : "Offline (Last Known Location)",
                style: TextStyle(
                  fontSize: 12,
                  color: _isOnline
                      ? Colors.greenAccent
                      : appBarForegroundColor.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        elevation: 4,
        actions: [
          if (!isCustomerLocationMode) ...[
            IconButton(
              icon: Icon(Icons.refresh, color: appBarForegroundColor),
              onPressed: _loadEngineersList,
              tooltip: 'Refresh engineers list',
            ),
            IconButton(
              icon: Stack(
                children: [
                  Icon(Icons.group_add_rounded, color: appBarForegroundColor),
                  if (_engineersList.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          _engineersList.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: _showEngineerSelectionSheet,
              tooltip: 'Select Engineer',
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          _buildFloatingControls(),
          // Only show engineer details card if we are NOT in customer location mode
          if (!isCustomerLocationMode) ...[
            if (showBothOverlays) ...[
              _buildCustomerAddressOverlay(bottomPadding: 180),
              _buildEngineerOverlay(),
            ] else ...[
              if (isEngineerSelected) _buildEngineerOverlay(),
              if (widget.customerAddress != null)
                _buildCustomerAddressOverlay(),
            ],
          ]
          // In customer location mode, only show the customer address card
          else if (widget.customerAddress != null)
            _buildCustomerAddressOverlay(),
        ],
      ),
    );
  }

  Widget _buildCustomerAddressOverlay({double bottomPadding = 20}) {
    final primaryColor = ThemeService.instance.primaryColor;
    final isDark = ThemeService.instance.isDarkMode;
    final surfaceColor = isDark ? Colors.grey.shade900 : Colors.white;
    final borderColor = isDark ? Colors.grey.shade700 : const Color(0xFFE5E7EB);
    final dividerColor = isDark
        ? Colors.grey.shade700
        : const Color(0xFFE5E7EB);
    final labelColor = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final headerTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Positioned(
      bottom: bottomPadding,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.home_work_rounded,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "Customer Location",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: headerTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Ticket details
            _buildDetailRow(
              "Booking ID",
              widget.bookingId,
              labelColor,
              textColor,
            ),
            _buildDetailRow(
              "Customer",
              widget.customerName,
              labelColor,
              textColor,
            ),
            _buildDetailRow(
              "Service Type",
              widget.jobType,
              labelColor,
              textColor,
            ),
            _buildDetailRow(
              "Device Type",
              widget.deviceType,
              labelColor,
              textColor,
            ),
            _buildDetailRow(
              "Device Brand",
              widget.deviceBrand,
              labelColor,
              textColor,
            ),
            _buildDetailRow(
              "Assigned Engineer",
              widget.assignedEmployee,
              labelColor,
              textColor,
            ),
            _buildDetailRow(
              "Status",
              widget.customerStatus,
              labelColor,
              textColor,
            ),
            Divider(height: 24, color: dividerColor),
            // Address
            Text(
              "Address",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: labelColor,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.customerAddress ?? "N/A",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textColor,
                height: 1.5,
              ),
              softWrap: true,
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
    Color textColor,
  ) {
    if (value == null || value.isEmpty || value == "N/A")
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, color: textColor),
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
    final textColor = isDark ? Colors.white : const Color(0xFF333333);

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
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rooks.charity_app',
        ),
        if (_customerLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _customerLocation!,
                width: 80,
                height: 80,
                child: Icon(Icons.location_pin, color: primaryColor, size: 50),
              ),
            ],
          ),
        // All engineers' markers (always show them!)
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
                  width: 140,
                  height: 120,
                  child: GestureDetector(
                    onTap: () {
                      // When tapping a marker, select that engineer
                      _switchEngineer(username, username);
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade900 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            username,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? primaryColor : textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.all(isSelected ? 8 : 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade900 : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: isSelected
                                ? Border.all(color: primaryColor, width: 3)
                                : null,
                          ),
                          child: Icon(
                            Icons.location_pin,
                            color: isOnline ? primaryColor : Colors.grey,
                            size: isSelected ? 30 : 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              })
              .toList(),
        ),
        if (_pathHistory.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _pathHistory,
                strokeWidth: 4,
                color: primaryColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        if (_jobUpdatePoints.isNotEmpty)
          MarkerLayer(
            markers: _jobUpdatePoints.map((item) {
              final pos = item['pos'] as latlong.LatLng;
              final status = item['status'] as String;
              return Marker(
                point: pos,
                width: 30,
                height: 30,
                child: Tooltip(
                  message: 'Job Update: $status',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
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

  Widget _buildFloatingControls() {
    final primaryColor = ThemeService.instance.primaryColor;
    final isDark = ThemeService.instance.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF374151);
    return Positioned(
      right: 16,
      top: 16,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildMapButton(Icons.add, _zoomIn, textColor: textColor),
                Divider(height: 1, color: Colors.grey.shade300),
                _buildMapButton(Icons.remove, _zoomOut, textColor: textColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_lastLocation != null)
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildMapButton(
                Icons.my_location,
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
    final textColor = isDark ? Colors.white : Colors.black;
    final surfaceColor = isDark
        ? Colors.grey.shade900
        : Colors.white.withValues(alpha: 0.95);

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.grey.shade700
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.engineering_rounded,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _assignedEmployeeName ??
                            _currentTrackingName ??
                            "Select Engineer",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: isDark ? Colors.white : primaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isOnline ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _isOnline
                                  ? "Online"
                                  : "Offline (Last Known Location)",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _isOnline ? Colors.green : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_lastUpdateTime != null)
                            Flexible(
                              child: Text(
                                "Last updated: ${DateFormat('HH:mm:ss').format(_lastUpdateTime!)}",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
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
