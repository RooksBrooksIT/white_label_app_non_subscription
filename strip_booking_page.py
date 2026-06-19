import re

with open('lib/frontend/engineer/screens/booking_page.dart', 'r') as f:
    content = f.read()

# Remove AdminDetails class
content = re.sub(r'class AdminDetails \{.*?\}\n\}\n', '', content, flags=re.DOTALL)

# Remove ProfessionalTheme class
content = re.sub(r'class ProfessionalTheme \{.*?\}\n\}\n', '', content, flags=re.DOTALL)

# Remove ProfessionalAnimations class
content = re.sub(r'class ProfessionalAnimations \{.*?\}\n\}\n', '', content, flags=re.DOTALL)

# Remove ProfessionalLoadingSpinner class
content = re.sub(r'class ProfessionalLoadingSpinner extends StatelessWidget \{.*?\n\}\n', '', content, flags=re.DOTALL)

# Remove ProfessionalEmptyState class
content = re.sub(r'class ProfessionalEmptyState extends StatelessWidget \{.*?\n\}\n', '', content, flags=re.DOTALL)

# Remove ProfessionalNavigationDrawer class
content = re.sub(r'class ProfessionalNavigationDrawer extends StatelessWidget \{.*?\n\}\n', '', content, flags=re.DOTALL)

# Add imports for these models at the top
imports = """
import '../models/admin_details.dart';
import '../models/engineer_theme.dart';
import '../widgets/engineer_widgets.dart';
"""
content = imports + content

with open('lib/frontend/engineer/screens/booking_page.dart', 'w') as f:
    f.write(content)

