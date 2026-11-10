# CafeGO RBAC Refactoring Implementation Plan
**Project**: Strict Role-Based Access Control (RBAC) across authentication, routing, and business logic
**Status**: Batch 1 ✅ COMPLETE | Batch 2 📋 READY | Batch 3 📋 READY
**Last Updated**: November 10, 2026

---

## PROJECT OVERVIEW

### Objectives
1. **Enforce Strict RBAC**: Admin, Staff, Driver, Customer roles with isolated UIs
2. **Remove Customer Ordering from Admin**: Clean separation of concerns
3. **Fix Staff Order Queue**: FIFO sorting with prep timer and interactive order details
4. **Implement Payment Handling**: Staff process cash/COD transactions with records
5. **Add Driver Workspace**: Accept deliveries, live tracking, earnings, rating system
6. **Business Analytics**: Revenue by payment type, product financials, payroll management

### Target Completion: 40-51 hours (3 batches)
- **Batch 1**: ✅ 1.5 hours (COMPLETE)
- **Batch 2**: 📋 21-26 hours (READY)
- **Batch 3**: 📋 18-24 hours (READY)

---

## BATCH 1: Core Auth & Strict Role-Based Routing ✅ COMPLETE

### Status: ✅ DEPLOYED TO GITHUB
- **Commit**: `c5ee718` - "Batch 1: Core Auth & Strict Role-Based Routing"
- **Branch**: `main`
- **CI/CD**: GitHub Actions running
- **Live App**: https://mykhelcs.github.io/orderacoffee/

### Completed Tasks

#### Task 1.1: Update UserProfile Model
**File**: `lib/backend/models/user_profile.dart`

**Changes**:
- ✅ Added driver role support (4 roles: admin, staff, driver, customer)
- ✅ Added `isDriver` getter → `role == 'driver'`
- ✅ Added `isCoreStaff` getter → `role == 'staff'` (staff-only, no admins)
- ✅ Added 5 driver-specific fields:
  - `vehicleType: String?` (motorcycle, car, van)
  - `vehicleNumber: String?` (license plate)
  - `isAvailable: bool` (driver online/offline, default false)
  - `currentDeliveryId: String?` (current order ID)
  - `totalDeliveries: int` (lifetime delivery count, default 0)
  - `averageRating: double?` (1-5 stars driver rating)
- ✅ Updated `fromMap()` factory with all new fields
- ✅ Updated `toMap()` serialization with all new fields
- ✅ Updated `copyWith()` with all new fields
- ✅ Updated equality operators (`==`, `hashCode`) with all new fields

**Verification**: ✅ Type-safe, backward compatible, Firestore-ready

---

#### Task 1.2: Verify Auth Registration Flow
**Files**: 
- `lib/backend/repositories/auth_repository.dart` (line ~239)
- `lib/frontend/features/auth/auth_provider.dart`

**Status**: ✅ ALREADY IMPLEMENTED
- ✅ New signups automatically assigned role='customer'
- ✅ Admin email detection assigns role='admin'
- ✅ `confirmEmailVerification()` calls `_authRepo.signUp()` which creates customer profile
- ✅ No changes required

---

#### Task 1.3: Enhance Router with Strict Role Guards
**File**: `lib/frontend/navigation/router.dart`

**Changes**:
- ✅ Enhanced `RouterNotifier.redirect()` with comprehensive role-based logic
- ✅ Extracted role from `authState.profile?.role`
- ✅ Defined route prefixes: admin, staff, driver, customer
- ✅ Implemented strict role guards:
  - Admin routes (`/admin/*`) → only `role='admin'`
  - Staff routes (`/staff/*`) → only `role='staff'` (not admin)
  - Driver routes (`/driver/*`) → only `role='driver'`
  - Customer routes (`/`, `/cart`, `/orders`, `/profile`) → only `role='customer'`
- ✅ Added cross-role redirects (prevent URL manipulation)
- ✅ Added auto-redirect post-login (admin→/admin, staff→/staff, driver→/driver, customer→/)
- ✅ Organized route structure with clear comments

