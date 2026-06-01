import os

replacements = {
    "import 'package:subscription_rooks_app/frontend/screens/engineer_location_screen.dart';": "import 'package:subscription_rooks_app/frontend/engineer/screens/location_page.dart';",
    "import 'package:subscription_rooks_app/frontend/screens/engineer_barcode_scanner_page.dart';": "import 'package:subscription_rooks_app/frontend/engineer/screens/barcode_scanner_page.dart';",
    "import 'package:subscription_rooks_app/frontend/screens/engineer_barcode_identifier.dart';": "import 'package:subscription_rooks_app/frontend/engineer/screens/barcode_identifier_page.dart';",
    "import 'package:subscription_rooks_app/frontend/screens/engineer_login_page.dart';": "import 'package:subscription_rooks_app/frontend/engineer/screens/login_page.dart';",
    "import 'package:subscription_rooks_app/frontend/screens/engineer_attendance_screen.dart';": "import 'package:subscription_rooks_app/frontend/engineer/screens/attendance_page.dart';",
    
    # Also relative imports might exist in engineer_main_layout.dart
    "import '../../screens/engineer_location_screen.dart';": "import 'location_page.dart';",
    "import '../../screens/engineer_barcode_scanner_page.dart';": "import 'barcode_scanner_page.dart';",
    "import '../../screens/engineer_barcode_identifier.dart';": "import 'barcode_identifier_page.dart';",
    "import '../../screens/engineer_login_page.dart';": "import 'login_page.dart';",
    "import '../../screens/engineer_attendance_screen.dart';": "import 'attendance_page.dart';"
}

def replace_in_file(filepath):
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        original_content = content
        
        for old, new in replacements.items():
            content = content.replace(old, new)
        
        if content != original_content:
            with open(filepath, 'w') as f:
                f.write(content)
            print(f"Updated {filepath}")
    except Exception as e:
        print(f"Error processing {filepath}: {e}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            replace_in_file(os.path.join(root, file))

