import os
import glob

def replace_in_file(filepath):
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        original_content = content
        
        content = content.replace("import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart';", 
                                  "import 'package:subscription_rooks_app/frontend/engineer/screens/engineer_main_layout.dart';")
        content = content.replace("EngineerPage(", "EngineerMainLayout(")
        
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

