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
import 'package:url_launcher/url_launcher.dart';

class AdminGeoLocationScreen extends StatefulWidget {
  final String engineerId;
  final String engineerName;
  final String? bookingDocId;

  const AdminGeoLocationScreen({
    super.key,
    required this.engineerId,
    required this.engineerName,
    this.bookingDocId,
  });

  @override
  State<AdminGeoLocationScreen> createState() => _AdminGeoLocationScreenState();
}

class _AdminGeoLocationScreenState extends State<AdminGeoLocationScreen> {
  // State variables
  latlong.LatLng? _lastLocation;
  double _currentSpeed = 0.0;
  double _currentHeading = 0.0;
  double _currentAccuracy = 0.0;
  bool _isOnline = false;
  DateTime? _lastUpdateTime;
  DateTime? _lastRTDBUpdateTime;
  int _updateCount = 0;
  bool _autoFollow = true;
  String? _assignedEmployeeName;
  String? _currentTicketStatus;

  StreamSubscription<rtdb.DatabaseEvent>? _engineerSubscription;
  StreamSubscription<firestore.QuerySnapshot<Map<String, dynamic>>>?
  _adminSubscription;
  StreamSubscription<firestore.QuerySnapshot<Map<String, dynamic>>>?
  _updatesSubscription;
  final MapController _mapController = MapController();
  final List<latlong.LatLng> _pathHistory = [];
  final List<Map<String, dynamic>> _jobUpdatePoints = [];
  String? _currentTrackingId;
  String? _currentTrackingName;

  // Store engineers list with their details
  List<Map<String, dynamic>> _engineersList = [];
  bool _isLoadingEngineers = false;

  // Store the selected engineer's document ID for better queries
  String? _selectedEngineerDocId;

  // Flag to track if index is missing
  bool _indexMissing = false;

  // Corrected Firestore index URL
  final String _firestoreIndexUrl =
      'https://console.firebase.google.com/v1/r/project/white-label-app-33300/firestore/indexes?create_composite=Cl5wcm9qZWN0cy93aGl0ZS1sYWJlbC1hcHAtMzM2MDavZGF0YWJhc2VzLylhkZWZhWXk3VwMv5kZGV4ZXNY9fEAAeDQoJDXBKVXRlZEJ5AEAdQoJdXBKVXRlZEJ5AEAdQoJdXBKVXRlZEJ4';

  String _sanitizePath(String path) {
    return path.replaceAll(RegExp(r'[.#$\[\]]'), '_');
  }

  @override
  void initState() {
    super.initState();
    _currentTrackingId = widget.engineerId;
    _currentTrackingName = widget.engineerName;
    _checkAuthAndListen();
    _loadEngineersList();
  }

