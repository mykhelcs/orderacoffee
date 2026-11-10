# CafeGO Firebase Test Accounts Setup

**Project**: `coughfee-app`
**Created**: November 10, 2026
**Purpose**: Test RBAC implementation with accounts for all 4 roles

---

## Test Account Credentials

### 🔐 Admin Account
```
Email:    admin@cafego.ph
Password: Admin@123456
Role:     admin
Name:     Admin User
Phone:    +63912345601
UID:      8sJe87j7TMM0cCzGsuM4YkPMZeA2
Status:   ✅ Provisioned (Auth + Firestore)
```

### 👨‍💼 Staff Account
```
Email:    staff@cafego.ph
Password: Staff@123456
Role:     staff
Name:     Staff User
Phone:    +63912345602
UID:      Es1dTJTuIjcUnp0dvQSR9oWeRJl2
Status:   ✅ Provisioned (Auth + Firestore)
```

### 🚗 Driver Account
```
Email:       driver@cafego.ph
Password:    Driver@123456
Role:        driver
Name:        Driver User
Phone:       +63912345603
Vehicle:     Motorcycle
License:     ABC-1234
UID:         RWy68IJ9vGMZo8TZM1MTVxRECXh1
Status:      ✅ Provisioned (Auth + Firestore)
```

### 👥 Customer Account
```
Email:    customer@cafego.ph
Password: Customer@123456
Role:     customer
Name:     Customer User
Phone:    +63912345604
UID:      trKExqOCWsPqEOWEe1xnqiy7Q3S2
Status:   ✅ Provisioned (Auth + Firestore)
```

---

## Firebase Setup Options

### Option 1: Firebase Console (Manual) ⭐ RECOMMENDED FOR TESTING

**Steps**:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `coughfee-app`
3. Go to **Authentication** > **Users**
4. Click **Add user** button for each account
5. Create with credentials above
6. Once created, verify user exists in Firestore

**Then set roles in Firestore**:
1. Go to **Firestore Database**
2. Find `users` collection
3. For each user, click edit and add/update:
   - `role: "admin"` (for admin user)
   - `role: "staff"` (for staff user)
   - `role: "driver"` (for driver user)
   - `role: "customer"` (for customer user)

---

### Option 2: Firebase CLI (Recommended for Bulk Operations)

**Prerequisites**:
- Firebase CLI installed: `firebase --version` (already installed ✅)
- Authenticated: `firebase login`

**Step 1: Export Existing Users**
```bash
cd c:\Users\Rane\CafeGo\orderacoffee
firebase auth:export users.json --project coughfee-app
```

**Step 2: Create Import File** (`test_users.json`)
```json
{
  "users": [
    {
      "localId": "admin-uid-001",
      "email": "admin@cafego.ph",
      "emailVerified": true,
      "passwordHash": "hash_will_be_ignored",
      "displayName": "Admin User",
      "customAttributes": {
        "role": "admin"
      },
      "createdAt": 1730000000000
    },
    {
      "localId": "staff-uid-001",
      "email": "staff@cafego.ph",
      "emailVerified": true,
      "passwordHash": "hash_will_be_ignored",
      "displayName": "Staff User",
      "customAttributes": {
        "role": "staff"
      },
      "createdAt": 1730000000001
    },
    {
      "localId": "driver-uid-001",
      "email": "driver@cafego.ph",
      "emailVerified": true,
      "passwordHash": "hash_will_be_ignored",
      "displayName": "Driver User",
      "customAttributes": {
        "role": "driver"
      },
      "createdAt": 1730000000002
    },
    {
      "localId": "customer-uid-001",
      "email": "customer@cafego.ph",
      "emailVerified": true,
      "passwordHash": "hash_will_be_ignored",
      "displayName": "Customer User",
      "customAttributes": {
        "role": "customer"
      },
      "createdAt": 1730000000003
    }
  ]
}
```

**Step 3: Import Users**
```bash
firebase auth:import test_users.json --project coughfee-app
```

---

### Option 3: App Registration Flow (Best for E2E Testing)

**Step 1: Open the App**
- Go to: https://mykhelcs.github.io/orderacoffee/

**Step 2: Create Each Account**
- Click "Sign Up"
- Enter credentials from above
- Verify email (use test email or skip if configured)
- Each signup defaults to `role: "customer"`

**Step 3: Set Correct Roles**
- After signup, accounts are created with `role: "customer"`
- Go to Firebase Console > Firestore
- Update each user's role document:
  - `admin@cafego.ph` → set `role: "admin"`
  - `staff@cafego.ph` → set `role: "staff"`
  - `driver@cafego.ph` → set `role: "driver"` + add driver fields
  - `customer@cafego.ph` → leave `role: "customer"`

**Step 4: Update Driver Account**
For the driver user, also add these fields in Firestore:
```
vehicleType: "motorcycle"
vehicleNumber: "ABC-1234"
isAvailable: false
currentDeliveryId: null
totalDeliveries: 0
averageRating: null
```

---

## Firestore Database Structure

### After Setup, Your `users` Collection Should Look Like:

