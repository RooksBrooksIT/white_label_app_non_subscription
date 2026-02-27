import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_dashboard.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class EngineerManagementPage extends StatefulWidget {
  static Route route() =>
      MaterialPageRoute(builder: (_) => EngineerManagementPage());
  const EngineerManagementPage({super.key});

  @override
  _EngineerManagementPageState createState() => _EngineerManagementPageState();
}

class _EngineerManagementPageState extends State<EngineerManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isEditing = false;
  String? _editingEngineerId;
  Future<bool> _onWillPop() async {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => admindashboard()),
      (Route<dynamic> route) => false,
    );
    return false;
  }

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _passwordVisible = false;
  List<Map<String, dynamic>> _engineers = [];

  String _confirmPasswordMessage = '';
  Color _confirmPasswordMessageColor = Colors.transparent;

  // Updated professional color scheme
  // Updated professional color scheme
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get secondaryColor => Theme.of(context).primaryColorLight;
  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get errorColor => Theme.of(context).colorScheme.error;
  Color get successColor => Colors.green;
  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  Color get textLightColor => Theme.of(context).hintColor;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredEngineers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchEngineers();
  }

  void _loadForEdit(Map<String, dynamic> engineer) {
    setState(() {
      _isEditing = true;
      _editingEngineerId = engineer['id'];
      _usernameController.text = engineer['Username'] ?? '';
      _emailController.text = engineer['Email'] ?? '';
      _phoneController.text = engineer['Phone'] ?? '';
      _specializationController.text = engineer['Specialization'] ?? '';
      // Clear password for security, require re-entry or keep as is?
      // User says "update account information", persisting modified values.
      // Usually, we don't load the password. If it's empty, we might skip updating it.
      _passwordController.clear();
      _confirmPasswordController.clear();
      _confirmPasswordMessage = '';
    });
    _tabController.animateTo(0);
  }

  void _cancelEdit() {
    _clearForm();
    setState(() {
      _isEditing = false;
      _editingEngineerId = null;
    });
  }

  void _filterEngineers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredEngineers = _engineers;
      } else {
        _filteredEngineers = _engineers
            .where(
              (engineer) =>
                  (engineer['Username'] ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  (engineer['Specialization'] ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA), // Soft background
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => _onWillPop(),
          ),
          title: Text(
            'Engineer Management',
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
          children: [_buildEngineerForm(), _buildEngineersList()],
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
                Tab(icon: Icon(Icons.person_add_rounded), text: 'Add New'),
                Tab(icon: Icon(Icons.dashboard_rounded), text: 'Directory'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEngineerForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Engineer' : 'Add New Engineer',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isEditing
                  ? 'Update information for this account.'
                  : 'Create a new account for your service team.',
              style: TextStyle(
                fontSize: 16,
                color: textLightColor,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),
            _buildFormField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.person_outline_rounded,
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Please enter a username'
                  : null,
            ),
            const SizedBox(height: 20),
            _buildFormField(
              controller: _passwordController,
              label: _isEditing ? 'New Password (Optional)' : 'Password',
              icon: Icons.lock_outline_rounded,
              isPasswordField: true,
              validator: (value) {
                if (!_isEditing && (value == null || value.isEmpty)) {
                  return 'Please enter a password';
                }
                if (value != null && value.isNotEmpty && value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
              onChanged: (value) => _validateConfirmPassword(),
            ),
            const SizedBox(height: 20),
            _buildFormField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.shield_outlined,
              isPasswordField: true,
              validator: (value) {
                if (_passwordController.text.isNotEmpty &&
                    value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
              onChanged: (value) => _validateConfirmPassword(),
            ),
            if (_confirmPasswordMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 8),
                child: Text(
                  _confirmPasswordMessage,
                  style: TextStyle(
                    color: _confirmPasswordMessageColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _buildFormField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an email';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildFormField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_iphone_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a phone number';
                }
                if (value.length != 10) return 'Phone number must be 10 digits';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildFormField(
              controller: _specializationController,
              label: 'Specialization',
              icon: Icons.architecture_rounded,
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Please enter a specialization'
                  : null,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          _addEngineer();
                        }
                      },
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
                        _isEditing ? 'Update Account' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: _isEditing ? _cancelEdit : _clearForm,
                child: Text(
                  _isEditing ? 'Cancel Edit' : 'Discard Changes',
                  style: TextStyle(
                    color: _isEditing ? errorColor : textLightColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100), // Padding for bottom navbar
          ],
        ),
      ),
    );
  }

  void _validateConfirmPassword() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    setState(() {
      if (confirm.isEmpty) {
        _confirmPasswordMessage = '';
        _confirmPasswordMessageColor = Colors.transparent;
      } else if (password == confirm) {
        _confirmPasswordMessage = 'Passwords match';
        _confirmPasswordMessageColor = successColor;
      } else {
        _confirmPasswordMessage = 'Passwords do not match';
        _confirmPasswordMessageColor = errorColor;
      }
    });
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool isPasswordField = false,
    Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
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
        obscureText: isPasswordField ? !_passwordVisible : obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: textLightColor.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(
            icon,
            color: primaryColor.withOpacity(0.7),
            size: 22,
          ),
          counterText: "",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: primaryColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          suffixIcon: isPasswordField
              ? IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: textLightColor,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                )
              : null,
        ),
        validator: validator,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildEngineersList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Directory',
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
                  onChanged: _filterEngineers,
                  decoration: InputDecoration(
                    hintText: 'Search by name or specialization...',
                    hintStyle: TextStyle(color: textLightColor, fontSize: 15),
                    prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredEngineers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search_rounded,
                        size: 80,
                        color: textLightColor.withOpacity(0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'No engineers found'
                            : 'No results for "${_searchController.text}"',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textLightColor,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filteredEngineers.length,
                  itemBuilder: (context, index) {
                    final engineer = _filteredEngineers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            // Quick details or edit
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      (engineer['Username'] ?? 'U')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        engineer['Username'] ?? 'No Name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 17,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        engineer['Specialization'] ??
                                            'No Specialization',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: textLightColor,
                                          fontWeight: FontWeight.w500,
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
                                      onPressed: () => _loadForEdit(engineer),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: errorColor.withOpacity(0.7),
                                      ),
                                      onPressed: () =>
                                          _deleteEngineer(engineer['id']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _fetchEngineers() async {
    try {
      final querySnapshot = await FirestoreService.instance
          .collection('EngineerLogin')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _engineers = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'Username': data['Username'],
            'Email': data['Email'],
            'Phone': data['Phone'],
            'Specialization': data['Specialization'],
          };
        }).toList();
        _filteredEngineers = _engineers;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch engineers: ${error.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _addEngineer() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final collection = FirestoreService.instance.collection(
          'EngineerLogin',
        );

        if (_isEditing && _editingEngineerId != null) {
          // Update existing
          final data = {
            'Username': _usernameController.text,
            'Email': _emailController.text,
            'Phone': _phoneController.text,
            'Specialization': _specializationController.text,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (_passwordController.text.isNotEmpty) {
            data['Password'] = _passwordController.text;
          }

          await collection.doc(_editingEngineerId).update(data);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Engineer updated successfully!'),
              backgroundColor: successColor,
            ),
          );
        } else {
          // Create new logic
          final existingUserQuery = await collection
              .where('Username', isEqualTo: _usernameController.text)
              .get();

          if (existingUserQuery.docs.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Username already exists'),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }

          final now = DateTime.now();
          final formattedDate =
              '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}';
          final docId = '${_usernameController.text}_$formattedDate';

          await collection.doc(docId).set({
            'Username': _usernameController.text,
            'Password': _passwordController.text,
            'Email': _emailController.text,
            'Phone': _phoneController.text,
            'Specialization': _specializationController.text,
            'createdAt': FieldValue.serverTimestamp(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Engineer created successfully!'),
              backgroundColor: successColor,
            ),
          );
        }

        _isEditing ? _cancelEdit() : _clearForm();
        _fetchEngineers();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Operation failed: ${error.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteEngineer(String? id) async {
    if (id == null) return;

    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Confirm Delete', style: TextStyle(color: textColor)),
        content: Text(
          'Are you sure you want to delete this engineer?',
          style: TextStyle(color: textLightColor),
        ),
        backgroundColor: cardColor,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: textLightColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: errorColor)),
          ),
        ],
      ),
    );

    if (confirmDelete) {
      try {
        await FirestoreService.instance
            .collection('EngineerLogin')
            .doc(id)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Engineer deleted successfully'),
            backgroundColor: successColor,
          ),
        );

        _fetchEngineers();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete engineer: ${error.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  void _clearForm() {
    FocusScope.of(context).unfocus();
    _usernameController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _emailController.clear();
    _phoneController.clear();
    _specializationController.clear();
    setState(() {
      _confirmPasswordMessage = '';
      _confirmPasswordMessageColor = Colors.transparent;
      _passwordVisible = false;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