  // Function to load engineers from Firestore with their document IDs
  Future<void> _loadEngineersList() async {
    if (mounted) {
      setState(() {
        _isLoadingEngineers = true;
      });
    }

    try {
      // Get all engineers from EngineerLogin collection
      final query = FirestoreService.instance.collection('EngineerLogin');

      final snapshot = await query.get();

      final engineers = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final username = data['Username']?.toString();
        final email = data['Email']?.toString();
        final phone = data['Phone']?.toString();

        if (username != null && username.isNotEmpty) {
          engineers.add({
            'docId': doc.id, // Store the actual document ID
            'username': username,
            'email': email,
            'phone': phone,
            'fullPath': doc.reference.path,
          });
        }
      }

      // Remove duplicates based on username (keep the first occurrence)
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

          // If we have a current tracking ID, find its document ID
          if (_currentTrackingId != null) {
            final matchedEngineer = _engineersList.firstWhere(
              (e) => e['username'] == _currentTrackingId,
              orElse: () => {},
            );
            if (matchedEngineer.isNotEmpty) {
              _selectedEngineerDocId = matchedEngineer['docId'];
            }
          }
        });
      }

      debugPrint('Loaded ${_engineersList.length} engineers');
    } catch (e) {
      debugPrint('Error loading engineers: $e');
      if (mounted) {
        setState(() {
          _isLoadingEngineers = false;
        });
      }
    }
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
    _engineerSubscription?.cancel();
    _adminSubscription?.cancel();
    _updatesSubscription?.cancel();

    if (_currentTrackingId != null && _currentTrackingId!.isNotEmpty) {
      _listenToEngineerLocation();
      _listenToEngineerUpdates(); // This will track from Engineer_updates collection
    }
    _listenToAdminDetails();
  }

  void _switchEngineer(String id, String name, {String? docId}) {
    if (mounted) {
      setState(() {
        _currentTrackingId = id;
        _currentTrackingName = name;
        _selectedEngineerDocId = docId;
        _lastLocation = null;
        _pathHistory.clear();
        _jobUpdatePoints.clear();
        _updateCount = 0;
        _currentSpeed = 0.0;
        _currentHeading = 0.0;
        _currentAccuracy = 0.0;
        _isOnline = false;
        _lastUpdateTime = null;
        _assignedEmployeeName = null;
        _currentTicketStatus = null;
        _autoFollow = true;
        _indexMissing = false;
      });

      // Cancel existing subscriptions
      _engineerSubscription?.cancel();
      _updatesSubscription?.cancel();

      // Start new listeners
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
        final dynamic latVal = data['lat'];
        final dynamic lngVal = data['lng'];
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

            // Find the document ID for the new engineer
            final matchedEngineer = _engineersList.firstWhere(
              (e) => e['username'] == assignedEmployee,
              orElse: () => {},
            );

            _switchEngineer(
              assignedEmployee,
              assignedEmployee,
              docId: matchedEngineer.isNotEmpty
                  ? matchedEngineer['docId']
                  : null,
            );
          }

          setState(() {
            _assignedEmployeeName = assignedEmployee;
            _currentTicketStatus = adminStatus;

            if (latVal != null && lngVal != null) {
              final double lat = (latVal as num).toDouble();
              final double lng = (lngVal as num).toDouble();
              final newPos = latlong.LatLng(lat, lng);

              // Only update from Firestore if RTDB hasn't updated recently (last 10 seconds)
              // or if this is the first location we're receiving.
              final bool shouldUpdateFromFirestore =
                  _lastRTDBUpdateTime == null ||
                  DateTime.now().difference(_lastRTDBUpdateTime!).inSeconds >
                      10;

              if (shouldUpdateFromFirestore &&
                  (_lastLocation == null || _lastLocation != newPos)) {
                _lastLocation = newPos;
                _updateCount++;
                _pathHistory.add(newPos);
                if (_pathHistory.length > 200) _pathHistory.removeAt(0);

                if (_autoFollow) {
                  _mapController.move(newPos, _mapController.camera.zoom);
                }
              }
            }
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
    _engineerSubscription?.cancel();
    if (_currentTrackingId == null || _currentTrackingId!.isEmpty) return;

    final sanitizedId = _sanitizePath(_currentTrackingId!);
    final tenantId = ThemeService.instance.databaseName;
    final dbRef = rtdb.FirebaseDatabase.instance.ref(
      '$tenantId/engineers/$sanitizedId',
    );

    _engineerSubscription = dbRef.onValue.listen(
      (event) {
        final data = event.snapshot.value;
        if (data == null) return;

        final engineerData = Map<String, dynamic>.from(data as Map);
        final locationData = engineerData['location'] != null
            ? Map<String, dynamic>.from(engineerData['location'] as Map)
            : null;

        if (mounted) {
          setState(() {
            _isOnline = engineerData['isOnline'] ?? false;

            if (locationData != null) {
              final double lat = (locationData['lat'] as num).toDouble();
              final double lng = (locationData['lng'] as num).toDouble();
              final newPos = latlong.LatLng(lat, lng);

              // Check if position changed
              if (_lastLocation == null || _lastLocation != newPos) {
                _lastLocation = newPos;
                _updateCount++;
                _pathHistory.add(newPos);
                if (_pathHistory.length > 200) _pathHistory.removeAt(0);

                // Auto-follow logic
                if (_autoFollow) {
                  _mapController.move(newPos, _mapController.camera.zoom);
                }
              }

              _currentSpeed = (locationData['speed'] as num? ?? 0.0).toDouble();
              _currentHeading = (locationData['heading'] as num? ?? 0.0)
                  .toDouble();
              _currentAccuracy = (locationData['accuracy'] as num? ?? 0.0)
                  .toDouble();
              _lastRTDBUpdateTime = DateTime.now();
              _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(
                locationData['lastUpdate'] ??
                    locationData['timestamp'] ??
                    DateTime.now().millisecondsSinceEpoch,
              );
            }
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to location: $error');
      },
    );
  }

  // Listen to Engineer_updates collection for tracking
  void _listenToEngineerUpdates() {
    _updatesSubscription?.cancel();

    if (_currentTrackingId == null || _currentTrackingId!.isEmpty) {
      debugPrint('No engineer selected for tracking');
      return;
    }

    debugPrint('Listening to Engineer_updates for: $_currentTrackingId');

    // Try with orderBy first (requires index)
    try {
      firestore.Query<Map<String, dynamic>> query = FirestoreService.instance
          .collection('Engineer_updates')
          .where('updatedBy', isEqualTo: _currentTrackingId)
          .orderBy('updatedAt', descending: true)
          .limit(50); // Get last 50 updates for better history

      _updatesSubscription = query.snapshots().listen(
        (snapshot) {
          _processEngineerUpdates(snapshot);
        },
        onError: (error) {
          debugPrint('Error with ordered query: $error');

          // Check if it's an index error
          if (error.toString().contains('index') ||
              error.toString().contains('failed-precondition')) {
            setState(() {
              _indexMissing = true;
            });

            // Fall back to query without orderBy
            _fallbackEngineerUpdates();
          } else {
            // Show other errors
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error tracking engineer: $error'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Exception setting up query: $e');
      _fallbackEngineerUpdates();
    }
  }

  // Fallback method without orderBy (works without index)
  void _fallbackEngineerUpdates() {
    debugPrint('Using fallback query without orderBy');

    firestore.Query<Map<String, dynamic>> query = FirestoreService.instance
        .collection('Engineer_updates')
        .where('updatedBy', isEqualTo: _currentTrackingId)
        .limit(50);

    _updatesSubscription = query.snapshots().listen(
      (snapshot) {
        _processEngineerUpdates(snapshot);
      },
      onError: (error) {
        debugPrint('Error in fallback query: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error tracking engineer: $error'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  // Process engineer updates (common method for both queries)
  void _processEngineerUpdates(
    firestore.QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.docs.isEmpty) {
      debugPrint('No Engineer_updates found for $_currentTrackingId');
      return;
    }

    debugPrint('Received ${snapshot.docs.length} Engineer_updates');

    // Sort client-side if needed (for fallback query)
    final sortedDocs = snapshot.docs.toList()
      ..sort((a, b) {
        final aTime =
            (a.data()['updatedAt'] as firestore.Timestamp?)?.toDate() ??
            DateTime.now();
        final bTime =
            (b.data()['updatedAt'] as firestore.Timestamp?)?.toDate() ??
            DateTime.now();
        return bTime.compareTo(aTime); // Descending
      });

    // Process all updates
    final List<latlong.LatLng> newPoints = [];
    final List<Map<String, dynamic>> newUpdateDetails = [];
    firestore.Timestamp? latestTimestamp;
    latlong.LatLng? latestPos;
    String? latestStatus;

    // Process in chronological order to maintain sequence
    for (final doc in sortedDocs.reversed) {
      final data = doc.data();
      final dynamic latVal = data['lat'];
      final dynamic lngVal = data['lng'];
      final dynamic timestamp = data['updatedAt'];
      final String? status = data['engineerStatus']?.toString();
      final String docId = doc.id;

      if (latVal != null && lngVal != null) {
        try {
          final double lat = (latVal as num).toDouble();
          final double lng = (lngVal as num).toDouble();
          final pos = latlong.LatLng(lat, lng);

          newPoints.add(pos);

          // Store update details
          newUpdateDetails.add({
            'pos': pos,
            'status': status ?? 'Update',
            'time': timestamp is firestore.Timestamp
                ? timestamp.toDate()
                : null,
            'docId': docId,
            'rawData': data,
          });

          // Track the latest update
          if (timestamp is firestore.Timestamp) {
            if (latestTimestamp == null ||
                timestamp.toDate().isAfter(latestTimestamp.toDate())) {
              latestTimestamp = timestamp;
              latestPos = pos;
              latestStatus = status;
            }
          }
        } catch (e) {
          debugPrint('Error parsing location data: $e');
        }
      }
    }

    if (mounted && newPoints.isNotEmpty) {
      setState(() {
        // Add new points to path history (avoid duplicates)
        for (final point in newPoints) {
          if (!_pathHistory.contains(point)) {
            _pathHistory.add(point);
          }
        }

        // Limit path history size
        if (_pathHistory.length > 500) {
          _pathHistory.removeRange(0, _pathHistory.length - 500);
        }

        // Update job update points
        _jobUpdatePoints.clear();
        _jobUpdatePoints.addAll(newUpdateDetails.reversed.take(20).toList());

        // If we have a latest position from Engineer_updates and no recent RTDB update,
        // use this as the current location
        final bool useEngineerUpdates =
            _lastRTDBUpdateTime == null ||
            (latestTimestamp != null &&
                latestTimestamp.toDate().isAfter(
                  _lastRTDBUpdateTime!.subtract(const Duration(minutes: 5)),
                ));

        if (useEngineerUpdates && latestPos != null) {
          debugPrint(
            'Using Engineer_updates location from ${latestTimestamp?.toDate()}',
          );
          _lastLocation = latestPos;
          _updateCount++;

          // Update status if available
          if (latestStatus != null) {
            _currentTicketStatus = latestStatus;
          }

          if (_autoFollow) {
            _mapController.move(latestPos, _mapController.camera.zoom);
          }
          _lastUpdateTime = latestTimestamp?.toDate() ?? DateTime.now();
        }
      });
    }
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

  // Improved URL launcher with better error handling
  Future<void> _launchURL(String url) async {
    debugPrint('Attempting to launch URL: $url');

    final Uri uri = Uri.parse(url);
    try {
      // Check if we can launch the URL
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
        debugPrint('URL launched successfully');
      } else {
        debugPrint('Cannot launch URL: $url');

        // Show error with alternative options
        if (mounted) {
          _showUrlErrorDialog(url);
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        _showUrlErrorDialog(url);
      }
    }
  }

  // Show dialog with alternative ways to access the URL
  void _showUrlErrorDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cannot Open Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unable to open the browser automatically.'),
            const SizedBox(height: 16),
            const Text('Please copy this link manually:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(url, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Copy to clipboard
              // Note: You'll need to add clipboard service if you want this
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _engineerSubscription?.cancel();
    _adminSubscription?.cancel();
    _updatesSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentTrackingName != null && _currentTrackingName!.isNotEmpty
                  ? "Tracking: $_currentTrackingName"
                  : "Select an Engineer",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _isOnline ? "Online (RTDB)" : "Offline",
              style: TextStyle(
                fontSize: 12,
                color: _isOnline ? Colors.greenAccent : Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            ),
          ),
        ),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadEngineersList,
            tooltip: 'Refresh engineers list',
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.group_add_rounded, color: Colors.white),
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
      ),
      body: Stack(
        children: [
          _buildMap(),
          _buildFloatingControls(),
          _buildEngineerOverlay(),
          // if (_indexMissing) _buildIndexWarning(),
        ],
      ),
    );
  }

  // Widget _buildIndexWarning() {
  //   return Positioned(
  //     top: 16,
  //     left: 16,
  //     right: 16,
  //     child: Material(
  //       elevation: 8,
  //       borderRadius: BorderRadius.circular(12),
  //       child: Container(
  //         padding: const EdgeInsets.all(16),
  //         decoration: BoxDecoration(
  //           color: Colors.orange.shade50,
  //           borderRadius: BorderRadius.circular(12),
  //           border: Border.all(color: Colors.orange.shade300),
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Row(
  //               children: [
  //                 Icon(
  //                   Icons.warning_amber_rounded,
  //                   color: Colors.orange.shade700,
  //                 ),
  //                 const SizedBox(width: 8),
  //                 Expanded(
  //                   child: Text(
  //                     'Firestore Index Required',
  //                     style: GoogleFonts.inter(
  //                       fontWeight: FontWeight.bold,
  //                       fontSize: 16,
  //                       color: Colors.orange.shade800,
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             const SizedBox(height: 8),
  //             Text(
  //               'For optimal performance, please create the required Firestore index.',
  //               style: GoogleFonts.inter(
  //                 fontSize: 12,
  //                 color: Colors.orange.shade800,
  //               ),
  //             ),
  //             const SizedBox(height: 12),
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.end,
  //               children: [
  //                 TextButton(
  //                   onPressed: () {
  //                     setState(() {
  //                       _indexMissing = false;
  //                     });
  //                   },
  //                   child: const Text('DISMISS'),
  //                 ),
  //                 const SizedBox(width: 8),
  //                 ElevatedButton(
  //                   onPressed: () {
  //                     _launchURL(_firestoreIndexUrl);
  //                   },
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: Colors.orange.shade700,
  //                     foregroundColor: Colors.white,
  //                   ),
  //                   child: const Text('CREATE INDEX'),
  //                 ),
  //               ],
  //             ),
  //             const SizedBox(height: 8),
  //             Container(
  //               padding: const EdgeInsets.all(8),
  //               decoration: BoxDecoration(
  //                 color: Colors.white,
  //                 borderRadius: BorderRadius.circular(4),
  //               ),
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     'Or create manually:',
  //                     style: GoogleFonts.inter(
  //                       fontSize: 10,
  //                       fontWeight: FontWeight.bold,
  //                       color: Colors.grey.shade700,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 4),
  //                   Text(
  //                     '1. Go to Firebase Console',
  //                     style: GoogleFonts.inter(fontSize: 10),
  //                   ),
  //                   Text(
  //                     '2. Firestore Database → Indexes',
  //                     style: GoogleFonts.inter(fontSize: 10),
  //                   ),
  //                   Text(
  //                     '3. Create composite index:',
  //                     style: GoogleFonts.inter(fontSize: 10),
  //                   ),
  //                   Text(
  //                     '   • Collection: Engineer_updates',
  //                     style: GoogleFonts.inter(fontSize: 10),
  //                   ),
  //                   Text(
  //                     '   • Fields: updatedBy (Ascending), updatedAt (Descending)',
  //                     style: GoogleFonts.inter(fontSize: 10),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildMap() {
    final center = _lastLocation ?? const latlong.LatLng(12.9716, 77.5946);

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
          additionalOptions: const {
            'attribution': '© OpenStreetMap contributors',
            'minZoom': '1',
            'maxZoom': '19',
          },
          tileProvider: _CachedTileProvider(),
          fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
          maxZoom: 19,
          retinaMode: true,
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () =>
                  _launchURL('https://www.openstreetmap.org/copyright'),
            ),
          ],
        ),
        if (_pathHistory.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _pathHistory,
                strokeWidth: 4,
                color: Colors.blue.withOpacity(0.6),
              ),
            ],
          ),
        if (_jobUpdatePoints.isNotEmpty)
          MarkerLayer(
            markers: _jobUpdatePoints.map((item) {
              final pos = item['pos'] as latlong.LatLng;
              final status = item['status'] as String;
              final time = item['time'] as DateTime?;

              return Marker(
                point: pos,
                width: 40,
                height: 40,
                child: Tooltip(
                  message:
                      'Status: $status\nTime: ${time != null ? DateFormat('HH:mm:ss').format(time) : 'Unknown'}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        if (_lastLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _lastLocation!,
                width: 100,
                height: 100,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        _assignedEmployeeName ??
                            _currentTrackingName ??
                            "Engineer",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.2),
                          ),
                        ),
                        Transform.rotate(
                          angle: _currentHeading * (3.14159 / 180),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (_lastLocation != null && _currentAccuracy > 0)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _lastLocation!,
                radius: _currentAccuracy,
                useRadiusInMeter: true,
                color: Colors.blue.withOpacity(0.1),
                borderColor: Colors.blue.withOpacity(0.3),
                borderStrokeWidth: 1,
              ),
            ],
          ),
      ],
    );
  }

  // Helper method to get color based on status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.orange;
      case 'pending':
        return Colors.red;
      case 'started':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  Widget _buildFloatingControls() {
    return Positioned(
      right: 16,
      top: 16,
      child: Column(
        children: [
          _buildMapButton(Icons.add, _zoomIn),
          const SizedBox(height: 8),
          _buildMapButton(Icons.remove, _zoomOut),
          const SizedBox(height: 16),
          _buildMapButton(
            Icons.my_location,
            _centerOnEngineer,
            color: _autoFollow ? Colors.blue : Colors.white,
          ),
        ],
      ),
    );
  }

  void _showEngineerSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(),
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
                      const Icon(
                        Icons.people_outline,
                        size: 60,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No engineers found",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Make sure engineers have logged in",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadEngineersList,
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
                      final docId = engineer['docId'] as String;
                      final email = engineer['email'] as String?;
                      final phone = engineer['phone'] as String?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _currentTrackingId == username
                              ? Colors.blue.shade50
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _currentTrackingId == username
                                ? Colors.blue.shade200
                                : Colors.grey.shade200,
                          ),
                          boxShadow: [
                            if (_currentTrackingId == username)
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.05),
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
                                  Colors.blue.shade400,
                                  Colors.blue.shade700,
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
                          title: Text(
                            username,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: const Color(0xFF1E3A8A),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (email != null && email.isNotEmpty)
                                Text(
                                  email,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              if (phone != null && phone.isNotEmpty)
                                Text(
                                  phone,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              Text(
                                "Doc ID: $docId",
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: Colors.grey.shade400,
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
                                    color: Colors.blue.shade600,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    "TRACKING",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              else
                                ElevatedButton(
                                  onPressed: () {
                                    _switchEngineer(
                                      username,
                                      username,
                                      docId: docId,
                                    );
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(80, 30),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text("Track"),
                                ),
                            ],
                          ),
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
                      color: Colors.grey.shade500,
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

  Widget _buildMapButton(
    IconData icon,
    VoidCallback onPressed, {
    Color color = Colors.white,
  }) {
    return FloatingActionButton.small(
      heroTag: null,
      onPressed: onPressed,
      backgroundColor: color,
      child: Icon(
        icon,
        color: color == Colors.white ? Colors.black87 : Colors.white,
      ),
    );
  }

  Widget _buildEngineerOverlay() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.engineering_rounded,
                            color: Colors.blue.shade700,
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
                                  color: const Color(0xFF1E3A8A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _lastUpdateTime != null
                                        ? "Updated: ${DateFormat('HH:mm:ss').format(_lastUpdateTime!)}"
                                        : 'Waiting for updates...',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedEngineerDocId != null)
                                Text(
                                  "Doc: ${_selectedEngineerDocId!.substring(0, 8)}...",
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _buildStatusIndicator(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoStat(
                            Icons.speed_rounded,
                            "Speed",
                            (_currentSpeed * 3.6).toStringAsFixed(1),
                            "km/h",
                            Colors.orange,
                          ),
                          _buildVerticalDivider(),
                          _buildInfoStat(
                            Icons.sync_rounded,
                            "Updates",
                            "$_updateCount",
                            "pts",
                            Colors.blue,
                          ),
                          _buildVerticalDivider(),
                          _buildInfoStat(
                            Icons.timeline_rounded,
                            "Distance",
                            (_pathHistory.length * 0.01).toStringAsFixed(2),
                            "km",
                            Colors.green,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_jobUpdatePoints.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            "Recent Status Updates",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${_jobUpdatePoints.length} updates",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _jobUpdatePoints.length,
                          itemBuilder: (context, index) {
                            final update = _jobUpdatePoints[index];
                            final DateTime? time = update['time'];
                            final String status = update['status'];
                            final pos = update['pos'] as latlong.LatLng;

                            return GestureDetector(
                              onTap: () {
                                _mapController.move(pos, 15);
                                setState(() => _autoFollow = false);
                              },
                              child: Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    status,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _getStatusColor(
                                      status,
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      status,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: _getStatusColor(status),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      time != null
                                          ? DateFormat('HH:mm').format(time)
                                          : 'Unknown',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    String statusText =
        _currentTicketStatus?.toUpperCase() ??
        (_isOnline ? "LIVE (RTDB)" : "OFFLINE");

    Color bgColor = _isOnline ? Colors.green.shade50 : Colors.red.shade50;
    Color textColor = _isOnline ? Colors.green.shade700 : Colors.red.shade700;
    Color borderColor = _isOnline ? Colors.green.shade200 : Colors.red.shade200;

    if (_currentTicketStatus != null) {
      bgColor = _getStatusColor(_currentTicketStatus!).withOpacity(0.1);
      textColor = _getStatusColor(_currentTicketStatus!);
      borderColor = _getStatusColor(_currentTicketStatus!).withOpacity(0.3);
      statusText = _currentTicketStatus!.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey.shade300);
  }

  Widget _buildInfoStat(
    IconData icon,
    String label,
    String value,
    String unit,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: const Color(0xFF1E3A8A),
                ),
              ),
              TextSpan(
                text: " $unit",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey.shade500,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// Custom tile provider for caching
class _CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return NetworkImage(
      getTileUrl(coordinates, options),
      headers: const {
        'User-Agent': 'SubscriptionRooksApp/1.0 (contact@yourcompany.com)',
        'Accept-Encoding': 'gzip',
      },
    );
  }
}
