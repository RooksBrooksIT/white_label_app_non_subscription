import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class AMCCreatePage extends StatefulWidget {
  const AMCCreatePage({super.key});

  @override
  State<AMCCreatePage> createState() => _AMCCreatePageState();
}

class _AMCCreatePageState extends State<AMCCreatePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isCheckingEmail = false;
  bool _isCheckingPhone = false;
  String? _emailError;
  String? _phoneError;

  // New variables for edit mode
  bool _isEditMode = false;
  String? _editingDocId;
  String? _originalEmail;
  String? _originalPhone;

  // Dynamic Color Palette from ThemeService
  late Color primaryColor;
  late Color secondaryColor;
  late Color backgroundColor;
  final Color accentColor = const Color(0xFF00D2FF);
  final Color textColor = const Color(0xFF2D3436);
  final Color textLightColor = const Color(0xFF636E72);
  final Color errorColor = const Color(0xFFD63031);
  final Color successColor = const Color(0xFF00B894);
  final Color editModeColor = const Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCustomers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    FirestoreService.instance.collection('AMC_user').snapshots().listen((
      snapshot,
    ) {
      if (mounted) {
        setState(() {
          _customers = snapshot.docs.map((doc) {
            final data = doc.data();
            return {...data, 'id': doc.id};
          }).toList();
          _filteredCustomers = _customers;
        });
      }
    });
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        _filteredCustomers = _customers
            .where(
              (customer) =>
                  (customer['name'] ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  (customer['email'] ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  (customer['Id'] ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();
      }
    });
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _usernameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _obscurePassword = true;
      _emailError = null;
      _phoneError = null;
      _isEditMode = false;
      _editingDocId = null;
      _originalEmail = null;
      _originalPhone = null;
    });
  }

  void _loadAccountForEdit(Map<String, dynamic> data, String docId) {
    setState(() {
      _isEditMode = true;
      _editingDocId = docId;
      _usernameController.text = data['name'] ?? '';
      _emailController.text = data['email'] ?? '';
      _phoneController.text = data['Phone Number'] ?? '';
      _originalEmail = data['email'] ?? '';
      _originalPhone = data['Phone Number'] ?? '';
      _passwordController.clear();
      _confirmPasswordController.clear();
    });

    _tabController.animateTo(0);
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      final querySnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  Future<String?> _validateEmailUnique(String? value) async {
    // Skip validation if we're in edit mode and email hasn't changed
    if (_isEditMode && value == _originalEmail) {
      setState(() {
        _emailError = null;
      });
      return null;
    }

    final basicValidation = _validateEmail(value);
    if (basicValidation != null) {
      setState(() {
        _emailError = null;
      });
      return basicValidation;
    }

    setState(() {
      _isCheckingEmail = true;
      _emailError = null;
    });

    try {
      final emailExists = await _checkEmailExists(value!);
      if (emailExists) {
        setState(() {
          _emailError = 'This email is already registered';
        });
        return _emailError;
      }
      setState(() {
        _emailError = null;
      });
      return null;
    } catch (e) {
      setState(() {
        _emailError = 'Error checking email availability';
      });
      return _emailError;
    } finally {
      setState(() {
        _isCheckingEmail = false;
      });
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  Future<String?> _validatePhoneNumberUnique(String? value) async {
    // Skip validation if we're in edit mode and phone hasn't changed
    if (_isEditMode && value == _originalPhone) {
      setState(() {
        _phoneError = null;
      });
      return null;
    }

    if (value == null || value.isEmpty) {
      setState(() {
        _phoneError = null;
      });
      return 'Please enter a phone number';
    }
    final numericRegex = RegExp(r'^\d{10}$');
    if (!numericRegex.hasMatch(value)) {
      setState(() {
        _phoneError = null;
      });
      return 'Phone number must be exactly 10 digits';
    }

    setState(() {
      _isCheckingPhone = true;
      _phoneError = null;
    });

    try {
      final querySnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .where('Phone Number', isEqualTo: value)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _phoneError = 'This phone number is already registered';
        });
        return _phoneError;
      } else {
        setState(() {
          _phoneError = null;
        });
        return null;
      }
    } catch (e) {
      setState(() {
        _phoneError = 'Error checking phone number';
      });
      return _phoneError;
    } finally {
      setState(() {
        _isCheckingPhone = false;
      });
    }
  }

  String? _validatePhoneNumberBasic(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a phone number';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
      return 'Phone number must be exactly 10 digits';
    }
    if (_phoneError != null) {
      return _phoneError;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    // In edit mode, password is optional
    if (_isEditMode && (value == null || value.isEmpty)) {
      return null;
    }

    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    // In edit mode, if password is empty, confirmation should also be empty
    if (_isEditMode && _passwordController.text.isEmpty) {
      return null;
    }

    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _deleteAccount(String docId, String userName) async {
    final bool? shouldDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return _buildDeleteConfirmationDialog(userName);
      },
    );

    if (shouldDelete == true) {
      await FirestoreService.instance
          .collection('AMC_user')
          .doc(docId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userName account deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCreatedDialog(
    String userName,
    String email,
    String password,
    String id,
  ) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Account Created',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'AMC ID: $id',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Name', userName),
            _buildDetailRow('Email', email),
            _buildDetailRow('Password', password),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      'CLOSE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      backgroundColor: primaryColor,
                    ),
                    child: const Text(
                      'CONFIRM',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final bool? shouldProceed = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return _buildConfirmationDialog();
        },
      );

      if (shouldProceed == true) {
        setState(() {
          _isLoading = true;
        });

        try {
          if (_isEditMode) {
            // Update existing account - only password can be changed
            final updateData = <String, dynamic>{};

            // Only update password if a new one is provided
            if (_passwordController.text.isNotEmpty) {
              updateData['password'] = _passwordController.text;
            }

            await FirestoreService.instance
                .collection('AMC_user')
                .doc(_editingDocId)
                .update(updateData);

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Account updated successfully!'),
                backgroundColor: accentColor,
              ),
            );

            _clearForm();
          } else {
            // Create new account (existing logic)
            final emailExists = await _checkEmailExists(_emailController.text);
            if (emailExists) {
              if (!mounted) return;
              setState(() {
                _emailError = 'This email is already registered';
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Email ${_emailController.text} is already registered!',
                  ),
                  backgroundColor: errorColor,
                ),
              );
              return;
            }

            final phoneQuery = await FirestoreService.instance
                .collection('AMC_user')
                .where('Phone Number', isEqualTo: _phoneController.text)
                .limit(1)
                .get();

            if (phoneQuery.docs.isNotEmpty) {
              if (!mounted) return;
              setState(() {
                _phoneError = 'This phone number is already registered';
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Phone number ${_phoneController.text} is already registered!',
                  ),
                  backgroundColor: errorColor,
                ),
              );
              return;
            }

            String newAmcId;
            try {
              final allDocs = await FirestoreService.instance
                  .collection('AMC_user')
                  .get();

              if (allDocs.docs.isEmpty) {
                newAmcId = 'AMC001';
              } else {
                int highestNumber = 0;
                for (var doc in allDocs.docs) {
                  final data = doc.data();
                  final id = data['Id'];
                  if (id != null && id.toString().startsWith('AMC')) {
                    try {
                      final numberPart = id.toString().substring(3);
                      final number = int.parse(numberPart);
                      if (number > highestNumber) {
                        highestNumber = number;
                      }
                    } catch (e) {
                      print('Skipping invalid ID format: $id');
                    }
                  }
                }
                newAmcId =
                    'AMC${(highestNumber + 1).toString().padLeft(3, '0')}';
              }
            } catch (e) {
              print('Error generating AMC ID: $e');
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final count = await FirestoreService.instance
                  .collection('AMC_user')
                  .get()
                  .then((snapshot) => snapshot.docs.length);
              newAmcId = 'AMC${(count + 1).toString().padLeft(3, '0')}';
            }

            await FirestoreService.instance
                .collection('AMC_user')
                .doc(newAmcId)
                .set({
                  'email': _emailController.text.toLowerCase().trim(),
                  'name': _usernameController.text,
                  'password': _passwordController.text,
                  'Phone Number': _phoneController.text,
                  'Id': newAmcId,
                  'createdAt': FieldValue.serverTimestamp(),
                });

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Account created successfully with ID: $newAmcId',
                ),
                backgroundColor: accentColor,
              ),
            );

            showDialog(
              context: context,
              builder: (BuildContext context) {
                return _buildAccountCreatedDialog(
                  _usernameController.text,
                  _emailController.text,
                  _passwordController.text,
                  newAmcId,
                );
              },
            );

            _clearForm();
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error ${_isEditMode ? 'updating' : 'creating'} account: $e',
              ),
              backgroundColor: errorColor,
            ),
          );
          print('Detailed error: $e');
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    }
  }

  Widget _buildConfirmationDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isEditMode ? Icons.edit_outlined : Icons.account_circle_outlined,
              size: 48,
              color: _isEditMode ? editModeColor : primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _isEditMode
                  ? 'Confirm Account Update'
                  : 'Confirm Account Creation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isEditMode ? editModeColor : primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEditMode
                  ? 'Are you sure you want to update this account? Only password will be changed.'
                  : 'Are you sure you want to create this account?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      side: BorderSide(
                        color: _isEditMode ? editModeColor : primaryColor,
                      ),
                    ),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isEditMode ? editModeColor : primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      backgroundColor: _isEditMode
                          ? editModeColor
                          : primaryColor,
                    ),
                    child: Text(
                      _isEditMode ? 'UPDATE' : 'CONFIRM',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteConfirmationDialog(String userName) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: errorColor),
            const SizedBox(height: 16),
            Text(
              'Delete Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: errorColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to delete $userName\'s account?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      backgroundColor: errorColor,
                    ),
                    child: const Text(
                      'DELETE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Refresh colors from ThemeService
    primaryColor = ThemeService.instance.primaryColor;
    secondaryColor = ThemeService.instance.secondaryColor;
    backgroundColor = ThemeService.instance.backgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'AMC Customer Management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCustomerForm(), _buildCustomerDirectory()],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: TabBar(
            controller: _tabController,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(width: 3, color: primaryColor),
              insets: const EdgeInsets.symmetric(horizontal: 48),
            ),
            labelColor: primaryColor,
            unselectedLabelColor: textLightColor,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.person_add_rounded), text: 'Add Customer'),
              Tab(icon: Icon(Icons.people_alt_rounded), text: 'Directory'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditMode ? 'Edit Customer' : 'Add New Customer',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isEditMode
                  ? 'Update information for this account.'
                  : 'Create a new account for your AMC customers.',
              style: TextStyle(
                fontSize: 16,
                color: textLightColor,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),
            _buildFormField(
              controller: _usernameController,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter name';
                if (value.length < 3) return 'Name too short';
                return null;
              },
              enabled: !_isEditMode,
            ),
            const SizedBox(height: 20),
            _buildEmailFieldRedesigned(),
            const SizedBox(height: 20),
            _buildPhoneNumberFieldRedesigned(),
            const SizedBox(height: 20),
            _buildFormField(
              controller: _passwordController,
              label: _isEditMode ? 'New Password (Optional)' : 'Password',
              icon: Icons.lock_outline_rounded,
              isPasswordField: true,
              validator: _validatePassword,
            ),
            const SizedBox(height: 20),
            _buildFormField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.shield_outlined,
              isPasswordField: true,
              validator: _validateConfirmPassword,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEditMode ? 'Update Account' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: _isEditMode ? _cancelEdit : _clearForm,
                child: Text(
                  _isEditMode ? 'Cancel Edit' : 'Clear Form',
                  style: TextStyle(
                    color: _isEditMode ? errorColor : textLightColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      _editingDocId = null;
      _clearForm();
    });
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPasswordField = false,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPasswordField && _obscurePassword,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: textLightColor,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: primaryColor),
          suffixIcon: isPasswordField
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: textLightColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : backgroundColor.withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildEmailFieldRedesigned() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        enabled: !_isEditMode,
        decoration: InputDecoration(
          labelText: 'Email Address',
          labelStyle: TextStyle(
            color: textLightColor,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(Icons.alternate_email_rounded, color: primaryColor),
          suffixIcon: _isCheckingEmail
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: !_isEditMode
              ? Colors.white
              : backgroundColor.withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && !_isEditMode) {
            _validateEmailUnique(value);
          }
        },
        validator: _validateEmail,
      ),
    );
  }

  Widget _buildPhoneNumberFieldRedesigned() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.number,
        enabled: !_isEditMode,
        decoration: InputDecoration(
          labelText: 'Phone Number',
          labelStyle: TextStyle(
            color: textLightColor,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(Icons.phone_iphone_rounded, color: primaryColor),
          suffixIcon: _isCheckingPhone
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: !_isEditMode
              ? Colors.white
              : backgroundColor.withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          counterText: '',
        ),
        maxLength: 10,
        onChanged: (value) {
          if (value.length == 10 && !_isEditMode) {
            _validatePhoneNumberUnique(value);
          }
        },
        validator: _validatePhoneNumberBasic,
      ),
    );
  }

  Widget _buildCustomerDirectory() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Directory',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterCustomers,
                  decoration: InputDecoration(
                    hintText: 'Search by name or AMC ID...',
                    prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredCustomers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search_rounded,
                        size: 64,
                        color: textLightColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No customers found',
                        style: TextStyle(
                          fontSize: 18,
                          color: textLightColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = _filteredCustomers[index];
                    final String name = customer['name'] ?? 'No Name';
                    final String id = customer['Id'] ?? 'No ID';
                    final String email = customer['email'] ?? 'No Email';
                    final String phone = customer['Phone Number'] ?? 'No Phone';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: primaryColor.withOpacity(0.1),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: $id',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textLightColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textLightColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: primaryColor.withOpacity(0.7),
                                  ),
                                  onPressed: () => _loadAccountForEdit(
                                    customer,
                                    customer['id'],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: errorColor.withOpacity(0.7),
                                  ),
                                  onPressed: () =>
                                      _deleteAccount(customer['id'], name),
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
    );
  }
}
