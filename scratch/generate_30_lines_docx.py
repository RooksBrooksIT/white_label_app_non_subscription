import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls

def create_30_line_docx(output_path):
    doc = docx.Document()
    
    # 1 inch margins
    for section in doc.sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.9)
        section.right_margin = Inches(0.9)

    COLOR_PRIMARY = RGBColor(30, 58, 138)    # Deep Navy
    COLOR_SECONDARY = RGBColor(37, 99, 235)  # Blue
    COLOR_TEXT = RGBColor(31, 41, 55)        # Charcoal
    COLOR_ACCENT = RGBColor(217, 119, 6)     # Amber

    # Title
    p_title = doc.add_paragraph()
    p_title.paragraph_format.space_before = Pt(0)
    p_title.paragraph_format.space_after = Pt(2)
    r_sub = p_title.add_run("SERVNEX • 30-LINE EXECUTIVE SUMMARY\n")
    r_sub.font.name = "Segoe UI"
    r_sub.font.size = Pt(10)
    r_sub.font.bold = True
    r_sub.font.color.rgb = COLOR_ACCENT

    r_title = p_title.add_run("The ServNex Story: Modern Field Service in 30 Lines")
    r_title.font.name = "Segoe UI"
    r_title.font.size = Pt(18)
    r_title.font.bold = True
    r_title.font.color.rgb = COLOR_PRIMARY

    # Subtitle
    p_desc = doc.add_paragraph()
    p_desc.paragraph_format.space_before = Pt(0)
    p_desc.paragraph_format.space_after = Pt(12)
    r_desc = p_desc.add_run("A concise, customer-friendly overview of problems, solutions, workflows, and business value.")
    r_desc.font.name = "Segoe UI"
    r_desc.font.size = Pt(10.5)
    r_desc.font.italic = True
    r_desc.font.color.rgb = RGBColor(100, 116, 139)

    lines = [
        ("01", "Every service business struggles with lost customer calls, misplaced paper slips, and scattered requests."),
        ("02", "Managers face a daily operational blind spot with zero real-time visibility into technician field locations."),
        ("03", "Traditional attendance relies on unverified honor systems, causing proxy check-ins and untracked hours."),
        ("04", "Annual Maintenance Contracts (AMCs) frequently expire unnoticed, quietly draining predictable recurring revenue."),
        ("05", "Technicians often service the wrong machines due to mixed-up serial numbers and missing service records."),
        ("06", "Delayed paper receipts and manual billing create customer payment disputes and cash flow bottlenecks."),
        ("07", "Most software forces businesses to display generic third-party logos instead of their own brand identity."),
        ("08", "ServNex solves these challenges by uniting management, field engineers, and customers on one smart cloud platform."),
        ("09", "As a multi-tenant solution, every organization gets a private, secure database with instant real-time synchronization."),
        ("10", "The platform is fully white-labeled, letting you showcase your company logo, custom colors, and unique brand name."),
        ("11", "Administrators gain an executive command center showing live pending tickets, active workforce, and system alerts."),
        ("12", "Smart dispatching enables managers to assign service or delivery tickets to the nearest technician in seconds."),
        ("13", "Live GPS fleet radar displays real-time technician movements, auto-follow tracking, and historical travel paths."),
        ("14", "Mobile attendance is strictly geofenced, ensuring engineers can only check in when physically on site."),
        ("15", "The dedicated AMC hub tracks equipment contracts, schedules preventive visits, and triggers automated renewal alerts."),
        ("16", "Integrated barcode and QR scanning lets technicians verify equipment serial numbers and repair histories via camera."),
        ("17", "Field engineers carry a pocket companion app that delivers instant push notifications with job directions and fault details."),
        ("18", "Technicians update job stages from In Progress to Completed while uploading mandatory before-and-after photo proof."),
        ("19", "Doorstep digital payments and customer signatures are recorded directly on the technician's mobile device."),
        ("20", "Customers enjoy an intuitive self-service portal to raise service tickets with photos in just a few taps."),
        ("21", "A live ride-share style tracker gives customers complete peace of mind with real-time stage updates."),
        ("22", "Instant push alerts keep customers informed when an engineer is assigned, en route, and finished."),
        ("23", "Verified digital service summaries, invoices, and warranty cards are instantly accessible on the customer's phone."),
        ("24", "A built-in 5-star rating system provides immediate customer feedback to help maintain exceptional service standards."),
        ("25", "Automated PDF reporting generates audit-ready attendance logs, staff productivity scores, and GST-compliant invoices."),
        ("26", "Businesses using ServNex reduce ticket resolution time by 40% to 50% through rapid, intelligent dispatching."),
        ("27", "Geofenced tracking achieves 100% attendance integrity, eliminating payroll leakage from unverified hours."),
        ("28", "Proactive contract notifications boost Annual Maintenance Contract renewal rates by over 30%."),
        ("29", "Flexible subscription tiers scale seamlessly from small local teams to large multi-branch enterprises."),
        ("30", "ServNex transforms daily operational friction into an automated, profitable, and customer-delighting service machine.")
    ]

    for num, text in lines:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(1.5)
        p.paragraph_format.space_after = Pt(2.5)
        p.paragraph_format.line_spacing = 1.15
        
        r_num = p.add_run(f"{num}. ")
        r_num.font.name = "Segoe UI"
        r_num.font.size = Pt(10)
        r_num.font.bold = True
        r_num.font.color.rgb = COLOR_SECONDARY

        r_text = p.add_run(text)
        r_text.font.name = "Segoe UI"
        r_text.font.size = Pt(10)
        r_text.font.color.rgb = COLOR_TEXT

    doc.save(output_path)
    print("30-line docx successfully generated.")

if __name__ == "__main__":
    out_file = r"d:\Rooks Tech\white_label_non_subscription\ServNex_30_Line_Summary.docx"
    create_30_line_docx(out_file)
