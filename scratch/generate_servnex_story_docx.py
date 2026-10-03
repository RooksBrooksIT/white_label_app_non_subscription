import os
import sys
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import parse_xml, OxmlElement
from docx.oxml.ns import nsdecls, qn

def create_servnex_document(output_path):
    doc = docx.Document()
    
    # ── Page Margins (1 inch all around) ──
    for section in doc.sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)
        section.page_width = Inches(8.5)
        section.page_height = Inches(11.0)

    # ── Colors ──
    COLOR_PRIMARY = RGBColor(30, 58, 138)     # Deep Navy (#1E3A8A)
    COLOR_SECONDARY = RGBColor(37, 99, 235)   # Tech Blue (#2563EB)
    COLOR_ACCENT = RGBColor(217, 119, 6)      # Amber Gold (#D97706)
    COLOR_TEXT = RGBColor(31, 41, 55)         # Charcoal Dark (#1F2937)
    COLOR_MUTED = RGBColor(100, 116, 139)     # Slate Muted (#64748B)
    COLOR_SUCCESS = RGBColor(16, 185, 129)    # Emerald (#10B981)

    HEX_PRIMARY = "1E3A8A"
    HEX_SECONDARY = "2563EB"
    HEX_ACCENT = "D97706"
    HEX_BG_LIGHT = "F8FAFC"
    HEX_BORDER = "CBD5E1"
    HEX_CALLOUT_BG = "EFF6FF"
    HEX_CALLOUT_BORDER = "2563EB"
    HEX_WARN_BG = "FEF3C7"
    HEX_WARN_BORDER = "D97706"
    HEX_SUCCESS_BG = "ECFDF5"
    HEX_SUCCESS_BORDER = "10B981"

    # ── Helper XML functions ──
    def set_cell_background(cell, hex_color):
        shading_elm = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
        cell._tc.get_or_add_tcPr().append(shading_elm)

    def set_cell_margins(cell, top=140, bottom=140, left=180, right=180):
        tcPr = cell._tc.get_or_add_tcPr()
        tcMar = parse_xml(
            f'<w:tcMar {nsdecls("w")}>'
            f'  <w:top w:w="{top}" w:type="dxa"/>'
            f'  <w:bottom w:w="{bottom}" w:type="dxa"/>'
            f'  <w:left w:w="{left}" w:type="dxa"/>'
            f'  <w:right w:w="{right}" w:type="dxa"/>'
            f'</w:tcMar>'
        )
        tcPr.append(tcMar)

    def set_callout_borders(cell, border_color):
        tcPr = cell._tc.get_or_add_tcPr()
        borders = parse_xml(
            f'<w:tcBorders {nsdecls("w")}>'
            f'  <w:top w:val="none"/>'
            f'  <w:left w:val="single" w:sz="36" w:space="0" w:color="{border_color}"/>'
            f'  <w:bottom w:val="none"/>'
            f'  <w:right w:val="none"/>'
            f'</w:tcBorders>'
        )
        tcPr.append(borders)

    def set_table_borders(table, border_color="CBD5E1"):
        tblPr = table._tbl.tblPr
        borders = parse_xml(
            f'<w:tblBorders {nsdecls("w")}>'
            f'  <w:top w:val="single" w:sz="8" w:space="0" w:color="{border_color}"/>'
            f'  <w:left w:val="none"/>'
            f'  <w:bottom w:val="single" w:sz="10" w:space="0" w:color="{border_color}"/>'
            f'  <w:right w:val="none"/>'
            f'  <w:insideH w:val="single" w:sz="4" w:space="0" w:color="{border_color}"/>'
            f'  <w:insideV w:val="none"/>'
            f'</w:tblBorders>'
        )
        tblPr.append(borders)

    def add_callout(text, title=None, border_color=HEX_CALLOUT_BORDER, bg_color=HEX_CALLOUT_BG):
        table = doc.add_table(rows=1, cols=1)
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        table.autofit = False
        table.columns[0].width = Inches(6.5)
        
        cell = table.cell(0, 0)
        set_cell_background(cell, bg_color)
        set_callout_borders(cell, border_color)
        set_cell_margins(cell, top=140, bottom=140, left=200, right=180)
        
        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.line_spacing = 1.18
        
        if title:
            r_title = p.add_run(f"✦  {title}\n")
            r_title.font.name = "Segoe UI"
            r_title.font.size = Pt(11)
            r_title.font.bold = True
            r_title.font.color.rgb = COLOR_PRIMARY
        
        r_text = p.add_run(text)
        r_text.font.name = "Segoe UI"
        r_text.font.size = Pt(10)
        r_text.font.italic = True
        r_text.font.color.rgb = COLOR_TEXT
        
        sp = doc.add_paragraph()
        sp.paragraph_format.space_before = Pt(0)
        sp.paragraph_format.space_after = Pt(6)

    def add_h1(text):
        h = doc.add_paragraph()
        h.paragraph_format.space_before = Pt(22)
        h.paragraph_format.space_after = Pt(8)
        h.paragraph_format.keep_with_next = True
        run = h.add_run(text)
        run.font.name = "Segoe UI"
        run.font.size = Pt(18)
        run.font.bold = True
        run.font.color.rgb = COLOR_PRIMARY
        return h

    def add_h2(text):
        h = doc.add_paragraph()
        h.paragraph_format.space_before = Pt(16)
        h.paragraph_format.space_after = Pt(6)
        h.paragraph_format.keep_with_next = True
        run = h.add_run(text)
        run.font.name = "Segoe UI"
        run.font.size = Pt(14)
        run.font.bold = True
        run.font.color.rgb = COLOR_SECONDARY
        return h

    def add_h3(text):
        h = doc.add_paragraph()
        h.paragraph_format.space_before = Pt(12)
        h.paragraph_format.space_after = Pt(4)
        h.paragraph_format.keep_with_next = True
        run = h.add_run(text)
        run.font.name = "Segoe UI"
        run.font.size = Pt(11.5)
        run.font.bold = True
        run.font.color.rgb = COLOR_PRIMARY
        return h

    def add_body(text, bold_prefix=None, space_after=6):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(space_after)
        p.paragraph_format.line_spacing = 1.2
        if bold_prefix:
            rb = p.add_run(bold_prefix)
            rb.font.name = "Segoe UI"
            rb.font.size = Pt(10.5)
            rb.font.bold = True
            rb.font.color.rgb = COLOR_TEXT
        run = p.add_run(text)
        run.font.name = "Segoe UI"
        run.font.size = Pt(10.5)
        run.font.color.rgb = COLOR_TEXT
        return p

    def add_bullet(text, bold_prefix=None):
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.space_before = Pt(1)
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.line_spacing = 1.18
        if bold_prefix:
            rb = p.add_run(bold_prefix)
            rb.font.name = "Segoe UI"
            rb.font.size = Pt(10)
            rb.font.bold = True
            rb.font.color.rgb = COLOR_PRIMARY
        run = p.add_run(text)
        run.font.name = "Segoe UI"
        run.font.size = Pt(10)
        run.font.color.rgb = COLOR_TEXT
        return p

    # ══════════════════════════════════════════════════════════
    # DOCUMENT COVER / TITLE HEADER
    # ══════════════════════════════════════════════════════════
    title_p = doc.add_paragraph()
    title_p.paragraph_format.space_before = Pt(28)
    title_p.paragraph_format.space_after = Pt(4)
    run_app_badge = title_p.add_run("SERVNEX ENTERPRISE SERVICE MANAGEMENT PLATFORM\n")
    run_app_badge.font.name = "Segoe UI"
    run_app_badge.font.size = Pt(11)
    run_app_badge.font.bold = True
    run_app_badge.font.color.rgb = COLOR_ACCENT

    run_title = title_p.add_run("The Complete ServNex Story:\nTransforming Field Service Chaos into a High-Growth Engine")
    run_title.font.name = "Segoe UI"
    run_title.font.size = Pt(24)
    run_title.font.bold = True
    run_title.font.color.rgb = COLOR_PRIMARY

    sub_p = doc.add_paragraph()
    sub_p.paragraph_format.space_before = Pt(6)
    sub_p.paragraph_format.space_after = Pt(18)
    run_sub = sub_p.add_run(
        "A Comprehensive Customer-Friendly Guide to Features, User Roles, Workflows, "
        "and Business Impact for Modern Service Providers"
    )
    run_sub.font.name = "Segoe UI"
    run_sub.font.size = Pt(13)
    run_sub.font.color.rgb = COLOR_MUTED

    # Meta Table Box
    meta_table = doc.add_table(rows=1, cols=3)
    meta_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    meta_table.autofit = False
    meta_table.columns[0].width = Inches(2.1)
    meta_table.columns[1].width = Inches(2.2)
    meta_table.columns[2].width = Inches(2.2)
    
    set_table_borders(meta_table, "E2E8F0")
    for cell in meta_table.rows[0].cells:
        set_cell_background(cell, "F1F5F9")
        set_cell_margins(cell, top=100, bottom=100, left=120, right=120)

    p0 = meta_table.cell(0, 0).paragraphs[0]
    p0.add_run("Target Audience:\n").bold = True
    p0.add_run("Business Owners, Ops Heads & Enterprise Clients").font.size = Pt(9)
    p0.paragraph_format.line_spacing = 1.1

    p1 = meta_table.cell(0, 1).paragraphs[0]
    p1.add_run("Document Scope:\n").bold = True
    p1.add_run("Full Architecture, Roles, Workflows & ROI").font.size = Pt(9)
    p1.paragraph_format.line_spacing = 1.1

    p2 = meta_table.cell(0, 2).paragraphs[0]
    p2.add_run("Core Tenet:\n").bold = True
    p2.add_run("100% White-Labeled Multi-Tenant Solution").font.size = Pt(9)
    p2.paragraph_format.line_spacing = 1.1

    doc.add_paragraph().paragraph_format.space_after = Pt(14)

    # ══════════════════════════════════════════════════════════
    # EXECUTIVE SUMMARY
    # ══════════════════════════════════════════════════════════
    add_h1("Executive Summary")
    add_body(
        "In the competitive world of after-sales service, equipment maintenance, and facility management, "
        "customer trust is won or lost in the field. When an air conditioner breaks down in the peak of summer, "
        "when a corporate server room loses power, or when a hospital's diagnostic device stalls, the speed, "
        "transparency, and professionalism of the service team define the brand."
    )
    add_body(
        "Yet, the vast majority of service organizations are trapped in operational chaos. They juggle service "
        "requests across phone calls and WhatsApp groups, dispatch technicians blindly without location visibility, "
        "struggle with lost paper receipts, miss lucrative Annual Maintenance Contract (AMC) renewals, and rely on "
        "antiquated spreadsheets that leave leadership in the dark."
    )
    add_body(
        "ServNex was engineered to eliminate this friction entirely. ServNex is a robust, multi-tenant, fully "
        "white-labeled cloud ecosystem that seamlessly connects three vital groups into a single real-time rhythm: "
        "the Operations Administrator who orchestrates the business, the Field Engineer who executes on the ground, "
        "and the Customer who relies on dependable service. With real-time GPS tracking, geofenced mobile attendance, "
        "camera barcode verification, end-to-end AMC lifecycle tracking, instant digital invoices, and dynamic tenant "
        "rebranding, ServNex transforms service companies from reactive firefighters into predictable, high-margin, "
        "customer-obsessed enterprises."
    )

    add_callout(
        "\"ServNex is not just another ticketing tool. It is an end-to-end operational operating system designed "
        "to give service organizations complete command over their workforce, absolute clarity over their physical "
        "assets, and a stunning branded customer experience that drives lifelong retention.\"",
        title="The ServNex Mission"
    )

    # ══════════════════════════════════════════════════════════
    # CHAPTER 1: THE STORY OF SERVICE CHAOS
    # ══════════════════════════════════════════════════════════
    add_h1("Chapter 1: The Modern Service Struggle — A Tale of Two Companies")
    
    add_h2("The Traditional Reality: A Day of Friction and Blind Spots")
    add_body(
        "Consider Apex Services, a reputable HVAC and equipment service firm with 20 field engineers and 400 commercial "
        "clients. On paper, Apex is a thriving enterprise. In reality, every single morning at 8:30 AM starts in a state of controlled panic."
    )
    add_body(
        "Customer service inquiries pour in through multiple disconnected channels: WhatsApp messages sent to personal phones, "
        "inbox emails, phone calls scribbled on desktop sticky notes, and frantic voice notes. Without a centralized intake engine, "
        "tickets slip through the cracks. A critical commercial client waits three days for a technician simply because a paper memo was misplaced."
    )
    add_body(
        "Meanwhile, the Operations Manager faces the infamous 'Black Hole of Field Operations'. Ten engineers have marked themselves 'On Duty' "
        "via text, but where are they actually located? Are they stuck in traffic, already at the client's facility, or still at home? "
        "When an urgent emergency ticket arrives, the dispatcher spends 45 minutes making frantic phone calls to find out who is closest."
    )
    add_body(
        "At the customer's site, confusion continues. The technician arrives without the service history of the equipment. They inspect the wrong "
        "machine because serial numbers were recorded incorrectly. When parts are replaced, notes are jotted down on a paper voucher that gets coffee-stained "
        "or lost. Customers call the office five times asking: 'What is happening with my repair? Who is coming? How much will it cost?'"
    )
    add_body(
        "At the end of the month, the financial hemorrhage is laid bare: dozens of high-value Annual Maintenance Contracts (AMCs) expired silently "
        "because nobody tracked them on the spreadsheet. Billing is delayed by weeks because field receipts haven't been reconciled. Worst of all, "
        "the company is forced to use off-the-shelf software that stamps a third-party logo on every communication, diluting Apex's hard-earned brand identity."
    )

    add_h2("The 7 Fatal Pitfalls That Drain Revenue and Customer Trust")
    add_bullet(" Dispatchers have zero visibility into where technicians are, leading to delayed arrivals, excessive fuel costs, and customer frustration.", bold_prefix="1. The Field Blind Spot:")
    add_bullet(" Unverifiable attendance leads to proxy check-ins, delayed starts, and untracked idle hours that erode profit margins.", bold_prefix="2. Attendance Fraud & Lack of Accountability:")
    add_bullet(" Service inquiries scattered across paper, WhatsApp, and calls result in forgotten jobs, missed SLAs, and angry clients.", bold_prefix="3. Disorganized Ticket Lifecycles:")
    add_bullet(" Without automated reminders and preventive maintenance schedules, businesses lose up to 35% of recurring contract revenue annually.", bold_prefix="4. Lapsed AMC Renewals:")
    add_bullet(" Technicians service the wrong units or order incompatible components due to lack of serial number and barcode tracking.", bold_prefix="5. Asset & Serial Number Mix-ups:")
    add_bullet(" Paper receipts get lost, manual invoice generation takes days, and payment reconciliation becomes an accounting nightmare.", bold_prefix="6. Delayed Invoicing & Billing Friction:")
    add_bullet(" Generic software forces businesses to promote someone else's logo instead of establishing their own prestigious market identity.", bold_prefix="7. Brand Dilution:")

    add_callout(
        "Service businesses do not fail due to a lack of technical expertise. They fail due to operational friction. "
        "When communication breaks down between the desk, the field, and the customer, revenue leaks out of every seam.",
        title="The Core Problem",
        border_color=HEX_WARN_BORDER,
        bg_color=HEX_WARN_BG
    )

    # ══════════════════════════════════════════════════════════
    # COMPARISON TABLE: OLD WAY VS SERVNEX
    # ══════════════════════════════════════════════════════════
    add_h2("Side-by-Side: The Traditional Breakdown vs. The ServNex Revolution")
    
    comp_table = doc.add_table(rows=7, cols=3)
    comp_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    comp_table.autofit = False
    comp_table.columns[0].width = Inches(1.8)
    comp_table.columns[1].width = Inches(2.3)
    comp_table.columns[2].width = Inches(2.4)
    set_table_borders(comp_table, HEX_BORDER)

    headers = ["Operational Area", "The Old Manual Way", "The ServNex Way"]
    for i, h in enumerate(headers):
        cell = comp_table.cell(0, i)
        set_cell_background(cell, HEX_PRIMARY)
        set_cell_margins(cell, top=140, bottom=140, left=140, right=140)
        p = cell.paragraphs[0]
        run = p.add_run(h)
        run.font.name = "Segoe UI"
        run.font.bold = True
        run.font.size = Pt(10)
        run.font.color.rgb = RGBColor(255, 255, 255)

    comp_data = [
        ("Ticket Logging", "Manual paper notes, lost WhatsApp chats, customer anxiety", "Unified digital portal, automated IDs, instant push alerts"),
        ("Field Visibility", "Blind dispatching, constant phone calls asking 'Where are you?'", "Live real-time GPS map with breadcrumb route trails"),
        ("Technician Attendance", "Honor system, verbal check-ins, untracked hours", "Geofenced GPS validation with instant supervisor logs"),
        ("Asset Identification", "Manual serial number guessing, servicing wrong equipment", "In-app camera Barcode & QR scanner with instant repair logs"),
        ("AMC Management", "Forgotten contract expiries, missed preventive care", "Automated contract tracking, proactive renewal reminders"),
        ("Customer Experience", "Customer kept in the dark, forced to follow up repeatedly", "Live ride-share style tracker, digital invoices, star ratings")
    ]

    for row_idx, data in enumerate(comp_data, start=1):
        bg = "FFFFFF" if row_idx % 2 != 0 else HEX_BG_LIGHT
        for col_idx, text in enumerate(data):
            cell = comp_table.cell(row_idx, col_idx)
            set_cell_background(cell, bg)
            set_cell_margins(cell, top=100, bottom=100, left=120, right=120)
            p = cell.paragraphs[0]
            p.paragraph_format.line_spacing = 1.15
            run = p.add_run(text)
            run.font.name = "Segoe UI"
            run.font.size = Pt(9.5)
            if col_idx == 0:
                run.font.bold = True
                run.font.color.rgb = COLOR_PRIMARY
            elif col_idx == 2:
                run.font.color.rgb = COLOR_TEXT

    doc.add_paragraph().paragraph_format.space_after = Pt(12)

    # ══════════════════════════════════════════════════════════
    # CHAPTER 2: ENTER SERVNEX - THE UNIFIED SOLUTION
    # ══════════════════════════════════════════════════════════
    add_h1("Chapter 2: Enter ServNex — The Unified Service Symphony")
    add_body(
        "ServNex was purpose-built to replace fragmented tools with an intelligent, cohesive operating platform. "
        "Instead of requiring a business to subscribe to separate software for ticketing, GPS tracking, attendance, "
        "inventory, and customer portals, ServNex unifies all of these capabilities into a single, synchronized application."
    )
    add_body(
        "At its core, ServNex is designed around a three-sided architecture where every participant interacts with "
        "a tailored interface designed precisely for their daily needs, all powered by real-time cloud data."
    )

    add_h2("The Architectural Pillars of ServNex")
    add_bullet(" Each organization's data (tickets, staff, inventory, customer records) is isolated in a dedicated, secure database partition. No organization ever sees another company's records.", bold_prefix="1. Multi-Tenant Enterprise Security:")
    add_bullet(" Updates made by a technician in the field (status changes, photos, coordinates) appear instantly on the admin's dashboard and the customer's phone without requiring manual refreshes.", bold_prefix="2. Real-Time Cloud Synchronization:")
    add_bullet(" Every organization can completely rebrand the application with their custom company name, logo, primary/secondary brand colors, and typography in real time.", bold_prefix="3. Dynamic White-Label Sovereignty:")
    add_bullet(" Built on Google's Flutter framework, ServNex delivers a buttery-smooth, responsive experience across Android, iOS, tablets, and web browsers with offline caching for field technicians in low-signal basements.", bold_prefix="4. Resilient Mobile-First Architecture:")

    add_callout(
        "\"ServNex gives your business the technological sophistication of a Fortune 500 service enterprise, "
        "fully branded with your company's identity, deployed in minutes without writing a single line of code.\"",
        title="White-Label Power"
    )

    # ══════════════════════════════════════════════════════════
    # CHAPTER 3: THREE ROLES, ONE PLATFORM
    # ══════════════════════════════════════════════════════════
    add_h1("Chapter 3: Three User Roles, Three Tailored Experiences")
    add_body(
        "A system only works if people love using it. If software is too complicated for field technicians, "
        "they will not update it. If it is too dense for customers, they will continue to call on the phone. "
        "ServNex solves this through role-specific user journeys tailored to each stakeholder."
    )

    # Role 1: Admin
    add_h2("Role 1: The Operations Administrator (The Command Center)")
    add_body(
        "For business owners, service directors, and dispatch managers, ServNex provides an all-in-one executive dashboard "
        "that acts as the mission control of the entire enterprise."
    )
    add_bullet(" At a glance, administrators monitor pending tickets, active technicians, total customer accounts, and real-time system alerts.", bold_prefix="• Executive Pulse Dashboard:")
    add_bullet(" Raise service or delivery tickets with a few taps. Search existing customer profiles or create new ones on the fly. Assign tickets to specific engineers based on current proximity, skillset, and availability.", bold_prefix="• Ticket Dispatch & Lifecycle Engine:")
    add_bullet(" An interactive live map displays the real-time geographic location of all on-duty technicians. Admins can auto-follow a moving technician, view historical travel paths, and see job update locations.", bold_prefix="• Live Fleet Radar & GPS Map:")
    add_bullet(" Review daily attendance logs verified with GPS coordinates. Schedule work shifts and eliminate proxy attendance.", bold_prefix="• Geofenced Staff & Shift Management:")
    add_bullet(" Maintain an exhaustive directory of corporate and residential AMC clients. Record equipment details, track contract start and expiry dates, and receive automated renewal alerts before contracts lapse.", bold_prefix="• AMC & Customer Contract Hub:")
    add_bullet(" Manage device categories (Laptops, Printers, HVAC, CCTV, Industrial Motors) and brand configurations. Scan barcodes via camera to inspect equipment service logs.", bold_prefix="• Device Catalog & Barcode Engine:")
    add_bullet(" Generate professional PDF reports for attendance, technician performance metrics, and customer service summaries. Generate GST-compliant invoices and payment receipts with one click.", bold_prefix="• Financials & Automated PDF Reporting:")

    # Role 2: Engineer
    add_h2("Role 2: The Field Service Engineer (The Pocket Companion)")
    add_body(
        "Field technicians need an interface that is fast, intuitive, and works in high-pressure field environments. "
        "ServNex acts as their digital assistant throughout the workday."
    )
    add_bullet(" Technicians punch in and punch out directly from their smartphones. ServNex validates their geographic location to ensure they are at the designated office or service perimeter.", bold_prefix="• Single-Tap Geofenced Attendance:")
    add_bullet(" When a ticket is assigned, the technician receives an immediate push notification with the customer's name, address, contact number, device specifications, and reported fault.", bold_prefix="• Instant Job Dispatch & Navigation:")
    add_bullet(" Technicians use their smartphone camera to scan the barcode or QR code on the equipment, immediately verifying the serial number, warranty status, and past repair logs.", bold_prefix="• Built-in Barcode Asset Verification:")
    add_bullet(" Technicians advance tickets through a structured lifecycle: Assigned → In Progress → Waiting for Spare Parts → Completed. At each stage, they can attach photographic proof (before and after repair) and diagnostic descriptions.", bold_prefix="• Visual Proof & Stage Updates:")
    add_bullet(" Record payment collection (Cash, UPI QR, or Online Gateway) right at the customer's doorstep and capture digital sign-off.", bold_prefix="• Doorstep Payment & Handover:")

    # Role 3: Customer
    add_h2("Role 3: The Customer (Frictionless Transparency & Peace of Mind)")
    add_body(
        "Modern customers expect the convenience of consumer apps like Uber or Amazon when dealing with service providers. "
        "ServNex delivers this premium consumer experience."
    )
    add_bullet(" ServNex supports both contracted Annual Maintenance Contract (AMC) corporate accounts and retail walk-in customers.", bold_prefix="• Dual-Profile Convenience:")
    add_bullet(" Customers log in with their phone number or customer ID and raise service tickets in seconds, specifying device type, brand, issue description, and attaching fault photos.", bold_prefix="• Self-Service Ticket Creation:")
    add_bullet(" Customers no longer have to call asking 'Is someone coming?'. They see a live progress bar detailing every stage of their service request from assignment to technician arrival and final completion.", bold_prefix="• Live 'Track My Service' Timeline:")
    add_bullet(" Instant push notifications alert customers when a technician is assigned, when they are en route, and when the service is completed.", bold_prefix="• Proactive Push Updates:")
    add_bullet(" Customers can download verified service completion summaries, itemized bills, and warranty receipts directly to their devices.", bold_prefix="• Digital Invoices & Receipts:")
    add_bullet(" Customers submit 1 to 5 star ratings and written reviews upon ticket completion, providing management with real-time feedback on technician quality.", bold_prefix="• Ratings & Feedback Loop:")

    # ══════════════════════════════════════════════════════════
    # CHAPTER 4: THE 6 PILLARS OF SERVNEX POWER
    # ══════════════════════════════════════════════════════════
    add_h1("Chapter 4: The 6 Pillars of ServNex Platform Power")
    add_body(
        "To understand why ServNex outperforms generic ticketing and field management tools, "
        "it helps to explore the six foundational feature pillars that form its engine."
    )

    add_h2("Pillar 1: Omnichannel Ticket & Delivery Workflow Engine")
    add_body(
        "Service businesses do not just fix broken parts; they manage an intricate dance of diagnostics, spare parts delivery, "
        "bench testing, and equipment handover. ServNex provides a comprehensive ticket lifecycle engine supporting both "
        "'Service' and 'Delivery' workflows."
    )
    add_body(
        "Each ticket maintains an immutable digital audit log recording every event: when it was logged, who was assigned, "
        "when work began, which replacement parts were flagged, and the exact timestamps of completion. Status filters allow "
        "administrators to drill down into tickets that are 'Pending for Spares', 'Pending for Approval', 'Under Observation', "
        "or 'Delivered' in a fraction of a second."
    )

    add_h2("Pillar 2: Real-Time GPS Tracking & Geofenced Workforce Integrity")
    add_body(
        "Field service efficiency depends on smart routing and honest attendance. ServNex features a state-of-the-art "
        "geolocation engine that pairs Google Maps and Flutter Map technologies."
    )
    add_body(
        "Administrators can open the live fleet view to see an interactive map with technician markers color-coded by status "
        "(Available, In Transit, On Job, Offline). A sliding directory drawer lets managers filter staff instantly, trigger "
        "auto-follow cameras on specific technicians, and inspect historical breadcrumb paths to verify travel efficiency. "
        "Geofencing ensures that attendance check-in can only be recorded when the technician is physically within the geofenced radius."
    )

    add_h2("Pillar 3: AMC (Annual Maintenance Contract) Lifecycle & Recurring Revenue")
    add_body(
        "For service companies, AMCs represent the lifeblood of predictable recurring revenue. Yet, manual tracking results "
        "in forgotten maintenance visits and missed renewal windows."
    )
    add_body(
        "ServNex includes a dedicated AMC Management Suite. Businesses can register AMC clients, record equipment counts, "
        "set contract start and expiration dates, and schedule routine preventive maintenance visits. The platform automatically "
        "tracks contract health and alerts administrators when an AMC is approaching expiration, empowering sales teams to secure "
        "timely renewals and eliminate contract churn."
    )

    add_h2("Pillar 4: Intelligent Hardware Identification via Barcode & QR Scanner")
    add_body(
        "Physical asset confusion costs service businesses thousands of dollars in wasted labor and incorrect parts. "
        "ServNex turns every smartphone into an enterprise-grade hardware scanner."
    )
    add_body(
        "Using the mobile camera, administrators and field engineers can scan standard barcodes and 2D QR codes attached to client equipment. "
        "ServNex instantly queries the database to display the equipment's brand, model, purchase date, warranty status, and past repair history. "
        "This ensures that technicians always work on the correct unit, preventing costly liability issues and verifying spare parts compatibility."
    )

    add_h2("Pillar 5: Dynamic White-Labeling & Brand Sovereignty")
    add_body(
        "Why should your business promote someone else's software brand? ServNex is built from the ground up as a true white-label platform."
    )
    add_body(
        "Through the administrative Branding Customization portal, business owners can upload their high-resolution company logo, "
        "choose custom primary and secondary color palettes (or select from curated professional theme presets), pick modern typography, "
        "and define their application name. The moment settings are saved, the entire application dynamically re-skins itself across all "
        "admin, engineer, and customer devices in real time without requiring app store resubmissions."
    )

    add_h2("Pillar 6: Enterprise Analytics, Financials & Automated Reporting")
    add_body(
        "Leadership cannot make smart decisions without data. ServNex automates the heavy lifting of operational reporting and financial documentation."
    )
    add_body(
        "With a single click, administrators can generate and export publication-ready PDF documents: comprehensive monthly attendance logs, "
        "individual engineer productivity scores, detailed customer repair histories, and GST-compliant invoices with automatic tax breakdowns. "
        "These documents can be printed, emailed, or archived directly from the application."
    )

    # ══════════════════════════════════════════════════════════
    # CHAPTER 5: A DAY IN THE LIFE (THE STORY)
    # ══════════════════════════════════════════════════════════
    add_h1("Chapter 5: A Day in the Life with ServNex — The Operational Journey")
    add_body(
        "To see how all these pieces fit together into a harmonious workflow, let us follow a real-world scenario "
        "from start to finish on a typical Tuesday morning."
    )

    add_h2("08:30 AM — Geofenced Attendance & Morning Roll Call")
    add_body(
        "Arun, a senior field technician at Apex Solutions, opens the ServNex mobile app on his phone as he arrives at the regional dispatch depot. "
        "He taps 'Mark Attendance'. The app uses GPS geofencing to verify Arun's physical coordinates within the depot boundaries. "
        "His check-in timestamp and location are instantly recorded. At the headquarters dashboard, the Operations Manager sees Arun's status "
        "switch from 'Offline' to 'Active & Ready'."
    )

    add_h2("09:15 AM — A Critical Service Ticket is Raised")
    add_body(
        "Across town, the Facilities Director at Horizon Commercial Towers notices that their primary air compressor unit is showing a pressure fault. "
        "Instead of calling a generic hotline or waiting on hold, she opens the branded Horizon ServNex portal on her phone. "
        "She selects 'Service Request', picks her device from her saved AMC equipment list, types a brief description ('Overheating warning code E-04'), "
        "snaps a quick photo of the error screen, and taps 'Submit'."
    )

    add_h2("09:20 AM — Intelligent Map-Based Dispatch")
    add_body(
        "Back at the operations desk, a notification rings. The Operations Manager opens the live Ticket Overview. The new ticket from Horizon Towers "
        "is prominently highlighted. The manager opens the Live Fleet GPS Map, locates Horizon Towers, and sees that Arun is only 2.5 kilometers away, "
        "having just completed an inspection. With two clicks, the ticket is assigned to Arun."
    )

    add_h2("09:22 AM — Instant Notification & GPS Route Navigation")
    add_body(
        "Arun's smartphone vibrates with a high-priority push alert: 'New Job Assigned: Horizon Commercial Towers'. Arun taps the alert, "
        "reviews the fault photo and error code, and taps 'Navigate'. The app opens Google Maps with turn-by-turn navigation directly to the facility gate. "
        "Simultaneously, the customer at Horizon Towers receives a push alert: 'Technician Arun has been dispatched and is en route'."
    )

    add_h2("09:45 AM — On-Site Barcode Verification & Diagnostics")
    add_body(
        "Upon arriving, Arun meets the facility supervisor and heads to the equipment room. Arun taps 'Scan Barcode' in ServNex and points his phone "
        "at the compressor's serial tag. The app immediately pulls up the unit's complete profile: 50HP Screw Compressor, under active AMC Plan Gold, "
        "last serviced 45 days ago with a filter replacement. Arun updates the ticket status to 'In Progress'. The customer's app timeline immediately "
        "reflects that diagnostics have begun."
    )

    add_h2("10:45 AM — Photographic Evidence & Job Completion")
    add_body(
        "Arun identifies a faulty thermal relief valve, replaces it with a genuine spare part from his vehicle inventory, recalibrates the pressure sensor, "
        "and runs a 15-minute load test. Everything is within optimal operating limits. "
        "Arun takes two photos: one of the replaced valve and one of the clean digital diagnostic readout. He enters a completion note: 'Replaced thermal "
        "relief valve; pressure stabilized at 8.2 bar'. He selects payment type as 'Covered under AMC contract', captures the supervisor's digital signature, "
        "and taps 'Mark as Completed'."
    )

    add_h2("10:50 AM — Automated Invoice, Digital Receipt & Customer Review")
    add_body(
        "The moment Arun completes the ticket, three things happen instantaneously:"
    )
    add_bullet(" The customer receives a completion alert and an itemized digital service summary PDF in her app.", bold_prefix="1. Instant Customer Delivery:")
    add_bullet(" A rating prompt pops up on the customer's screen. Delighted by the rapid 90-minute turnaround, she awards 5 stars and writes: 'Super fast dispatch, technician arrived with exact parts!'.", bold_prefix="2. 5-Star Feedback Loop:")
    add_bullet(" The ticket automatically archives to the administrative dashboard, updating Arun's performance score and updating the customer's AMC service history log.", bold_prefix="3. Real-Time Admin Sync:")

    add_callout(
        "In less than two hours, a critical equipment failure was reported, dispatched, diagnosed, resolved, verified, "
        "and reviewed—with zero paper slips, zero phone friction, and 100% digital accountability.",
        title="The Power of Integration",
        border_color=HEX_SUCCESS_BORDER,
        bg_color=HEX_SUCCESS_BG
    )

    # ══════════════════════════════════════════════════════════
    # CHAPTER 6: QUANTIFIABLE BUSINESS IMPACT & ROI
    # ══════════════════════════════════════════════════════════
    add_h1("Chapter 6: Quantifiable Business Value & Return on Investment")
    add_body(
        "Investing in an enterprise platform must translate directly into tangible financial and operational returns. "
        "Organizations that implement ServNex experience dramatic improvements across key performance indicators (KPIs)."
    )

    # ROI Table
    roi_table = doc.add_table(rows=6, cols=3)
    roi_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    roi_table.autofit = False
    roi_table.columns[0].width = Inches(2.0)
    roi_table.columns[1].width = Inches(2.2)
    roi_table.columns[2].width = Inches(2.3)
    set_table_borders(roi_table, HEX_BORDER)

    roi_headers = ["Key Metric", "Observed Improvement", "Commercial Impact"]
    for i, h in enumerate(roi_headers):
        cell = roi_table.cell(0, i)
        set_cell_background(cell, HEX_PRIMARY)
        set_cell_margins(cell, top=140, bottom=140, left=140, right=140)
        p = cell.paragraphs[0]
        run = p.add_run(h)
        run.font.name = "Segoe UI"
        run.font.bold = True
        run.font.size = Pt(10)
        run.font.color.rgb = RGBColor(255, 255, 255)

    roi_data = [
        ("Ticket Turnaround Time", "40% to 50% Reduction", "Technicians resolve more jobs per day, increasing billable capacity."),
        ("Workforce Accountability", "100% Elimination of Proxy Attendance", "Geofenced check-ins ensure honest field hours and lower payroll leakage."),
        ("AMC Contract Retention", "30% to 35% Increase in Renewals", "Automated expiry warnings prevent silent contract loss and recurring revenue bleed."),
        ("Billing & Dispute Resolution", "90% Reduction in Invoice Disputes", "Photo proof, timestamps, and customer signatures eliminate client payment friction."),
        ("Customer Retention", "Net Promoter Score (NPS) increases by 25+", "A transparent digital experience builds loyalty and wins word-of-mouth contracts.")
    ]

    for row_idx, data in enumerate(roi_data, start=1):
        bg = "FFFFFF" if row_idx % 2 != 0 else HEX_BG_LIGHT
        for col_idx, text in enumerate(data):
            cell = roi_table.cell(row_idx, col_idx)
            set_cell_background(cell, bg)
            set_cell_margins(cell, top=100, bottom=100, left=120, right=120)
            p = cell.paragraphs[0]
            p.paragraph_format.line_spacing = 1.15
            run = p.add_run(text)
            run.font.name = "Segoe UI"
            run.font.size = Pt(9.5)
            if col_idx == 0:
                run.font.bold = True
                run.font.color.rgb = COLOR_PRIMARY
            elif col_idx == 1:
                run.font.bold = True
                run.font.color.rgb = COLOR_SECONDARY

    doc.add_paragraph().paragraph_format.space_after = Pt(12)

    # ══════════════════════════════════════════════════════════
    # CHAPTER 7: TIERS & PACKAGES
    # ══════════════════════════════════════════════════════════
    add_h1("Chapter 7: Commercial Plans & Scalable Growth")
    add_body(
        "ServNex is architected to scale seamlessly with your organization, whether you are an emerging local service "
        "team with 5 technicians or an enterprise corporation managing hundreds of engineers across multiple regional territories."
    )

    # Plan Matrix Table
    plan_table = doc.add_table(rows=5, cols=4)
    plan_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    plan_table.autofit = False
    plan_table.columns[0].width = Inches(1.5)
    plan_table.columns[1].width = Inches(1.6)
    plan_table.columns[2].width = Inches(1.7)
    plan_table.columns[3].width = Inches(1.7)
    set_table_borders(plan_table, HEX_BORDER)

    plan_headers = ["Feature / Tier", "Silver (Starter)", "Gold (Popular)", "Platinum (Pro Power)"]
    for i, h in enumerate(plan_headers):
        cell = plan_table.cell(0, i)
        set_cell_background(cell, HEX_PRIMARY)
        set_cell_margins(cell, top=140, bottom=140, left=120, right=120)
        p = cell.paragraphs[0]
        run = p.add_run(h)
        run.font.name = "Segoe UI"
        run.font.bold = True
        run.font.size = Pt(9.5)
        run.font.color.rgb = RGBColor(255, 255, 255)

    plan_data = [
        ("Target Team Size", "Small teams (up to 5 engineers)", "Growing teams (up to 10 engineers)", "Enterprise teams (Unlimited)"),
        ("Customer Capacity", "Up to 20 Customers", "Up to 50 Customers", "Unlimited Customers"),
        ("Field GPS Tracking", "Standard Dashboard", "Live Real-Time GPS Tracking", "Live GPS + Route Breadcrumbs"),
        ("Advanced Modules", "Ticketing & History Logs", "Automated PDF Exports & Routing", "Geofenced Attendance + Barcodes")
    ]

    for row_idx, data in enumerate(plan_data, start=1):
        bg = "FFFFFF" if row_idx % 2 != 0 else HEX_BG_LIGHT
        for col_idx, text in enumerate(data):
            cell = plan_table.cell(row_idx, col_idx)
            set_cell_background(cell, bg)
            set_cell_margins(cell, top=100, bottom=100, left=100, right=100)
            p = cell.paragraphs[0]
            p.paragraph_format.line_spacing = 1.15
            run = p.add_run(text)
            run.font.name = "Segoe UI"
            run.font.size = Pt(9)
            if col_idx == 0:
                run.font.bold = True
                run.font.color.rgb = COLOR_PRIMARY
            elif col_idx == 2:
                run.font.color.rgb = COLOR_ACCENT

    doc.add_paragraph().paragraph_format.space_after = Pt(12)

    add_body(
        "Additionally, an Enterprise Custom tier is available for corporations requiring bespoke ERP integrations, "
        "dedicated cloud infrastructure, customized SLA guarantees, and on-premise staff onboarding."
    )

    # ══════════════════════════════════════════════════════════
    # CHAPTER 8: CONCLUSION & GETTING STARTED
    # ══════════════════════════════════════════════════════════
    add_h1("Chapter 8: Conclusion & Your Path Forward")
    add_body(
        "The service economy has entered a new era. Customers are no longer willing to tolerate blind arrival windows, "
        "lost service slips, or lack of communication. In turn, service businesses cannot survive if they continue to "
        "leak revenue through unverified field hours and forgotten AMC contracts."
    )
    add_body(
        "ServNex is your complete vehicle for modern service excellence. By equipping your dispatchers with real-time "
        "operational command, your field engineers with an intuitive pocket companion, and your customers with an elegant, "
        "transparent service portal—all beautifully wrapped under your own company brand—ServNex empowers you to grow "
        "profitably, retain customers effortlessly, and lead your industry."
    )

    add_h2("Getting Started in 3 Simple Steps")
    add_bullet(" Register your organization in seconds. Pick your brand colors, upload your corporate logo, and set your company name. Your custom app is live immediately.", bold_prefix="Step 1: Configure Your Brand:")
    add_bullet(" Add your field engineers, configure your device categories (brands and models), and import your existing customer and AMC contract lists.", bold_prefix="Step 2: Onboard Staff & Inventory:")
    add_bullet(" Experience the interactive 6-step guided tour on your dashboard, dispatch your first live ticket, and watch your service operations transform into a well-oiled machine.", bold_prefix="Step 3: Launch Operations:")

    add_callout(
        "\"The best time to digitize and elevate your service business was yesterday. The next best time is right now. "
        "Partner with ServNex and step into the future of field service excellence.\"",
        title="Ready to Elevate Your Service?",
        border_color=HEX_PRIMARY,
        bg_color=HEX_CALLOUT_BG
    )

    # Save document
    doc.save(output_path)
    print(f"Document successfully created at: {output_path}")

if __name__ == "__main__":
    out_file = r"d:\Rooks Tech\white_label_non_subscription\ServNex_Complete_Product_Story_and_Business_Overview.docx"
    create_servnex_document(out_file)