```
users/
├── admin-uid-001/
│   ├── name: "Admin User"
│   ├── email: "admin@cafego.ph"
│   ├── phone: "+63912345601"
│   ├── role: "admin"
│   ├── isEmailVerified: true
│   ├── favorites: []
│   ├── stamps: 0
│   ├── addresses: []
│   ├── createdAt: <timestamp>
│   └── photoUrl: null
│
├── staff-uid-001/
│   ├── name: "Staff User"
│   ├── email: "staff@cafego.ph"
│   ├── phone: "+63912345602"
│   ├── role: "staff"
│   ├── isEmailVerified: true
│   ├── favorites: []
│   ├── stamps: 0
│   ├── addresses: []
│   ├── createdAt: <timestamp>
│   └── photoUrl: null
│
├── driver-uid-001/
│   ├── name: "Driver User"
│   ├── email: "driver@cafego.ph"
│   ├── phone: "+63912345603"
│   ├── role: "driver"
│   ├── isEmailVerified: true
│   ├── favorites: []
│   ├── stamps: 0
│   ├── addresses: []
│   ├── vehicleType: "motorcycle"
│   ├── vehicleNumber: "ABC-1234"
│   ├── isAvailable: false
│   ├── currentDeliveryId: null
│   ├── totalDeliveries: 0
│   ├── averageRating: null
│   ├── createdAt: <timestamp>
│   └── photoUrl: null
│
└── customer-uid-001/
    ├── name: "Customer User"
    ├── email: "customer@cafego.ph"
    ├── phone: "+63912345604"
    ├── role: "customer"
    ├── isEmailVerified: true
    ├── favorites: []
    ├── stamps: 0
    ├── addresses: []
    ├── createdAt: <timestamp>
    └── photoUrl: null
```

---

## Testing Role-Based Access

### After Creating Accounts, Test Each Role:

#### 1. Admin Account (`admin@cafego.ph`)
```
Login → Should redirect to /admin
Verify:
✓ Can see Admin Dashboard
✓ Can access Menu Management
✓ Can access Inventory
✓ Can access Analytics
✓ Cannot see Cart or Checkout
✓ Cannot access Customer menu (/cart, /orders)
```

#### 2. Staff Account (`staff@cafego.ph`)
```
Login → Should redirect to /staff (when implemented in Batch 3)
For now:
✓ Can login successfully
✓ Cannot access /admin
✓ Cannot access / (customer home)
✓ Verify role='staff' in Firestore
```

#### 3. Driver Account (`driver@cafego.ph`)
```
Login → Should redirect to /driver (when implemented in Batch 3)
For now:
✓ Can login successfully
✓ Cannot access /admin
✓ Cannot access / (customer home)
✓ Verify role='driver' + driver fields in Firestore
```

#### 4. Customer Account (`customer@cafego.ph`)
```
Login → Should redirect to / (menu home)
Verify:
✓ Can see Menu and browse items
✓ Can add items to cart
✓ Can access /cart, /orders, /profile
✓ Cannot access /admin
✓ Can proceed to checkout
```

---

## Current Implementation Status

### ✅ Completed (Batch 1)
- UserProfile model supports 4 roles
- Router enforces strict role-based access
- Admin redirect to /admin working
- Auth flow defaults to customer role

### ⏳ Pending (Batch 2-3)
- `/admin/*` screens (Menu, Inventory, Analytics, Users, Payroll)
- `/staff/*` screens (Order Queue, Payment Records)
- `/driver/*` screens (Delivery Dashboard, History)
- Admin can update user roles via UI

---

## Manual Role Update (If Needed)

If you need to change a user's role after creation:

**Via Firebase Console**:
1. Go to Firestore Database
2. Navigate to `users` collection
3. Click on the user document
4. Edit the `role` field
5. Update to: "admin", "staff", "driver", or "customer"

**Via Firebase CLI**:
```bash
firebase firestore:delete --recursive --project coughfee-app users/USER_UID
# Then re-import with correct role
```

---

## Troubleshooting

### "Email already in use" Error
- User already exists in Firebase Auth
- Either:
  - Use different email addresses
  - Delete existing user from Firebase Console first
  - Import with `--only` flag to skip duplicates

### User Created but No Firestore Document
- Firebase Auth user exists but Firestore document missing
- Solution:
  1. Go to Firebase Console > Firestore
  2. Manually create document: `users/{uid}`
  3. Add fields from structure above

### Role Not Changing After Update
- Firestore security rules may be blocking updates
- Verify Firestore rules allow role updates by admin
- Check rules in `firestore.rules`

### Can't Login to App
- Verify email/password match exactly (case-sensitive)
- Check that user's `isEmailVerified: true` in Firestore
- Clear browser cache/cookies and try again
- Check Firebase Console > Authentication for user status

---

## Next Steps

1. **Create Test Accounts** using one of the 3 options above
2. **Verify in Firestore** that all 4 users exist with correct roles
3. **Test Login Flow** with each account
4. **Verify Role Redirects** after login
5. **Begin Batch 2** implementation once all accounts working

---

## Additional Resources

- **Firebase Console**: https://console.firebase.google.com/
- **Firestore Rules Editor**: https://console.firebase.google.com/ > Firestore > Rules
- **Firebase CLI Docs**: https://firebase.google.com/docs/cli
- **CafeGO App**: https://mykhelcs.github.io/orderacoffee/
- **GitHub Repo**: https://github.com/mykhelcs/orderacoffee

---

## Quick Reference Card

| Role | Email | Password | Purpose |
|------|-------|----------|---------|
| Admin | admin@cafego.ph | Admin@123456 | System management (Batch 2) |
| Staff | staff@cafego.ph | Staff@123456 | Order management (Batch 3) |
| Driver | driver@cafego.ph | Driver@123456 | Delivery management (Batch 3) |
| Customer | customer@cafego.ph | Customer@123456 | Order placement |

---

**Status**: ✅ All accounts provisioned in Firebase Auth & Firestore
**Last Updated**: November 10, 2026