**Redirect Table**:
| Role | Initial Redirect | Accessible | Blocked |
|------|------------------|-----------|---------|
| admin | /admin | /admin/* | /staff/*, /driver/*, /checkout |
| staff | /staff | /staff/* | /admin/*, /driver/*, /checkout |
| driver | /driver | /driver/* | /admin/*, /staff/*, /checkout |
| customer | / | /, /cart, /checkout, /orders | /admin/*, /staff/*, /driver/* |

**Verification**: ✅ Compiles without errors, all guards functional

---

#### Task 1.4: Verify Shared Auth UI
**Status**: ✅ ALREADY IMPLEMENTED (No Changes Needed)
- ✅ Login screen (`LoginScreen`) - shared by all roles
- ✅ Sign up screen (`SignUpScreen`) - defaults to customer
- ✅ Email verification screen (`EmailVerificationScreen`) - shared
- ✅ Landing screen (`LandingScreen`) - public entry

---

### Files Modified in Batch 1
| File | Changes | Lines |
|------|---------|-------|
| `lib/backend/models/user_profile.dart` | Added driver role + 5 fields, updated getters/serialization | 120+ |
| `lib/frontend/navigation/router.dart` | Enhanced redirect logic, strict guards, route reorganization | 140+ |

### Database Schema (Batch 1)
No schema changes required. All new fields supported by existing Firestore structure.

### Testing Checklist ✅
- [x] UserProfile deserializes with all new driver fields
- [x] Router compiles without errors
- [x] Login redirects admin to /admin
- [x] Login redirects staff to /staff
- [x] Login redirects customer to /
- [x] Customer cannot access /admin URL
- [x] Admin trying /cart redirects to /admin
- [x] Staff trying /admin redirects to /staff

---

## BATCH 2: Admin UI Refactoring & New Modules (READY)

### Overview
Remove customer ordering from admin. Add 6 management screens: Menu, Inventory, Analytics, Users, Payroll, Dashboard.

### Phase Breakdown

#### Phase 1: Data Models & Repositories (3-4 hours)
**Files to Create/Modify**:
1. Update `lib/backend/models/order.dart` - add driver/payment tracking fields
2. Update `lib/backend/models/menu_item.dart` - add stock/cost fields
3. Create `lib/backend/models/payroll.dart` - salary model
4. Create `lib/backend/repositories/payroll_repository.dart` - 6 CRUD methods
5. Expand `lib/backend/repositories/reports_repository.dart` - analytics methods

**Key Models**:
```dart
// Order additions
driverId: String?
driverStartedAt: Timestamp?
driverCompletedAt: Timestamp?
driverRating: double?
paymentHandledBy: String?
paymentHandledAt: Timestamp?

// MenuItem additions
stock: int
costPerUnit: double
createdAt: Timestamp?

// Payroll model
employeeId, role, baseSalary, allowances, deductions
commissionPerDelivery, totalDeliveries, totalCommission
netPay, payPeriod, status, paidAt, createdAt
```

**Repository Methods**:
- `PayrollRepository.getPayrollByPeriod(period, role?)`
- `PayrollRepository.createPayrollEntry(Payroll)`
- `PayrollRepository.markPayrollAsPaid(payrollId)`
- `ReportsRepository.getTotalRevenueByPaymentType(start, end)` → {cod, online, counter}
- `ReportsRepository.getOrderCountByPaymentType(start, end)` → {cod, online, counter}
- `ReportsRepository.getProductFinancials()` → financials with cost/revenue/margin

#### Phase 2: Providers (2 hours)
**Files to Create/Modify**:
1. Expand `lib/frontend/features/admin/admin_provider.dart` - menu/item management
2. Create `lib/frontend/features/admin/payroll_provider.dart` - salary state

**Provider Methods**:
- `AdminNotifier.editMenuItem(MenuItem)`
- `AdminNotifier.createMenuItem(MenuItem)`
- `AdminNotifier.updateMenuItemStock(itemId, newStock)`
- `PayrollNotifier.editSalary(payrollId, baseSalary, allowances)`
- `PayrollNotifier.markAsPaid(payrollId)`

#### Phase 3: Admin UI Screens (12-16 hours - can parallelize)

**3.3.1 Menu Management Screen** (2-3 hours)
- **File**: Create `lib/frontend/features/admin/screens/menu_management_screen.dart`
- **Features**:
  - Grid/list of menu items with images
  - Quick stock adjust with ±buttons
  - Add New Item button (+)
  - Edit item sheet (name, category, price, stock, cost, modifiers, add-ons)
  - Delete with confirmation
  - Real-time refresh on changes
- **UI Components**: Item cards, edit form, dialogs

**3.3.2 Inventory & Product Financials** (2-3 hours)
- **File**: Create `lib/frontend/features/admin/screens/inventory_screen.dart`
- **Features**:
  - Summary cards: total spend, revenue, margin, low stock alerts
  - Sortable table: name, category, cost, units sold, revenue, stock, margin
  - Filter: category, low stock (<5 units)
  - Restock flow: add units + cost
  - Export to CSV/PDF
- **UI Components**: Data table, filter controls, restock dialog

**3.3.3 Analytics - Revenue by Payment Type** (2 hours)
- **File**: Update `lib/frontend/features/admin/screens/analytics_screen.dart`
- **Features**:
  - Revenue cards: COD, Online (PayMongo), Counter (Cash)
  - Total revenue, order count, average per method
  - Pie chart (revenue split), bar chart (order count)
  - Date range: Today, Week, Month, Custom
  - Export to PDF
- **UI Components**: Cards, charts, date picker

**3.3.4 User Management Directory** (2 hours)
- **File**: Create `lib/frontend/features/admin/screens/user_management_screen.dart`
- **Features**:
  - Filter tabs: All, Customers, Staff, Drivers, Admins
  - Search by name/email
  - User cards: avatar, name, email, role badge, status
  - Action menu: view, promote, demote, delete
  - Role change modal with confirmation
  - Prevent self-demotion from admin
- **UI Components**: Filter tabs, search bar, user cards, role modal

**3.3.5 Payroll Management** (2 hours)
- **File**: Create `lib/frontend/features/admin/screens/payroll_screen.dart`
- **Features**:
  - Summary card: total payroll, staff/driver counts, paid/pending status
  - Filter: role (all/staff/drivers), period, status
  - Payroll table: name, role, base, allowances, commission, deductions, net pay, status
  - Edit salary: base, allowances, deductions, commission/delivery
  - Mark as paid: confirmation, notification
  - Export to PDF with signatures
- **UI Components**: Data table, filter controls, edit modal, export button

**3.3.6 Admin Dashboard Update** (1-2 hours)
- **File**: Update `lib/frontend/features/admin/admin_screen.dart`
- **Changes**:
  - Replace/reorganize navigation tabs: Orders, Menu, Inventory, Analytics, Users, Payroll
  - Route each tab to corresponding screen
  - Remove any cart/checkout UI references
  - Verify no customer features visible
- **Verification**: All tabs load, proper role guards in place

#### Phase 4: Clean Up & Testing (4 hours)
**Actions**:
- Remove Add to Cart buttons from admin menu display
- Remove cart drawer access from admin
- Remove checkout navigation from admin
- Add route guard to prevent admin accessing /checkout
- Test all role-based access controls
- Verify analytics calculations accurate
- Test payroll commission calculations for drivers

**Testing Checklist**:
- [ ] Create menu item works
- [ ] Edit/delete menu items functions
- [ ] Quick stock adjust immediate Firestore update
- [ ] Product financials calculate correctly (cost × sold)
- [ ] Low stock alerts for < 5 units
- [ ] Revenue by payment type totals match orders
- [ ] Date filter updates analytics
- [ ] User search finds by name/email
- [ ] Role promotion updates user
- [ ] Cannot demote self from admin
- [ ] Salary calculations correct
- [ ] Commission calculations for drivers correct
- [ ] Payroll export generates PDF
- [ ] Admin cannot access /checkout
- [ ] No customer features in admin UI

### Database Schema Additions (Batch 2)
**Firestore Collections/Fields**:
- `menu` items: Add `stock: int`, `costPerUnit: double`, `createdAt: timestamp`
- `orders`: Add `paymentHandledBy: string?`, `paymentHandledAt: timestamp?`, driver fields
- New `payroll` collection: Documents with employee salary data

**Security Rules**:
- Allow admin to create/edit/delete menu items
- Allow admin to view all orders and analytics
- Allow admin to create/edit payroll entries

### Estimated Effort: 21-26 hours

---

## BATCH 3: Staff UI & Interactive Order Queue (READY)

### Overview
Implement staff order management, driver delivery workspace, and payment handling.

### Phase Breakdown

#### Phase 1: Staff Order Queue Screen (3-4 hours)
**File**: Create `lib/frontend/features/staff/staff_order_queue_screen.dart`

**Features**:
- FIFO sorting by `createdAt` (oldest first)
- Queue sections: Received (red), Preparing (yellow), Ready (green)
- Each order card shows:
  - Order ID, type badge (Pickup/Delivery/Dine-in)
  - Prep timer (live elapsed time ⏱️)
  - Item preview (first 2-3 items)
  - Current status
- Click card → opens interactive detail sheet
- Real-time updates (stream listener)
- Auto-move orders between sections on status change

**UI Component**: `lib/frontend/features/staff/order_queue_card.dart`

---

#### Phase 2: Interactive Order Detail Sheet (2-3 hours)
**File**: Create `lib/frontend/features/staff/order_detail_sheet.dart`

**Features**:
- Order header: ID, type, customer (if applicable), prep timer
- Customer notes/special instructions (prominent)
- Full item list with quantities:
  - Size, Milk, Sugar, Ice, Shots, Add-ons
  - Item-specific notes
- Order summary: subtotal, fees, total
- Context-aware status buttons:
  - Received → "Start Preparing" button
  - Preparing → "Mark Ready" button
  - Ready + Pickup → "Mark as Completed" button
  - Ready + Delivery → "Ready for Pickup" button
  - Ready + Dine-in → "Mark as Served" button
  - Any → "Cancel Order" button (with confirmation)
- Payment pending badge (if applicable)
- "Receive Payment" button (if Pay at Counter)

**Functionality**:
- Status button updates `order.status` in Firestore
- Queue auto-updates (order moves to new section)
- Toast confirmation on success
- Sheet closes on action

---

#### Phase 3: Payment Input & Cash Handling (2-3 hours)
**Files**: 
- Create `lib/frontend/features/staff/payment_input_sheet.dart`
- Create `lib/frontend/features/staff/payment_records_screen.dart`

**Payment Input Sheet**:
- Display order total (₱)
- Input field: Amount received
- Calculate change (received - total)
- Confirm button:
  - Update `order.paymentStatus = 'paid'`
  - Set `order.paymentHandledBy = staff.uid`
  - Set `order.paymentHandledAt = now`
  - Show receipt preview
  - Toast: "Payment received! (Change: ₱X.XX)"

**Payment Records Screen**:
- Filter by date: Today, Week, Month, Custom
- Display cash/COD transactions:
  - Order ID, customer, amount, timestamp, staff
- Click transaction → detail view (full order + payment info)
- Daily summary: total cash, count, COD breakdown
- Print receipt button
- Export daily summary to CSV/PDF

---

#### Phase 4: Driver Role & Delivery Workspace (4-5 hours)
**Files**:
- Create `lib/frontend/features/driver/driver_delivery_screen.dart`
- Create `lib/frontend/features/driver/delivery_card.dart`
- Create `lib/frontend/features/driver/delivery_detail_sheet.dart`
- Create `lib/frontend/features/driver/delivery_history_screen.dart`

**Driver Dashboard**:
- Header: Online/Offline toggle, vehicle info (type + plate), today's earnings (₱), rating (⭐)
- **Active Delivery** (if `currentDeliveryId`):
  - Full-screen map: branch → customer location
  - Customer address, phone, notes
  - Items summary
  - Actions: "Start Navigation", "Arrived at Customer", "Delivery Complete"
- **If No Active**: "You're all caught up!" message + refresh
- **Available Deliveries Queue**:
  - List of orders with `status='ready'` and `driverId=null`
  - Sort by distance from driver (closest first)
  - Card: Order ID, customer, address, distance (km), delivery time estimate
  - "Accept Delivery" button
- **Accept Flow**:
  - Confirmation dialog
  - Update `order.driverId = driver.uid`
  - Update `order.status = 'out_for_delivery'`
  - Update `driver.currentDeliveryId = orderId`
  - Show active delivery
  - Toast: "Delivery accepted! 🎉"

**Delivery History Tab**:
- Filter: date range, status
- Show completed deliveries:
  - Order ID, customer, address, earnings, customer rating, timestamp
- Click → detail view (full order + delivery timeline + rating)
- Summary: total earnings, count, average rating, on-time %

**Real-time Location Tracking**:
- Start background location service on delivery acceptance
- Update `order.riderLat`, `order.riderLng` every 10 seconds
- Customer sees live driver location on tracking map
- Stop tracking on delivery completion

**Driver Rating System**:
- On delivery completed:
  - Show 5-star rating sheet
  - Optional review text field
  - Submit updates `order.driverRating` + recalculates `driver.averageRating`

---

#### Phase 5: Providers & Repositories (2 hours)
**Files**:
- Create methods in `lib/backend/repositories/order_repository.dart`:
  - `getAvailableDeliveries()` → Stream of ready orders without driverId
  - `acceptDelivery(orderId, driverId)` → assign driver
  - `updateDriverLocation(driverId, lat, lng)` → real-time GPS
  - `completeDelivery(orderId)` → mark done, trigger rating

- Create `lib/frontend/features/driver/driver_provider.dart`:
  - `availableDeliveriesProvider` - StreamProvider
  - `driverStatsProvider(driverId)` - FutureProvider
  - `driverDeliveriesProvider` - StreamProvider

---

#### Phase 6: Testing & Polish (2-3 hours)
**Testing Checklist**:
- [ ] Orders sorted FIFO (oldest first)
- [ ] Prep timer counts up correctly
- [ ] Status buttons appear based on current status
- [ ] Status update reflects in queue immediately
- [ ] Payment handling logs transaction correctly
- [ ] Cash receipts print/export
- [ ] Driver accepts delivery successfully
- [ ] Location updates in real-time (every 10 sec)
- [ ] Delivery complete triggers rating sheet
- [ ] Driver rating calculates average correctly
- [ ] Driver earnings calculated per delivery
- [ ] All role-based access working
- [ ] End-to-end flow: order → staff manage → driver deliver → rate

### Database Schema Additions (Batch 3)
**Orders Collection**:
- From Batch 2: `driverId`, `driverStartedAt`, `driverCompletedAt`, `driverRating`
- From Batch 2: `paymentHandledBy`, `paymentHandledAt`

**Users Collection**:
- From Batch 1: driver fields (vehicleType, vehicleNumber, isAvailable, etc.)

**Security Rules**:
- Allow drivers to update own location
- Allow drivers to accept/complete deliveries
- Allow drivers to submit ratings

### Estimated Effort: 18-24 hours

---

## COMPLETION STATUS

### Batch 1: ✅ COMPLETE
- [x] Task 1.1: Update UserProfile with driver role + 5 fields
- [x] Task 1.2: Verify auth registration flow (customer default)
- [x] Task 1.3: Implement strict role-based router guards
- [x] Task 1.4: Verify shared auth UI
- [x] Deployed to GitHub (commit c5ee718)
- [x] CI/CD running

### Batch 2: 📋 READY
- [ ] Phase 1: Models & Repositories (3-4 hours)
- [ ] Phase 2: Providers (2 hours)
- [ ] Phase 3.1-3.6: 6 Admin Screens (12-16 hours)
- [ ] Phase 4: Clean Up & Testing (4 hours)

### Batch 3: 📋 READY
- [ ] Phase 1: Staff Queue (3-4 hours)
- [ ] Phase 2: Order Detail Sheet (2-3 hours)
- [ ] Phase 3: Payment & Cash Handling (2-3 hours)
- [ ] Phase 4: Driver Workspace (4-5 hours)
- [ ] Phase 5: Providers & Repos (2 hours)
- [ ] Phase 6: Testing (2-3 hours)

---

## Files & Artifacts Reference

### GitHub Deployment
- **Repo**: https://github.com/mykhelcs/orderacoffee
- **Latest Commit**: `c5ee718` - Batch 1: Core Auth & Strict Role-Based Routing
- **Branch**: `main`
- **Live App**: https://mykhelcs.github.io/orderacoffee/
- **Actions**: https://github.com/mykhelcs/orderacoffee/actions

### Documentation Artifacts (Session)
1. **CafeGO RBAC Refactoring Plan - 3 Batches** - Overview of entire project
2. **CafeGO RBAC - Task Breakdown & Checklist** - 14 tasks with checkboxes
3. **✅ BATCH 1 Complete** - Completion report
4. **BATCH 2 Implementation Plan** - Phase-by-phase detailed spec
5. **CafeGO RBAC - Executive Summary** - Complete project overview
6. **CafeGO RBAC - Master Implementation Checklist** - 100+ items all batches

### Key Files by Role
**Admin**:
- `lib/frontend/features/admin/admin_screen.dart` - Dashboard (to update Batch 2)
- `lib/frontend/features/admin/admin_provider.dart` - State management

**Staff** (Batch 3):
- `lib/frontend/features/staff/staff_order_queue_screen.dart` - Queue (to create)
- `lib/frontend/features/staff/order_detail_sheet.dart` - Order details (to create)
- `lib/frontend/features/staff/payment_records_screen.dart` - Payment history (to create)

**Driver** (Batch 3):
- `lib/frontend/features/driver/driver_delivery_screen.dart` - Dashboard (to create)
- `lib/frontend/features/driver/delivery_history_screen.dart` - History (to create)

**Auth & Models**:
- `lib/backend/models/user_profile.dart` - ✅ Updated (Batch 1)
- `lib/frontend/navigation/router.dart` - ✅ Updated (Batch 1)
- `lib/frontend/features/auth/auth_provider.dart` - Verified (Batch 1)

---

## Progress Summary
- **Batch 1**: ✅ 100% Complete (1.5 / 1.5 hours)
- **Batch 2**: 📋 0% (0 / 21-26 hours)
- **Batch 3**: 📋 0% (0 / 18-24 hours)
- **Total**: 3.3% Complete (1.5 / 40-51 hours)

---

## Next Steps
1. ✅ **Batch 1**: Review & test role-based redirects on live app
2. 📋 **Batch 2**: Start Phase 1 (Models & Repositories) when ready
3. 📋 **Batch 3**: Start after Batch 2 complete or parallelize Phases 1-2

