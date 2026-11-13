import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn
import os

def set_cell_background(cell, hex_color):
    """Sets background color of a table cell."""
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
    tc_pr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    """Sets inner margins (padding) for a table cell in dxa (1 pt = 20 dxa)."""
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = parse_xml(f'''
        <w:tcMar {nsdecls("w")}>
            <w:top w:w="{top}" w:type="dxa"/>
            <w:bottom w:w="{bottom}" w:type="dxa"/>
            <w:left w:w="{left}" w:type="dxa"/>
            <w:right w:w="{right}" w:type="dxa"/>
        </w:tcMar>
    ''')
    tc_pr.append(tc_mar)

def set_table_borders(table, color="D4A373", sz="4", val="single"):
    """Applies neat borders to a table."""
    tbl_pr = table._tbl.tblPr
    borders = parse_xml(f'''
        <w:tblBorders {nsdecls("w")}>
            <w:top w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
            <w:bottom w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
            <w:insideH w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
            <w:insideV w:val="none"/>
            <w:left w:val="none"/>
            <w:right w:val="none"/>
        </w:tblBorders>
    ''')
    tbl_pr.append(borders)

def add_callout(doc, text, title=None, border_color="D49755", bg_color="F9F6F0"):
    """Creates a visually distinct callout box with a left colored bar."""
    tbl = doc.add_table(rows=1, cols=1)
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    tbl.autofit = False
    cell = tbl.cell(0, 0)
    cell.width = Inches(6.5)
    
    set_cell_background(cell, bg_color)
    set_cell_margins(cell, top=140, bottom=140, left=200, right=200)
    
    # Left border only
    tc_pr = cell._tc.get_or_add_tcPr()
    borders = parse_xml(f'''
        <w:tcBorders {nsdecls("w")}>
            <w:left w:val="single" w:sz="24" w:space="0" w:color="{border_color}"/>
            <w:top w:val="none"/>
            <w:bottom w:val="none"/>
            <w:right w:val="none"/>
        </w:tcBorders>
    ''')
    tc_pr.append(borders)
    
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.line_spacing = 1.15
    
    if title:
        run_t = p.add_run(f"{title}\n")
        run_t.bold = True
        run_t.font.name = "Arial"
        run_t.font.size = Pt(10.5)
        run_t.font.color.rgb = RGBColor(0x5A, 0x38, 0x25) # Deep brown
    
    run = p.add_run(text)
    run.font.name = "Arial"
    run.font.size = Pt(9.5)
    run.font.italic = True
    run.font.color.rgb = RGBColor(0x23, 0x17, 0x14)
    
    # Space after table
    sp = doc.add_paragraph()
    sp.paragraph_format.space_before = Pt(0)
    sp.paragraph_format.space_after = Pt(6)

def format_table(table, col_widths, headers, data, alt_shading=True):
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(table, color="D4A373", sz="4")
    
    # Header Row
    hdr_cells = table.rows[0].cells
    for i, title in enumerate(headers):
        hdr_cells[i].text = title
        set_cell_background(hdr_cells[i], "5A3825") # Deep Coffee Brown
        set_cell_margins(hdr_cells[i], top=120, bottom=120, left=140, right=140)
        p = hdr_cells[i].paragraphs[0]
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(0)
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        for run in p.runs:
            run.font.name = "Arial"
            run.font.size = Pt(9.5)
            run.font.bold = True
            run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
            
    # Data Rows
    for row_idx, row_data in enumerate(data):
        row_cells = table.add_row().cells
        bg_col = "F9F6F0" if (alt_shading and row_idx % 2 == 1) else "FFFFFF"
        for col_idx, text in enumerate(row_data):
            row_cells[col_idx].text = str(text)
            set_cell_background(row_cells[col_idx], bg_col)
            set_cell_margins(row_cells[col_idx], top=90, bottom=90, left=140, right=140)
            p = row_cells[col_idx].paragraphs[0]
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.line_spacing = 1.1
            for run in p.runs:
                run.font.name = "Arial"
                run.font.size = Pt(9)
                run.font.color.rgb = RGBColor(0x23, 0x17, 0x14)
                
    # Column Widths
    for row in table.rows:
        for idx, width in enumerate(col_widths):
            row.cells[idx].width = Inches(width)

