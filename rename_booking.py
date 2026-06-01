import re

with open('lib/frontend/engineer/screens/booking_page.dart', 'r') as f:
    content = f.read()

content = content.replace('class EngineerPage extends', 'class BookingPage extends')
content = content.replace('class _EngineerPageState extends', 'class _BookingPageState extends')
content = content.replace('_EngineerPageState createState()', '_BookingPageState createState()')
content = content.replace('EngineerPage({', 'BookingPage({')
content = content.replace('State<EngineerPage>', 'State<BookingPage>')

with open('lib/frontend/engineer/screens/booking_page.dart', 'w') as f:
    f.write(content)
