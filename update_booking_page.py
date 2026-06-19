import re

with open('lib/frontend/engineer/screens/booking_page.dart', 'r') as f:
    content = f.read()

# Replace the build method
build_method_pattern = re.compile(
    r'  @override\n  Widget build\(BuildContext context\) \{.*?\n  Widget _buildTopSection',
    re.DOTALL
)

new_build_method = """  @override
  Widget build(BuildContext context) {
    return _buildBookingsView();
  }

  Widget _buildTopSection"""

content = build_method_pattern.sub(new_build_method, content)

with open('lib/frontend/engineer/screens/booking_page.dart', 'w') as f:
    f.write(content)

