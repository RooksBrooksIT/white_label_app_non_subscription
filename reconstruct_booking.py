import re

with open('lib/frontend/screens/engineer_dashboard_page.dart', 'r') as f:
    content = f.read()

# Find EngineerPage class and its state
match = re.search(r'(class EngineerPage extends StatefulWidget \{.*)', content, re.DOTALL)
if not match:
    print("Could not find EngineerPage")
    exit(1)

engineer_page_content = match.group(1)

# Rename to BookingPage
engineer_page_content = engineer_page_content.replace('class EngineerPage extends', 'class BookingPage extends')
engineer_page_content = engineer_page_content.replace('class _EngineerPageState extends State<EngineerPage>', 'class _BookingPageState extends State<BookingPage>')
engineer_page_content = engineer_page_content.replace('_EngineerPageState createState()', '_BookingPageState createState()')
engineer_page_content = engineer_page_content.replace('EngineerPage({', 'BookingPage({')
engineer_page_content = engineer_page_content.replace('State<EngineerPage>', 'State<BookingPage>')

# We need to change the build method to just return _buildDashboardView()
# The build method in engineer_dashboard_page.dart starts with:
#   @override
#   Widget build(BuildContext context) {
#     return AnnotatedRegion<SystemUiOverlayStyle>(
# ... up to ...
#         bottomNavigationBar: _buildBottomNavigationBar(),
#       ),
#     );
#   }
build_pattern = re.compile(r'  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}\n\n  Widget _buildTopSection', re.DOTALL)
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

engineer_page_content = build_pattern.sub(new_build, engineer_page_content)

# Remove the bottom navigation, top section, profile view, location view etc.
# We don't necessarily have to remove them right now, as long as the build method doesn't call them, they are just dead code which is fine for fixing the bug immediately. 
# But we can try to remove them.

with open('lib/frontend/engineer/screens/booking_page.dart', 'a') as f:
    f.write("\n\n")
    f.write(engineer_page_content)

print("Appended BookingPage to booking_page.dart")

