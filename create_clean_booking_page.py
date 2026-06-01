import re
import os

# Read from engineer_dashboard_page.dart
with open('lib/frontend/screens/engineer_dashboard_page.dart', 'r') as f:
    content = f.read()

# 1. Strip classes we moved to models/widgets
classes_to_remove = [
    r'class AdminDetails \{.*?\n\}\n',
    r'class ProfessionalTheme \{.*?\n\}\n',
    r'class ProfessionalAnimations \{.*?\n\}\n',
    r'class ProfessionalLoadingSpinner extends StatelessWidget \{.*?\n\}\n',
    r'class ProfessionalEmptyState extends StatelessWidget \{.*?\n\}\n',
    r'class ProfessionalNavigationDrawer extends StatelessWidget \{.*?\n\}\n'
]

for pattern in classes_to_remove:
    content = re.sub(pattern, '', content, flags=re.DOTALL)

# 2. Rename EngineerPage to BookingPage
content = content.replace('class EngineerPage extends', 'class BookingPage extends')
content = content.replace('class _EngineerPageState extends State<EngineerPage>', 'class _BookingPageState extends State<BookingPage>')
content = content.replace('_EngineerPageState createState() => _EngineerPageState();', '_BookingPageState createState() => _BookingPageState();')
content = content.replace('EngineerPage({', 'BookingPage({')
content = content.replace('State<EngineerPage>', 'State<BookingPage>')
content = content.replace('_EngineerPageState', '_BookingPageState')
content = content.replace('EngineerPage', 'BookingPage')

# 3. Replace the build method of BookingPage
build_pattern = re.compile(r'  @override\n  Widget build\(BuildContext context\) \{.*?\n  Widget _buildTopSection', re.DOTALL)
new_build = """  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: ProfessionalLoadingSpinner());
    }
    
    if (!_isCheckedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_late, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Please Check-In to view your bookings',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isCheckingIn ? null : _handleCheckIn,
              icon: _isCheckingIn 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login),
              label: Text(_isCheckingIn ? 'Checking In...' : 'Check In Now'),
            ),
          ],
        ),
      );
    }

    return _buildDashboardView();
  }

  Widget _buildTopSection"""

content = build_pattern.sub(new_build, content)

# 4. Add proper imports
imports_to_add = """
import '../models/admin_details.dart';
import '../models/engineer_theme.dart';
import '../widgets/engineer_widgets.dart';
"""
# Insert after the first import
content = re.sub(r'(import .*?;)', r'\1\n' + imports_to_add.strip() + '\n', content, count=1)

# Write to booking_page.dart
with open('lib/frontend/engineer/screens/booking_page.dart', 'w') as f:
    f.write(content)

print("Created clean booking_page.dart")
