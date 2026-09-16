import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_dashboard.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

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
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
              onPressed: () => _onWillPop(),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Engineer Management',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Manage your service team',
                style: TextStyle(
                  fontSize: 12,
                  color: textLightColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          centerTitle: false,
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildEngineerForm(), _buildEngineersList()],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                final selectedIndex = _tabController.index;

                return SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _tabController.animateTo(0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_add_rounded,
                                size: 22,
                                color: selectedIndex == 0
                                    ? primaryColor
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add Engineer',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selectedIndex == 0
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: selectedIndex == 0
                                      ? primaryColor
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: const Color(0xFFE2E8F0),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _tabController.animateTo(1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_alt_rounded,
                                size: 22,
                                color: selectedIndex == 1
                                    ? primaryColor
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Directory',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selectedIndex == 1
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: selectedIndex == 1
                                      ? primaryColor
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEngineerForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    primaryColor.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit_note_rounded : Icons.person_add_alt_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Engineer' : 'Add New Engineer',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          _isEditing
                              ? 'Update information for this account'
                              : 'Create a new account for your service team',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Form Fields Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildFormField(
                      controller: _usernameController,
                      label: 'Username',
                      icon: Icons.person_outline_rounded,
                      hint: 'Enter engineer username',
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter a username'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildFormField(
                      controller: _passwordController,
                      label: _isEditing ? 'New Password (Optional)' : 'Password',
                      icon: Icons.lock_outline_rounded,
                      hint: _isEditing ? 'Leave blank to keep current password' : 'Create a strong password',
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
                      hint: 'Re-enter your password',
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
                        child: Row(
                          children: [
                            Icon(
                              _confirmPasswordMessageColor == successColor 
                                  ? Icons.check_circle_outline 
                                  : Icons.error_outline,
                              color: _confirmPasswordMessageColor,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _confirmPasswordMessage,
                              style: TextStyle(
                                color: _confirmPasswordMessageColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    _buildFormField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.alternate_email_rounded,
                      hint: 'engineer@example.com',
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
                      hint: 'Enter 10-digit mobile number',
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
                      hint: 'e.g., AC Repair, Plumbing, Electrical',
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter a specialization'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _isEditing ? _cancelEdit : _clearForm,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  _isEditing ? 'Cancel Edit' : 'Clear Form',
                  style: TextStyle(
                    color: _isEditing ? errorColor : textLightColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool isPasswordField = false,
    Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPasswordField ? !_passwordVisible : obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: textLightColor.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                icon,
                color: primaryColor,
                size: 20,
              ),
              counterText: "",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
        ),
      ],
    );
  }

  Widget _buildEngineersList() {
    return Column(
      children: [
        // Top Domain Hero Banner Card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.18),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.people_alt_rounded,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Engineer Directory',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_filteredEngineers.length} Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'View, edit, and manage your service engineers',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: primaryColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search Bar Container
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterEngineers,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search by name or specialization...',
                hintStyle: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        Expanded(
          child: _filteredEngineers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person_search_rounded,
                          size: 44,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'No engineers found'
                            : 'No results for "${_searchController.text}"',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try adjusting your search criteria',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filteredEngineers.length,
                  itemBuilder: (context, index) {
                    final engineer = _filteredEngineers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _loadForEdit(engineer),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor,
                                        primaryColor.withValues(alpha: 0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      (engineer['Username'] ?? 'U')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            engineer['Username'] ?? 'No Name',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              engineer['Specialization'] ?? 'Service Engineer',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.email_outlined,
                                            size: 13,
                                            color: const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              engineer['Email'] ?? 'No Email',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone_android_rounded,
                                            size: 13,
                                            color: const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            engineer['Phone'] ?? 'No Phone',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _loadForEdit(engineer),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.edit_rounded,
                                          color: primaryColor,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _deleteEngineer(engineer['id']),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: errorColor.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          color: errorColor,
                                          size: 18,
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
          
          // Check subscription limits
          final tenantId = ThemeService.instance.databaseName;
          final appId = ThemeService.instance.appName;
          final actualAppId = await FirestoreService.instance.getActiveSubscriptionAppId(
            tenantId: tenantId,
            appId: appId,
          );
          
          final subSnapshot = await FirestoreService.instance
              .subscriptionsRef(tenantId: tenantId, appId: actualAppId)
              .limit(1)
              .get();
              
          if (subSnapshot.docs.isNotEmpty) {
            final subData = subSnapshot.docs.first.data();
            final limits = subData['limits'] as Map<String, dynamic>?;
            final maxEngineers = limits?['maxEngineers'] as int?;
            
            if (maxEngineers != null && _engineers.length >= maxEngineers) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Subscription limit reached. You can only create up to $maxEngineers engineers.'),
                    backgroundColor: errorColor,
                  ),
                );
              }
              setState(() {
                _isLoading = false;
              });
              return;
            }
          }

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
    _tabController.dispose();
    super.dispose();
  }
}