def build_document():
    doc = docx.Document()
    
    # Page setup: Standard Letter, 1-inch margins
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)
        section.page_width = Inches(8.5)
        section.page_height = Inches(11.0)
        
    # Styles definition
    styles = doc.styles
    normal_style = styles['Normal']
    normal_style.font.name = 'Arial'
    normal_style.font.size = Pt(10)
    normal_style.font.color.rgb = RGBColor(0x23, 0x17, 0x14)
    normal_style.paragraph_format.line_spacing = 1.15
    normal_style.paragraph_format.space_after = Pt(6)

    # ── HEADER / TITLE SECTION ──────────────────────────────────────────────────
    title_p = doc.add_paragraph()
    title_p.paragraph_format.space_before = Pt(0)
    title_p.paragraph_format.space_after = Pt(2)
    t_run = title_p.add_run("CafeGO Order: Complete Project Documentation")
    t_run.font.name = "Arial"
    t_run.font.size = Pt(22)
    t_run.bold = True
    t_run.font.color.rgb = RGBColor(0x5A, 0x38, 0x25) # Brand Brown

    sub_p = doc.add_paragraph()
    sub_p.paragraph_format.space_before = Pt(0)
    sub_p.paragraph_format.space_after = Pt(8)
    sub_run = sub_p.add_run("Mobile Programming I · Pre-Final Term Project · Flutter + Firebase\nGroup 2 · Section: CS31A · Instructor: Jayrek Tabasa")
    sub_run.font.name = "Arial"
    sub_run.font.size = Pt(11)
    sub_run.font.color.rgb = RGBColor(0x78, 0x69, 0x60)
    sub_run.bold = True

    add_callout(doc, 
        "This official documentation covers every item in the Pre-Final and Final Term project requirements for CafeGO Order. "
        "The project provides a complete, scalable mobile ordering ecosystem powered by Flutter and Firebase, featuring "
        "real-time order synchronization, strict Role-Based Access Control (Customer, Staff/Barista, Admin, Driver), "
        "live drink customization, cashless & cash checkout, and automated testing.",
        title="DOCUMENT SCOPE & ACADEMIC SUBMISSION NOTICE"
    )

    # Divider line
    div_p = doc.add_paragraph()
    div_p.paragraph_format.space_before = Pt(2)
    div_p.paragraph_format.space_after = Pt(14)
    pBdr = parse_xml(f'<w:pBdr {nsdecls("w")}><w:bottom w:val="single" w:sz="12" w:space="1" w:color="D49755"/></w:pBdr>')
    div_p._p.get_or_add_pPr().append(pBdr)

    # Helper for headings
    def add_h1(text):
        h = doc.add_paragraph()
        h.paragraph_format.space_before = Pt(16)
        h.paragraph_format.space_after = Pt(6)
        h.paragraph_format.keep_with_next = True
        r = h.add_run(text)
        r.font.name = "Arial"
        r.font.size = Pt(15)
        r.bold = True
        r.font.color.rgb = RGBColor(0x5A, 0x38, 0x25)
        # bottom underline
        bdr = parse_xml(f'<w:pBdr {nsdecls("w")}><w:bottom w:val="single" w:sz="6" w:space="1" w:color="D4A373"/></w:pBdr>')
        h._p.get_or_add_pPr().append(bdr)
        return h

    def add_h2(text):
        h = doc.add_paragraph()
        h.paragraph_format.space_before = Pt(12)
        h.paragraph_format.space_after = Pt(4)
        h.paragraph_format.keep_with_next = True
        r = h.add_run(text)
        r.font.name = "Arial"
        r.font.size = Pt(12)
        r.bold = True
        r.font.color.rgb = RGBColor(0x38, 0x23, 0x19)
        return h

    def add_h3(text):
        h = doc.add_paragraph()
        h.paragraph_format.space_before = Pt(8)
        h.paragraph_format.space_after = Pt(2)
        h.paragraph_format.keep_with_next = True
        r = h.add_run(text)
        r.font.name = "Arial"
        r.font.size = Pt(10.5)
        r.bold = True
        r.font.color.rgb = RGBColor(0x78, 0x69, 0x60)
        return h

    # ── 1. PROJECT TITLE AND OVERVIEW ──────────────────────────────────────────
    add_h1("1. Project Title and Overview")
    
    p = doc.add_paragraph()
    p.add_run("Application Name: ").bold = True
    p.add_run("CafeGO Order (Tagline: \"Your daily comfort brew\")\n")
    p.add_run("Brief Description: ").bold = True
    p.add_run("CafeGO Order is a single-shop mobile ordering and shop operations application built with Flutter and Firebase. "
              "Customers browse the menu, customize artisan drinks in real-time, order ahead (Pickup, Dine-in with table numbers, or Delivery), "
              "and track their order live through a 4-step stepper. Baristas and staff manage a live Kitchen Display System (KDS) order queue, "
              "while administrators control menu items, pricing, photos, and inventory availability from the same unified platform.")

    p2 = doc.add_paragraph()
    p2.add_run("Purpose: ").bold = True
    p2.add_run("To replace manual counter-only and chat-based ordering with a structured, trackable, mistake-resistant ordering ecosystem. "
               "The application bridges communication between customer, barista, cashier, and courier into a synchronized real-time state machine.")

    add_h2("Objectives")
    bullets_obj = [
        ("Accurate Drink Customization", "Let customers place accurate orders with full customization (size, milk substitute, sugar level, ice preference, add-ons) backed by dynamic live pricing calculations."),
        ("Queue Reduction & Flexibility", "Reduce physical queueing and wait times during peak hours by enabling Pickup, Dine-in (with table assignment), and Delivery orders ahead of time."),
        ("Unified Barista Queue (KDS)", "Provide baristas with a single live FIFO order queue so no order is lost in scattered chat messages or paper chits."),
        ("One-Tap Reordering", "Allow regular patrons to save favorite drink combinations and repeat past orders in a single tap."),
        ("Real-Time Inventory Control", "Let staff instantly toggle menu availability (e.g., when oat milk or specific pastries run out), instantly reflecting on customer devices without app restarts."),
        ("Robust Data Protection", "Enforce strict Role-Based Access Control (RBAC) via Firebase Authentication claims and Cloud Firestore Security Rules, guaranteeing data privacy and operational separation."),
    ]
    for b_title, b_desc in bullets_obj:
        bp = doc.add_paragraph(style='List Bullet')
        bp.paragraph_format.space_after = Pt(3)
        bp.add_run(f"{b_title}: ").bold = True
        bp.add_run(b_desc)

    add_h2("Problem Statement")
    doc.add_paragraph(
        "Coffee shop operations are inherently time-sensitive. At CafeGO, customers have historically ordered at the counter or through "
        "unstructured social messaging channels (e.g., Facebook Messenger / SMS). During morning and afternoon peak hours, this causes "
        "long physical lines, frequent mistakes in drink customizations (e.g., wrong milk type or missed syrup additions), lost order tickets, "
        "and barista fatigue. Furthermore, regular customers have no streamlined way to reorder their usual beverage, and management lacks "
        "immediate visibility into daily revenue, peak product demand, and live queue latency."
    )

    # ── 2. TARGET USERS AND SCOPE ──────────────────────────────────────────────
    add_h1("2. Target Users and Scope")
    add_h2("Intended Users")
    
    users_headers = ["User Role", "Target Needs & Operational Responsibilities in CafeGO"]
    users_data = [
        ["Customer", "Browse menu categories, customize drinks with live price updates, order ahead to skip queues, track order status live, reorder favorite drinks, manage profile and saved delivery addresses."],
        ["Barista / Staff", "View incoming orders in real-time via Kitchen Display System (KDS), manage preparation timers, process Cash/COD payments with change calculator, update order status (Received -> Preparing -> Ready -> Completed)."],
        ["Admin", "Comprehensive store management: add, edit, or hide menu items, update prices and photos, toggle stock availability, inspect daily revenue analytics, manage user roles."],
        ["Driver / Courier", "Accept assigned delivery orders, view delivery address and GPS route coordinates, inspect customer notes, update delivery milestones, and view delivery earnings."]
    ]
    t_users = doc.add_table(rows=1, cols=2)
    format_table(t_users, [1.8, 4.7], users_headers, users_data)

    add_h2("Main Features and Functionalities")
    p_feat = doc.add_paragraph()
    p_feat.add_run("Customer Side: ").bold = True
    p_feat.add_run("Email & password authentication, email OTP verification, category browsing, full-text menu search, live drink customization bottom sheet (size, milk, sugar, ice, toppings), "
                   "cart line management with notes, flexible checkout (Pickup, Dine-in with table assignment, Delivery with saved address), PayMongo cashless (GCash, Maya, Card) & Cash options, "
                   "real-time order status stepper, order receipts, favorite drinks, order history with one-tap reorder, profile management, and loyalty reward stamp card.\n\n")
    p_feat.add_run("Staff & Barista Side: ").bold = True
    p_feat.add_run("Live KDS ticket queue sorted oldest-first (FIFO), preparation countdown timer, interactive order details drawer, Cashier drawer with change calculation, one-tap status advancement.\n\n")
    p_feat.add_run("Admin Side: ").bold = True
    p_feat.add_run("Product catalog CRUD, image picker and upload, instant sold-out toggle, real-time daily revenue and sales breakdown charts, role-based security enforcement.\n\n")
    p_feat.add_run("Driver Side: ").bold = True
    p_feat.add_run("Delivery queue, interactive customer address details, GPS location viewer, delivery completion confirmation, and courier earnings summary.")

    add_h2("Project Boundaries and Limitations")
    limits = [
        ("Single Shop Scope", "Designed exclusively for CafeGO single-branch operations; multi-merchant or franchise routing is out of scope."),
        ("Payment Processing", "Supports Cash-on-Delivery, Pay-at-Counter, and PayMongo payment gateway (GCash, Maya, Credit/Debit card). No physical POS card-swipe hardware is integrated."),
        ("Delivery Logistics", "Delivery captures verified customer addresses, notes, and geographic coordinates. Automated third-party driver dispatch algorithms (e.g. GrabExpress/Lalamove API) are out of scope."),
        ("Connectivity Requirement", "Active internet connection is required for live Firestore synchronization. Offline queueing is deliberately disabled to prevent inventory desynchronization."),
        ("Target Test Environment", "Android mobile platform (API 28+) is the primary test and grading target, with responsive Flutter Web deployment for grading accessibility.")
    ]
    for l_title, l_desc in limits:
        bp = doc.add_paragraph(style='List Bullet')
        bp.paragraph_format.space_after = Pt(3)
        bp.add_run(f"{l_title}: ").bold = True
        bp.add_run(l_desc)

    add_h2("Expected Benefits")
    benefits = [
        ("Shorter Queue Times", "Peak-hour counter congestion reduced by enabling customers to order ahead and receive real-time readiness alerts."),
        ("Zero Customization Errors", "Structured options guarantee baristas receive precise specifications without handwriting ambiguity or missed chat messages."),
        ("Single Source of Truth", "Centralized Firestore order stream eliminates duplicated chits and lost tickets."),
        ("Customer Retention", "One-tap reordering and digital loyalty stamp incentives encourage higher customer lifetime value.")
    ]
    for b_title, b_desc in benefits:
        bp = doc.add_paragraph(style='List Bullet')
        bp.paragraph_format.space_after = Pt(3)
        bp.add_run(f"{b_title}: ").bold = True
        bp.add_run(b_desc)

    # ── 3. FUNCTIONAL REQUIREMENTS ─────────────────────────────────────────────
    add_h1("3. Functional Requirements")
    add_h2("3.1 Functional Requirements Matrix")
    
    fr_headers = ["ID", "Feature", "User Action", "Expected System Response", "Priority"]
    fr_data = [
        ["FR-01", "Sign Up", "Enter name, email, phone, and password", "Validates format, checks uniqueness, creates Auth account & Firestore profile, routes to Menu.", "Core"],
        ["FR-02", "Log In / Log Out", "Enter email and password", "Authenticates credentials and redirects according to role (Customer to Menu, Staff/Admin to Workspace).", "Core"],
        ["FR-03", "Browse Menu", "Tap category chip (Coffee, Iced, Pastry)", "Filters and displays available catalog items with photos, descriptions, and base prices.", "Core"],
        ["FR-04", "Search Menu", "Type keywords in search input", "Instantly filters catalog items matching name or ingredients in real time.", "Core"],
        ["FR-05", "Customize Drink", "Select size, milk, sugar, ice, and add-ons", "Calculates live price deltas and reflects subtotal immediately on action button.", "Core"],
        ["FR-06", "Manage Cart", "Adjust item quantity, edit options, or remove", "Updates cart line items, applies pricing rules, and recalculates total instantly.", "Core"],
        ["FR-07", "Checkout Order", "Select order type, enter details, submit", "Validates inputs, generates Firestore order ticket with status 'received'.", "Core"],
        ["FR-08", "Track Order", "Open active order tracking screen", "Streams live status (Received -> Preparing -> Ready -> Completed) with dynamic stepper.", "Core"],
        ["FR-09", "Order History & Reorder", "Select previous order and tap 'Reorder'", "Validates current item availability and rebuilds cart in one tap.", "Core"],
        ["FR-10", "Favorites", "Tap heart icon on menu item card", "Saves or removes item ID in user's favorites array in Firestore.", "Core"],
        ["FR-11", "Manage Profile", "Edit name, phone, or saved addresses", "Validates input (PH phone format) and updates Firestore user document.", "Core"],
        ["FR-12", "Manage Catalog", "Add, edit, or archive catalog items", "Uploads image to Storage, writes document to 'menu' collection, syncs instantly.", "Core"],
        ["FR-13", "Availability Toggle", "Switch item availability in admin/staff", "Updates 'isAvailable' flag; item displays 'Sold Out' and cannot be added to cart.", "Core"],
        ["FR-14", "Live KDS Queue", "Barista opens Kitchen Display queue", "Streams pending orders sorted oldest-first (FIFO) with prep timer.", "Core"],
        ["FR-15", "Update Order Status", "Staff taps next status button", "Atomically transitions order state; customer device updates within 2 seconds.", "Core"],
        ["FR-16", "Loyalty Rewards", "Complete qualifying coffee orders", "Awards 1 stamp per completed order; grants free drink reward voucher upon 8 stamps.", "Core / Codebase"],
        ["FR-17", "Order Notifications", "Order transitions to 'Ready' or 'Out'", "Triggers local system notification and updates in-app banner.", "Core / Codebase"],
        ["FR-18", "Sales Analytics", "Open admin reports tab", "Displays real-time daily order volume, revenue total, and payment method breakdown.", "Core / Codebase"],
        ["FR-19", "Payment Processing", "Select PayMongo (GCash/Maya/Card) or Cash", "Creates PayMongo checkout session or records cash transaction with cashier change calculator.", "Codebase Extension"],
        ["FR-20", "Driver Delivery Dispatch", "Driver accepts assigned delivery", "Displays customer address, map coordinates, delivery notes, and milestone tracker.", "Codebase Extension"],
        ["FR-21", "Order Rating & Feedback", "Rate completed order (1-5 stars + note)", "Saves rating to 'ratings' collection and calculates merchant satisfaction score.", "Codebase Extension"]
    ]
    t_fr = doc.add_table(rows=1, cols=5)
    format_table(t_fr, [0.6, 1.2, 1.8, 2.3, 0.6], fr_headers, fr_data)

    add_h2("3.2 Non-Functional Requirements (NFR)")
    nfr_headers = ["ID", "Requirement Specification", "Validation Metric & Implementation in Codebase"]
    nfr_data = [
        ["NFR-01", "Real-Time Sync Latency", "Order status changes appear on customer devices within 2 seconds under normal 4G/WiFi connectivity via Firestore snapshots."],
        ["NFR-02", "Form Validation & Error Handling", "Every user input (email format, password length >= 6, PH phone +63, table number) validates before submission with user-friendly error banners."],
        ["NFR-03", "Progressive Feedback & Empty States", "Shimmer loaders display during async fetch; all empty views (empty cart, no orders, empty search) provide friendly action prompts."],
        ["NFR-04", "Role-Based Data Isolation (RBAC)", "Customers can only read/write their own records. Menu writes and status mutations are locked to admin/staff via Firestore Security Rules."],
        ["NFR-05", "Credential & Secrets Security", "Zero API keys, Firebase service accounts, or private tokens committed to Git. Environment configs isolated via .env and compile-time constants."],
        ["NFR-06", "Responsive Ergonomics & Theming", "UI conforms to Material Design 3, supports Light and Dark modes, and adapts responsively across mobile screen sizes (360dp - 480dp width)."],
        ["NFR-07", "Accessibility & Touch Targets", "All interactive touch targets are at least 44x44 px; text-to-background contrast ratio exceeds WCAG AA standard (>= 4.5:1)."]
    ]
    t_nfr = doc.add_table(rows=1, cols=3)
    format_table(t_nfr, [0.8, 2.2, 3.5], nfr_headers, nfr_data)

    add_h2("3.3 Use Case Actors & Interactions")
    uc_headers = ["Actor", "Primary System Interactions & Workflows"]
    uc_data = [
        ["Customer", "Sign up, verify email, log in, browse menu, search, customize drinks, manage cart, checkout (Pickup/Dine-In/Delivery), track order live, view history, reorder, manage favorites, update profile, rate orders."],
        ["Barista / Staff", "Authenticate, view real-time FIFO order queue (KDS), advance order states, calculate cash change, toggle ingredient/item availability."],
        ["Admin", "Manage catalog (add, edit, archive items, upload photos), toggle store availability, review daily sales analytics, oversee staff operations."],
        ["Driver / Courier", "Authenticate, view active delivery assignments, navigate to customer address using coordinates, confirm delivery handoff."],
        ["Firebase System", "Enforce security rules, verify authentication tokens, stream real-time document snapshots, persist images, send notification alerts."]
    ]
    t_uc = doc.add_table(rows=1, cols=2)
    format_table(t_uc, [1.5, 5.0], uc_headers, uc_data)

    add_h2("3.4 System User Flows & Order Lifecycle")
    doc.add_paragraph("The application operates on distinct, role-guarded user flow loops:")
    
    flow_bullets = [
        ("Customer Lifecycle", "Login / Sign Up -> Catalog Browsing -> Item Customization (Bottom Sheet) -> Cart Verification -> Checkout (Select Pickup / Dine-In / Delivery) -> Live Order Tracking -> Receipt / History -> One-Tap Reorder."),
        ("Staff KDS Lifecycle", "Staff Login -> Live KDS Queue -> Inspect Order Specifications -> Tap 'Start Preparing' (Status: Preparing) -> Tap 'Ready' (Status: Ready) -> Cash Tender / Handoff -> Complete."),
        ("Order State Machine", "RECEIVED -> PREPARING -> READY -> COMPLETED (Cancellation permitted by customer only while in 'RECEIVED' state)."),
        ("Driver Lifecycle", "Driver Login -> Delivery Queue -> Accept Assignment -> Inspect Customer Notes & Coordinates -> Deliver & Collect Cash (if COD) -> Mark Completed.")
    ]
    for f_title, f_desc in flow_bullets:
        bp = doc.add_paragraph(style='List Bullet')
        bp.paragraph_format.space_after = Pt(3)
        bp.add_run(f"{f_title}: ").bold = True
        bp.add_run(f_desc)

    add_h2("3.5 Feature Prioritization Matrix")
    prio_headers = ["Priority Tier", "Scope Classification", "Features Included in CafeGO Order"]
    prio_data = [
        ["Core (Must Finish)", "Pre-Final Requirement", "FR-01 to FR-15: Auth, Catalog, Customization, Cart, Checkout, Tracking, Favorites, History, Profile, Admin CRUD, Sold-out Toggle, Live Barista Queue, Status Transitions."],
        ["Completed Enhancements", "Final Term & Codebase", "FR-16 (Loyalty Stamp System), FR-17 (Notifications), FR-18 (Sales Analytics), FR-19 (PayMongo Integration), FR-20 (Driver Workspace), FR-21 (Order Ratings)."]
    ]
    t_prio = doc.add_table(rows=1, cols=3)
    format_table(t_prio, [1.5, 1.8, 3.2], prio_headers, prio_data)

    # ── 4. UI/UX DESIGN AND ARCHITECTURE ───────────────────────────────────────
    add_h1("4. UI/UX Design and Architecture")
    add_h2("4.1 Screen List and Technical Implementation Notes")
    
    screen_headers = ["#", "Screen / Component", "Key UI Elements & Technical Implementation in Codebase"]
    screen_data = [
        ["1", "Login Screen", "Branded CafeGO logo, email & password fields, role detection, smooth tab switch between Sign In and Sign Up."],
        ["2", "Sign Up Screen", "Full name, email, Philippine phone (+63) input formatter, password validation, terms acknowledgement."],
        ["3", "Email Verification", "6-digit OTP entry screen for email verification prior to activation."],
        ["4", "Menu Home Screen", "Search bar, category filter chips (Hot, Iced, Non-Coffee, Pastries, Merch), coffee cards with photos and sold-out badges."],
        ["5", "Drink Customization", "Modal bottom sheet: size selector (S/M/L), milk alternatives, sugar level slider, ice level, add-on checkboxes, live price button."],
        ["6", "Cart Screen", "Detailed cart lines with custom options breakdown, quantity stepper (+/-), order special instructions note, checkout CTA."],
        ["7", "Checkout Screen", "Order type tab (Pickup / Dine-In with table number / Delivery with address), payment selector (Cash / Counter / GCash / Maya / Card)."],
        ["8", "Order Tracking Screen", "Real-time 4-step vertical status stepper, barista prep timer, delivery courier graphic, order summary drawer."],
        ["9", "Order Receipt Screen", "Digital customer receipt with unique order ID, timestamp, items breakdown, payment status, and order QR code."],
        ["10", "Order History Screen", "Chronological list of past orders with status chips, item counts, total spend, Track button, and one-tap Reorder button."],
        ["11", "Favorites Screen", "List of saved customer drinks with quick 'Add to Cart' action."],
        ["12", "Customer Profile", "User avatar, name, phone, email, saved delivery addresses manager, loyalty stamp summary, and logout button."],
        ["13", "Loyalty Rewards Screen", "Interactive 8-stamp loyalty card visualizer showing active earned coffee cups and free drink voucher code."],
        ["14", "Admin Dashboard", "Overview of store activity, quick navigation to catalog, inventory, and analytics."],
        ["15", "Menu Management", "Catalog table with search, item photo, base price, category, edit modal, and archive button."],
        ["16", "Item Form & Image Upload", "Form to add/edit menu items with category picker, price deltas, image picker, and Storage upload."],
        ["17", "Sold-Out / Inventory Switch", "Instant toggle per item to mark out-of-stock without deleting menu entries."],
        ["18", "Daily Sales Summary", "Visual charts showing today's order count, gross revenue, and revenue breakdown by payment type."],
        ["19", "Staff KDS Queue", "Kitchen display board with incoming tickets, elapsed timer, table numbers, and one-tap advance button."],
        ["20", "Driver Delivery Queue", "List of ready delivery orders, customer address, and distance."],
        ["21", "Driver Delivery Detail", "Interactive map view with coordinates, customer phone dialer, delivery notes, and delivery completion confirmation."]
    ]
    t_screen = doc.add_table(rows=1, cols=3)
    format_table(t_screen, [0.4, 2.0, 4.1], screen_headers, screen_data)

    add_h2("4.2 Navigation Architecture & Role-Based Guards")
    doc.add_paragraph(
        "Application routing is powered by 'go_router' with declarative state-driven redirects. "
        "A central 'RouterNotifier' listens to Riverpod's 'authProvider'. When auth state changes, routes are automatically guarded:\n"
        "• Unauthenticated users accessing private routes are redirected to '/login'.\n"
        "• Customers are restricted from '/admin/*', '/staff/*', and '/driver/*'.\n"
        "• Staff and Admins landing on default routes are redirected to their operational dashboards ('/staff' and '/admin').\n"
        "• Modals such as Drink Customization are loaded via ergonomic modal bottom sheets to prevent losing menu scroll position."
    )

    add_h2("4.3 Brand Color Palette")
    doc.add_paragraph("The application features the official CafeGO Artisanal Warm Coffee & Latte design system:")
    
    color_headers = ["Color Token Name", "Hex Code", "Light Mode Usage", "Dark Mode Usage"]
    color_data = [
        ["Brand Primary", "#5A3825 / #D4A373", "Deep Coffee Brown for primary buttons & titles", "Warm Amber accent for high dark-contrast"],
        ["Secondary (Crema)", "#D49755", "Warm crema accent, active status pill, borders", "Warm crema accent, highlights"],
        ["Canvas Background", "#F9F6F0 / #231F20", "Creamy Latte soft off-white canvas", "Deep Espresso warm charcoal dark surface"],
        ["Surface (Cards)", "#FFFFFF / #2E2728", "Crisp white card surfaces with subtle shadow", "Elevated warm mocha dark cards"],
        ["Text (Ink)", "#231714 / #F7F2EE", "Deep roasted espresso high-contrast text", "Soft milk foam off-white text"],
        ["Success", "#2E7D32", "Order completed, active in-stock, positive balance", "Order completed, active in-stock"],
        ["Warning / Prep", "#D97706", "Preparing order status, low stock warning", "Preparing order status, low stock warning"],
        ["Error / Danger", "#D6336C", "Cancelled order, validation failure, delete action", "Cancelled order, validation failure, delete action"]
    ]
    t_color = doc.add_table(rows=1, cols=4)
    format_table(t_color, [1.5, 1.3, 1.9, 1.8], color_headers, color_data)

    add_h2("4.4 Typography")
    doc.add_paragraph(
        "Typography is dynamically bundled using the 'google_fonts' package:\n"
        "• Headings, Brand Logo, and Price Badges: Rendered in 'Bricolage Grotesque' (semi-bold & extra-bold) with 'Playfair Display' accents, "
        "imparting a warm artisanal coffeehouse personality.\n"
        "• Body Text, Captions, and Form Inputs: Rendered in 'Figtree' (regular, medium, semi-bold) for optimal legibility at compact mobile scale."
    )

    add_h2("4.5 Ergonomics and UI Rationale")
    doc.add_paragraph(
        "The interface adopts a thumb-friendly ergonomic layout where high-frequency interactions (Add to Cart, Checkout, Status Advance) "
        "are docked in sticky bottom containers. Drink customization appears in a draggable bottom sheet so customers maintain visual context "
        "of the menu. High-contrast typography and semantic status chips guarantee clarity for baristas working in fast-paced cafe environments."
    )

    # ── 5. TECHNICAL PLAN AND FIREBASE DESIGN ──────────────────────────────────
    add_h1("5. Technical Plan and Firebase Design")
    add_h2("5.1 Technology Stack")
    
    tech_headers = ["Layer / Domain", "Technology Choice", "Justification & Usage in CafeGO"]
    tech_data = [
        ["Language & SDK", "Dart 3.5+ / Flutter Framework", "Cross-platform high-performance rendering, strong typing, declarative UI."],
        ["State Management", "flutter_riverpod (^2.5.1)", "Compile-safe, decoupled state providers without BuildContext dependency."],
        ["Navigation", "go_router (^14.3.0)", "Declarative routing with deep linking and strict role-based redirect guards."],
        ["Backend as a Service", "Firebase Suite", "Firebase Auth, Cloud Firestore, Firebase Storage, Cloud Functions, and FCM."],
        ["Local Storage", "shared_preferences (^2.3.2)", "Caches local session preferences and offline cart backups."],
        ["Mapping & Coordinates", "flutter_map & latlong2", "Renders open-source Leaflet map views for delivery driver navigation."],
        ["Testing & Mocking", "flutter_test, fake_cloud_firestore, firebase_auth_mocks, mocktail", "Comprehensive unit and widget test suite executing 170+ automated deterministic tests."],
        ["CI / CD Pipeline", "GitHub Actions", "Automated linting, test execution, and deployment to GitHub Pages on every commit."]
    ]
    t_tech = doc.add_table(rows=1, cols=3)
    format_table(t_tech, [1.5, 1.8, 3.2], tech_headers, tech_data)

    add_h2("5.2 Firebase Cloud Services Breakdown")
    fb_headers = ["Firebase Service", "Role and Architectural Function in CafeGO Order"]
    fb_data = [
        ["Firebase Authentication", "Handles customer and staff identity lifecycle, secure password hashing, session tokens, and RBAC custom claims."],
        ["Cloud Firestore", "NoSQL document database providing low-latency reactive streams for menu items, order queues, customer profiles, and analytics."],
        ["Firebase Storage", "Secure binary object storage hosting high-resolution menu beverage and pastry photography."],
        ["Cloud Functions", "Server-side order total validation, automated loyalty stamp calculation, and scheduled sales rollups."],
        ["Cloud Messaging (FCM)", "Dispatches push notifications when order status changes to 'Ready for Pickup' or 'Out for Delivery'."],
        ["Firestore Security Rules", "Enforces server-side authorization: public catalog read, customer record privacy, and staff-only status mutations."]
    ]
    t_fb = doc.add_table(rows=1, cols=2)
    format_table(t_fb, [1.8, 4.7], fb_headers, fb_data)

    add_h2("5.3 Firestore Database Schema")
    doc.add_paragraph("The database follows a clean, denormalized NoSQL architecture optimized for real-time reads:")
    
    schema_headers = ["Collection Path", "Document Key Fields & Types", "Relationship & Security Rules"]
    schema_data = [
        ["users/{uid}", "name (str), email (str), phone (str), role ('customer'|'staff'|'admin'|'driver'), favorites (array[str]), stamps (int), addresses (array[map]), createdAt (timestamp)", "User profile document. Readable/writable by owner; role mutations restricted to admin."],
        ["menu/{itemId}", "name (str), category (str), description (str), basePrice (num), imageUrl (str), isAvailable (bool), isHidden (bool), options (map: sizes, milks, sugar, ice, addOns)", "Publicly readable; mutations restricted to staff and admin."],
        ["orders/{orderId}", "userId (str), userName (str), items (array[map]), subtotal (num), deliveryFee (num), total (num), type ('pickup'|'dine-in'|'delivery'), tableNo (str), address (str), payment (str), status ('received'|'preparing'|'ready'|'completed'|'cancelled'), createdAt (timestamp)", "Owner creates & reads; staff/admin read & update status. Items denormalized to freeze price at purchase."],
        ["sales/{yyyy-MM-dd}", "date (str), orderCount (int), totalRevenue (num), paymentBreakdown (map)", "Aggregated sales ledger updated via backend service; staff/admin read-only."],
        ["ratings/{orderId}", "orderId (str), userId (str), rating (int 1-5), feedback (str), createdAt (timestamp)", "Customer feedback on completed orders."]
    ]
    t_schema = doc.add_table(rows=1, cols=3)
    format_table(t_schema, [1.5, 3.2, 1.8], schema_headers, schema_data)

    add_h2("5.4 Architectural Component Breakdown")
    doc.add_paragraph(
        "The codebase enforces strict separation of concerns into distinct layers:\n"
        "• lib/backend/models: Immutable typed data entities (UserProfile, MenuItem, CartLine, Order, SalesSummary) with robust fromMap/toMap serialization.\n"
        "• lib/backend/repositories: Abstract and concrete repository implementations (AuthRepository, MenuRepository, OrderRepository, CartRepository, ReportsRepository) encapsulating all Firebase operations.\n"
        "• lib/backend/services: External service integrations (PayMongoService, LocationService, NotificationService, SecurityService).\n"
        "• lib/core: App-wide constants, failures, and formatting utilities (Philippine phone formatter, currency helpers).\n"
        "• lib/frontend/features: Presentation layer organized by domain (auth, menu, cart, checkout, orders, profile, admin, staff, driver).\n"
        "• lib/frontend/navigation: Declarative GoRouter configuration with role-based redirect guards.\n"
        "• lib/frontend/theme: Centralized design system tokens, ColorScheme, and typography definitions."
    )

    # ── 6. TEAM ORGANIZATION AND TIMELINE ──────────────────────────────────────
    add_h1("6. Team Organization and Timeline")
    add_h2("6.1 Members and Responsibilities")
    
    team_headers = ["Member Name", "Assigned Project Role", "Primary Technical Responsibilities"]
    team_data = [
        ["Glenn Mykhel Gulfan", "Project Lead & Backend Engineer", "Project architecture, Firebase project configuration, Firestore schema design & Security Rules, Order state machine, PayMongo payment service, CI/CD pipeline."],
        ["Ranela Esgana", "Auth, Security & Profile Lead", "Authentication flows (Sign-up, Login, OTP verification), User Profiles, Saved Delivery Addresses, Favorites data management, User testing."],
        ["Sean", "Customer UI/UX Specialist", "Catalog presentation, live Drink Customization bottom sheet, Cart management, Checkout UX, Order Tracking stepper, Theme assets."],
        ["Jayshan", "Admin, Staff KDS & QA Lead", "Staff KDS queue, Admin catalog management, sold-out toggles, daily sales summary, automated test suite, documentation compilation."]
    ]
    t_team = doc.add_table(rows=1, cols=3)
    format_table(t_team, [1.6, 1.8, 3.1], team_headers, team_data)

    add_h2("6.2 Module Distribution Matrix")
    mod_headers = ["Functional Module", "Primary Owner", "Collaborating Support"]
    mod_data = [
        ["Project Setup, Git Workflow & CI/CD", "Glenn Mykhel Gulfan", "All Members"],
        ["Data Models & Firebase Repositories", "Glenn Mykhel Gulfan", "Ranela Esgana"],
        ["Auth Screens & Role-Based Routing", "Glenn Mykhel Gulfan", "Ranela Esgana"],
        ["Menu Catalog & Drink Customization", "Sean", "Jayshan"],
        ["Cart, Checkout & PayMongo Gateway", "Glenn Mykhel Gulfan", "Ranela Esgana"],
        ["Staff KDS Queue & Order Advancement", "Glenn Mykhel Gulfan", "Jayshan"],
        ["Admin Catalog & Inventory Toggles", "Glenn Mykhel Gulfan", "Jayshan"],
        ["Brand Theme & Reusable Widgets", "Sean", "Jayshan"],
        ["Automated Test Cases & Documentation", "All Members", "All Members"]
    ]
    t_mod = doc.add_table(rows=1, cols=3)
    format_table(t_mod, [2.5, 2.0, 2.0], mod_headers, mod_data)

    add_h2("6.3 Development Schedule and Milestones")
    mile_headers = ["Timeline Milestone", "Key Activities & Deliverables Accomplished"]
    mile_data = [
        ["Weeks 1 to 2: Proposal & Approval", "Project concept formulation, problem statement definition, feature scope boundary, Firebase service planning, team role assignments."],
        ["Weeks 3 to 4: Design & Prototyping", "Interactive HTML UI prototype, Flutter project scaffolding, theme configuration, navigation skeleton, Firebase connection established."],
        ["Pre-Final Presentation Milestone", "Working prototype demonstrated with live Firebase Auth, Firestore real-time menu loading, cart management, and order placement."],
        ["Weeks 5 to 7: Full System Development", "Complete implementation of 4 RBAC workspaces (Customer, Staff KDS, Admin, Driver), PayMongo integration, instant inventory toggles."],
        ["Week 8 onward: Hardening & Final Submission", "Comprehensive unit and widget testing (170 automated test cases), security audit, documentation in .docx, final live demonstration."]
    ]
    t_mile = doc.add_table(rows=1, cols=2)
    format_table(t_mile, [2.2, 4.3], mile_headers, mile_data)

    add_h2("6.4 Quality Assurance & Testing Strategy")
    doc.add_paragraph(
        "To guarantee rock-solid stability and prevent regression:\n"
        "• Test-Driven Development (TDD): Domain business logic (cart pricing, delivery fees, order state transitions) is unit-tested using 'fake_cloud_firestore' and 'firebase_auth_mocks'.\n"
        "• Widget Testing: Every primary user journey (Login, Menu, Cart, Checkout, KDS) is validated using Flutter widget tests.\n"
        "• 170 Passed Automated Tests: The current project codebase achieves a 100% pass rate across all 170 test cases.\n"
        "• Continuous Integration: GitHub Actions executes 'flutter analyze' and 'flutter test' automatically on all pull requests."
    )

    add_h2("6.5 Pre-Final Demonstration Checklist")
    chk_headers = ["Academic Requirement Item", "Verification Evidence in Codebase", "Status"]
    chk_data = [
        ["Approved Project Proposal", "Full documentation covering Objectives, Scope, and Architecture", "PASSED"],
        ["Flutter Project Runs on Target", "Compiled and verified on Android Emulator & Flutter Web", "PASSED"],
        ["Initial Screens & Navigation", "21 screens implemented matching CafeGO Warm Coffee design", "PASSED"],
        ["Firebase Project Connected", "Configured via firebase_core, google-services.json & options", "PASSED"],
        ["Live Proof of Concept", "Authentication creates user in Firestore; catalog streams in real time", "PASSED"],
        ["Team Member Explanations", "All roles mapped with distinct code ownership and commit history", "PASSED"]
    ]
    t_chk = doc.add_table(rows=1, cols=3)
    format_table(t_chk, [2.2, 3.4, 0.9], chk_headers, chk_data)

    # Save to outputs
    out_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(out_dir, ".."))
    
    file_root = os.path.join(project_root, "CafeGO_Order_PreFinal_Documentation.docx")
    file_docs = os.path.join(project_root, "docs", "CafeGO_Order_PreFinal_Documentation.docx")
    
    doc.save(file_root)
    print(f"Saved: {file_root}")
    
    os.makedirs(os.path.join(project_root, "docs"), exist_ok=True)
    doc.save(file_docs)
    print(f"Saved: {file_docs}")

if __name__ == "__main__":
    build_document()
