import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/brand_model_backend.dart';

class BrandModelPage extends StatefulWidget {
  const BrandModelPage({super.key});

  @override
  State<BrandModelPage> createState() => _BrandModelPageState();
}

class _BrandModelPageState extends State<BrandModelPage> with RouteAware {
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get secondaryColor => Theme.of(context).colorScheme.secondary;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get lightBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get surfaceColor => Theme.of(context).cardColor;
  Color get errorColor => Theme.of(context).colorScheme.error;
  Color get successColor => Colors.green;
  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  Color get lightTextColor => Theme.of(context).hintColor;

  final RouteObserver<ModalRoute<void>> _routeObserver =
      RouteObserver<ModalRoute<void>>();
  final _formKey = GlobalKey<FormState>();
  String? _selecteddevicesbrand;
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _specificationController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Map<String, String> devicesbrandCollections = {};

  List<String> devicesbrands = [];
  bool isLoading = false;
  bool isInitializing = true;
  bool showExistingValues = false;
  final BrandModelBackend _backend = BrandModelBackend();

  // For editing existing records
  String? _editingDocumentId;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    _loaddevicesbrands();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _loaddevicesbrands();
    super.didPopNext();
  }

  Future<void> _loaddevicesbrands() async {
    try {
      final alldevicesbrands = await _backend.loaddevicesbrands();

      if (!mounted) return;
      setState(() {
        devicesbrandCollections = alldevicesbrands;
        devicesbrands = devicesbrandCollections.keys.toList();
        isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isInitializing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading device types: $e'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    }
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    _brandController.dispose();
    _modelController.dispose();
    _specificationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addItem() async {
    if (_formKey.currentState == null ||
        !_formKey.currentState!.validate() ||
        _selecteddevicesbrand == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selecteddevicesbrand == null
                ? 'Please select a device type'
                : 'Please fill all required fields',
          ),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      final collectionName = devicesbrandCollections[_selecteddevicesbrand];
      if (collectionName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid device type selected.'),
            backgroundColor: errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        return;
      }

      await _backend.saveDeviceItem(
        devicesbrand: _selecteddevicesbrand!,
        collectionName: collectionName,
        brandName: _brandController.text,
        model: _modelController.text,
        specification: _specificationController.text,
        description: _descriptionController.text,
        editingDocumentId: isEditing ? _editingDocumentId : null,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item ${isEditing ? 'updated' : 'added'} successfully'),
          backgroundColor: successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );

      if (isEditing) {
        _cancelEdit();
      } else {
        _clearForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ${isEditing ? 'updating' : 'adding'} item: $e'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  void _editItem(Map<String, dynamic> item, String documentId) {
    if (!mounted) return;
    setState(() {
      isEditing = true;
      _editingDocumentId = documentId;
      _brandController.text = item['brandName'] ?? '';
      _modelController.text = item['model'] ?? '';
      _specificationController.text = item['specification'] ?? '';
      _descriptionController.text = item['description'] ?? '';
    });
  }

  void _cancelEdit() {
    if (!mounted) return;
    setState(() {
      isEditing = false;
      _editingDocumentId = null;
    });
    _clearForm();
  }

  Future<void> _deleteItem(
    String collectionName,
    String documentId,
    String brandName,
  ) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Confirm Delete',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "$brandName"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      await _backend.deleteDeviceItem(collectionName, documentId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$brandName" deleted successfully'),
          backgroundColor: successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting item: $e'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void _clearForm() {
    if (_formKey.currentState != null) {
      _formKey.currentState!.reset();
    }
    _brandController.clear();
    _modelController.clear();
    _specificationController.clear();
    _descriptionController.clear();
  }

  void _showAddDeviceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const AddDeviceDialog();
      },
    ).then((value) {
      if (!mounted) return;
      if (value != null && value is Map<String, String>) {
        setState(() {
          devicesbrandCollections[value['devicesbrand']!] =
              value['collectionName']!;
          devicesbrands = devicesbrandCollections.keys.toList();
        });
      } else if (value == true) {
        _loaddevicesbrands();
      }
    });
  }

  Future<void> _deletedevicesbrand(String devicesbrand) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Confirm Delete',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete the $devicesbrand device type and all its data? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      String collectionName = devicesbrandCollections[devicesbrand]!;

      await _backend.deletedevicesbrand(devicesbrand, collectionName);

      devicesbrandCollections.remove(devicesbrand);

      if (_selecteddevicesbrand == devicesbrand) {
        _clearForm();
        if (!mounted) return;
        setState(() {
          _selecteddevicesbrand = null;
          showExistingValues = false;
        });
      }

      if (!mounted) return;
      setState(() {
        devicesbrands = devicesbrandCollections.keys.toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$devicesbrand deleted successfully'),
          backgroundColor: successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting $devicesbrand: $e'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  IconData _getDeviceIcon(String devicesbrand) {
    switch (devicesbrand) {
      case 'Desktop':
        return Icons.desktop_windows;
      case 'Laptop':
        return Icons.laptop;
      case 'Printer':
        return Icons.print;
      case 'Projector':
        return Icons.video_label;
      default:
        return Icons.devices_other;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;
    final isVerySmallScreen = screenWidth < 400;

    return Scaffold(
      backgroundColor: lightBackground,
      appBar: AppBar(
        title: Text(
          'Add New Device',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 18 : 20,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isInitializing
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [primaryColor.withOpacity(0.8), primaryColor],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add_box_rounded,
                                    color: Colors.white,
                                    size: isSmallScreen ? 20 : 24,
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 8 : 12),
                                Text(
                                  'Device Information',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 18 : 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            Text(
                              'Select a device type and provide the required details to add a new device to your inventory',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        'SELECT DEVICE TYPE *',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    // Responsive grid for device types
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = isVerySmallScreen
                            ? 1
                            : isSmallScreen
                            ? 2
                            : 3;
                        double spacing = isSmallScreen ? 12.0 : 16.0;
                        double aspectRatio = isSmallScreen
                            ? (constraints.maxWidth / crossAxisCount) / 100
                            : (constraints.maxWidth / crossAxisCount) / 120;

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: aspectRatio,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            ...devicesbrands.map((devicesbrand) {
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color:
                                          _selecteddevicesbrand == devicesbrand
                                          ? primaryColor
                                          : Colors.grey.shade300,
                                      width:
                                          _selecteddevicesbrand == devicesbrand
                                          ? 2
                                          : 1,
                                    ),
                                  ),
                                  color: _selecteddevicesbrand == devicesbrand
                                      ? primaryColor.withOpacity(0.08)
                                      : surfaceColor,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selecteddevicesbrand = devicesbrand;
                                        showExistingValues = false;
                                        if (isEditing) _cancelEdit();
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.all(
                                            isSmallScreen ? 8.0 : 12.0,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: isSmallScreen ? 32 : 40,
                                                height: isSmallScreen ? 32 : 40,
                                                decoration: BoxDecoration(
                                                  color:
                                                      _selecteddevicesbrand ==
                                                          devicesbrand
                                                      ? primaryColor
                                                      : primaryColor
                                                            .withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  _getDeviceIcon(devicesbrand),
                                                  color:
                                                      _selecteddevicesbrand ==
                                                          devicesbrand
                                                      ? Colors.white
                                                      : primaryColor,
                                                  size: isSmallScreen ? 16 : 22,
                                                ),
                                              ),
                                              SizedBox(
                                                width: isSmallScreen ? 8 : 12,
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      devicesbrand,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            _selecteddevicesbrand ==
                                                                devicesbrand
                                                            ? primaryColor
                                                            : textColor,
                                                        fontSize: isSmallScreen
                                                            ? 12
                                                            : 14,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: isSmallScreen
                                                          ? 2
                                                          : 4,
                                                    ),
                                                    Text(
                                                      devicesbrandCollections[devicesbrand]!,
                                                      style: TextStyle(
                                                        fontSize: isSmallScreen
                                                            ? 10
                                                            : 11,
                                                        color: lightTextColor,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              size: isSmallScreen ? 16 : 18,
                                              color: errorColor.withOpacity(
                                                0.7,
                                              ),
                                            ),
                                            onPressed: () =>
                                                _deletedevicesbrand(
                                                  devicesbrand,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            // Add Device Card Button
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: primaryColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: _showAddDeviceDialog,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          primaryColor.withOpacity(0.05),
                                          primaryColor.withOpacity(0.1),
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                        isSmallScreen ? 8.0 : 12.0,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_circle_outline,
                                            color: primaryColor,
                                            size: isSmallScreen ? 24 : 28,
                                          ),
                                          SizedBox(
                                            height: isSmallScreen ? 4 : 8,
                                          ),
                                          Text(
                                            'Add New Type',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: primaryColor,
                                              fontSize: isSmallScreen ? 10 : 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    if (_selecteddevicesbrand == null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 8),
                        child: Text(
                          'Please select a device type',
                          style: TextStyle(
                            color: errorColor,
                            fontSize: isSmallScreen ? 11 : 12,
                          ),
                        ),
                      ),
                    SizedBox(height: isSmallScreen ? 16 : 24),
                    if (_selecteddevicesbrand != null) ...[
                      // Show Existing Values Toggle
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: surfaceColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.list_alt,
                                color: primaryColor,
                                size: isSmallScreen ? 20 : 24,
                              ),
                              SizedBox(width: isSmallScreen ? 8 : 12),
                              Expanded(
                                child: Text(
                                  'Show Existing Values',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Switch(
                                value: showExistingValues,
                                onChanged: (value) {
                                  setState(() {
                                    showExistingValues = value;
                                    if (isEditing && !value) _cancelEdit();
                                  });
                                },
                                activeThumbColor: primaryColor,
                                activeTrackColor: primaryColor.withOpacity(0.3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 24),

                      if (showExistingValues) _buildExistingValuesList(),

                      if (!showExistingValues || isEditing)
                        _buildDeviceDetailsForm(isSmallScreen),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDeviceDetailsForm(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEditing ? Icons.edit : Icons.edit_document,
                      color: primaryColor,
                      size: isSmallScreen ? 18 : 20,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Text(
                    isEditing ? 'Edit Device Details' : 'Device Details',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 12 : 20),

              // Brand Name
              TextFormField(
                controller: _brandController,
                decoration: InputDecoration(
                  labelText: 'Brand Name',
                  labelStyle: TextStyle(color: Theme.of(context).hintColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.branding_watermark,
                    color: primaryColor.withOpacity(0.7),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a brand name';
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 12 : 20),

              // Model
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: 'Model',
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.model_training,
                    color: primaryColor.withOpacity(0.7),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a model';
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 12 : 20),

              // Specification
              TextFormField(
                controller: _specificationController,
                decoration: InputDecoration(
                  labelText: 'Specification',
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.list_alt,
                    color: primaryColor.withOpacity(0.7),
                  ),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter specifications';
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 12 : 20),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.description,
                    color: primaryColor.withOpacity(0.7),
                  ),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 20 : 28),

              // Buttons
              isSmallScreen
                  ? Column(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _addItem,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              isEditing ? 'Update Device' : 'Add Device',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        if (isEditing) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _cancelEdit,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: errorColor,
                                side: BorderSide(color: errorColor, width: 1.5),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel Edit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _clearForm,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Clear Form',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _addItem,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                isEditing ? 'Update Device' : 'Add Device',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        if (isEditing) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _cancelEdit,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: errorColor,
                                side: BorderSide(color: errorColor, width: 1.5),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel Edit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                        ],
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clearForm,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Clear Form',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
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

  Widget _buildExistingValuesList() {
    final collectionName = devicesbrandCollections[_selecteddevicesbrand];

    if (collectionName == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No collection found for selected device type',
            style: TextStyle(color: errorColor),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _backend.streamDevices(collectionName),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'Error loading data: ${snapshot.error}',
                style: TextStyle(color: errorColor),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: lightTextColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No devices found',
                    style: TextStyle(fontSize: 16, color: lightTextColor),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Add a new device to get started',
                    style: TextStyle(fontSize: 12, color: lightTextColor),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: surfaceColor,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.list_alt, color: primaryColor),
                    SizedBox(width: 8),
                    Text(
                      'Existing $_selecteddevicesbrand Devices (${documents.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              ...documents.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getDeviceIcon(_selecteddevicesbrand!),
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      data['brandName'] ?? 'Unknown Brand',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Model: ${data['model'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          'ID: ${data['brandId'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 11, color: lightTextColor),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: primaryColor),
                          onPressed: () => _editItem(data, doc.id),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: errorColor),
                          onPressed: () => _deleteItem(
                            collectionName,
                            doc.id,
                            data['brandName'] ?? 'Unknown Brand',
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Show details in a dialog
                      _showDeviceDetails(data);
                    },
                  ),
                );
              }),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showDeviceDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['brandName'] ?? 'Device Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Brand ID', data['brandId']),
              _buildDetailRow('Brand Name', data['brandName']),
              _buildDetailRow('Model', data['model']),
              _buildDetailRow('Specification', data['specification']),
              _buildDetailRow('Description', data['description']),
              if (data['createdAt'] != null)
                _buildDetailRow('Created', _formatTimestamp(data['createdAt'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(color: lightTextColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate().toString();
    }
    return timestamp?.toString() ?? 'N/A';
  }
}

class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({super.key});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  Color get primaryColor => Theme.of(context).primaryColor;

  final TextEditingController _devicesbrandController = TextEditingController();
  bool _isCreating = false;
  final BrandModelBackend _backend = BrandModelBackend();

  @override
  void dispose() {
    _devicesbrandController.dispose();
    super.dispose();
  }

  Future<void> _createDeviceCollection() async {
    final String devicesbrand = _devicesbrandController.text.trim();

    if (devicesbrand.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a device type'),
          backgroundColor: Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final String collectionName = _backend.generateCollectionName(
        devicesbrand,
      );
      await _backend.savedevicesbrand(devicesbrand, collectionName);

      if (!mounted) return;
      Navigator.of(
        context,
      ).pop({'devicesbrand': devicesbrand, 'collectionName': collectionName});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating device type: $e'),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: SingleChildScrollView(
        child: Container(
          width: isSmallScreen ? double.infinity : 340,
          constraints: BoxConstraints(maxHeight: isSmallScreen ? 400 : 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_circle_outline,
                      color: primaryColor,
                      size: isSmallScreen ? 28 : 32,
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                Center(
                  child: Text(
                    'Add New Device Type',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                TextField(
                  controller: _devicesbrandController,
                  decoration: InputDecoration(
                    labelText: 'Device Type',
                    labelStyle: TextStyle(color: Theme.of(context).hintColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    hintText: 'e.g., Tablet, Server, Router',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.devices,
                      color: primaryColor.withOpacity(0.7),
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                Text(
                  'Collection name will be automatically generated (e.g., "tabletBrands")',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isCreating
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isCreating
                              ? null
                              : _createDeviceCollection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Create',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
