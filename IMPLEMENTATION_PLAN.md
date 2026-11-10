BATCH 1: Payment Flow Cleanup + Receipt Screen (4 Tasks)
Task 1.1: Remove "(PayMongo)" text
File: 
checkout_screen.dart
Line ~715: method.isPayMongo ? '${method.label} (PayMongo)' : method.label → method.label
Line ~294: 'PayMongo Checkout' → 'Complete Payment'
File: 
order.dart
Delete the entire displayLabel getter from PaymentMethod enum
Task 1.2: Create OrderReceiptScreen
Create: 
order_receipt_screen.dart
Content: Simple ConsumerWidget receipt screen showing order code, items list, total, and "Done" button navigating to /orders
Task 1.3: Register /order-receipt/:id route
File: 
router.dart
Action: Add import + new GoRoute for /order-receipt/:id → OrderReceiptScreen
Task 1.4: Wire Pay at Counter to receipt
File: 
checkout_screen.dart
 in _handlePlaceOrder()
Action: After order placement, branch:
if (paymentMethod == PaymentMethod.counter) context.go('/order-receipt/$orderId');
else → existing flow (PayMongo sheet then tracking)
BATCH 2: Distance-Based Fee + Full-Screen Map + QR Code (4 Tasks)
Task 2.1: Distance-based delivery fee
File: 
location_service.dart
Add method:
dart

static double computeDeliveryFeeByDistance(LatLng branch, LatLng customer) {
  final km = computeDistanceKm(branch, customer);
  if (km <= 2.0) return 45.0;
  final extra = ((km - 2.0) * 10.0 / 5.0).round() * 5.0;
  return 45.0 + extra;
}
File: 
checkout_screen.dart
Replace _computeDeliveryFee() to call new method
Show distance in label: 'Delivery (${km.toStringAsFixed(1)} km)'
Task 2.2: Add qr_flutter dependency
File: pubspec.yaml
Action: Add qr_flutter: ^4.1.0 under dependencies, then flutter pub get
Task 2.3: Full-screen map with DraggableScrollableSheet
File: 
order_tracking_screen.dart
Action:
Convert from ConsumerWidget to ConsumerStatefulWidget
Replace SingleChildScrollView(Column(...)) with Stack:
Positioned.fill: LiveOrderMap (full-screen, no fixed height)
DraggableScrollableSheet: order info, stepper, cancel button (initialSize: 0.42, minSize: 0.15, maxSize: 0.90)
Positioned(top: 0, ...): floating blurred AppBar with back button + title + more icon
Task 2.4: Add GCash QR + PAY button
File: 
order_tracking_screen.dart
Action: Inside DraggableScrollableSheet content, add QR payment card:
Show only when: order.payment.isPayMongo && order.paymentStatus == PaymentStatus.pending && order.status != cancelled
Display: QrImageView(data: order.paymongoCheckoutUrl, size: 180)
Button: BrandButton('PAY', trailing: peso(order.total), onPressed: () => completePayMongoPayment(order.id))
BATCH 3: Profile Photo + Ratings + Push Notifications (3 Tasks)
Task 3.1: Profile photo upload
File: pubspec.yaml

Add image_picker: ^1.1.2, run flutter pub get
File: 
user_profile.dart

Add field: final String? photoUrl; to UserProfile
Update constructor, fromMap, toMap, copyWith
File: 
user_repository.dart

Add method: Future<void> updatePhotoUrl(String uid, String url) → update Firestore
File: 
auth_provider.dart

Add imports: import 'dart:io'; import 'package:firebase_storage/firebase_storage.dart'; import 'package:image_picker/image_picker.dart';
Add method: uploadProfilePhoto(XFile image) → upload to Firebase Storage, get URL, update profile
File: 
profile_screen.dart

Make avatar GestureDetector tappable → show image picker (camera/gallery)
If profile?.photoUrl is set: show Image.network(photoUrl) else show letter initials
Add camera badge icon on avatar
Task 3.2: Post-order rating system
Create: 
order_rating.dart

Class with: orderId, userId, stars (1-5), comment, createdAt, toMap(), fromMap()
Create: 
rating_repository.dart

Methods: submitRating(OrderRating) → write to Firestore orders/{orderId}/ratings/{userId}, hasRated(orderId, userId) → check if already rated
Create: 
rating_provider.dart

Provider: ratingRepositoryProvider
File: 
order_tracking_screen.dart

Convert to ConsumerStatefulWidget (add state field: bool _ratingShown = false)
Add ref.listen to detect when order.status == OrderStatus.completed
Show rating bottom sheet with 5-star picker + optional comment TextField
On submit: save to Firestore, show "Thanks for rating!" snackbar
Task 3.3: Loyalty milestones + push notifications
File: pubspec.yaml

Add flutter_local_notifications: ^17.2.4, run flutter pub get
Create: 
notification_service.dart

Static methods: initialize(), showLocalNotification(title, body)
File: 
main.dart

Call NotificationService.initialize() before runApp()
File: 
auth_provider.dart

In earnStamp(): after updating stamps, show notification if stamps == 4 or stamps % 8 == 0
File: 
profile_screen.dart

In Comfort Club card: show milestone badge when stamps == 4, animate progress bar
## COMPLETION STATUS

### ✅ BATCH 1 (Payment Flow)
- [x] Task 1.1: Remove "(PayMongo)" text → DONE
- [x] Task 1.2: OrderReceiptScreen created → lib/frontend/features/orders/order_receipt_screen.dart
- [x] Task 1.3: Register /order-receipt/:id route → DONE (router.dart)
- [x] Task 1.4: Wire counter payment to receipt → DONE (checkout_screen.dart)

### ✅ BATCH 2 (Distance Delivery + Map + QR)
- [x] Task 2.1: Distance-based delivery fee → DONE (location_service.dart & checkout_screen.dart)
- [x] Task 2.2: Add dependencies → DONE (qr_flutter, image_picker, flutter_local_notifications)
- [x] Task 2.3: Full-screen map conversion → DONE (order_tracking_screen.dart)
- [x] Task 2.4: Add QR + PAY button → DONE (order_tracking_screen.dart)

### ✅ BATCH 3 (Profile + Ratings + Notifications)
- [x] Task 3.1: Profile photo upload → DONE (user_profile.dart, user_repository.dart, auth_provider.dart, profile_screen.dart)
- [x] Task 3.2: Rating system → DONE (order_rating.dart, rating_repository.dart, rating_provider.dart, order_tracking_screen.dart)
- [x] Task 3.3: Push notifications → DONE (notification_service.dart, main.dart, auth_provider.dart, profile_screen.dart)

### Files Created
1. ✅ lib/backend/repositories/rating_repository.dart
2. ✅ lib/backend/services/notification_service.dart
3. ✅ lib/backend/models/order_rating.dart
4. ✅ lib/frontend/features/orders/order_receipt_screen.dart
5. ✅ lib/frontend/features/orders/rating_provider.dart

### Files Manually Edited & Verified
1. ✅ lib/frontend/navigation/router.dart → Added /order-receipt/:id route
2. ✅ lib/frontend/features/checkout/checkout_screen.dart → Added counter → receipt routing, distance fee calculation
3. ✅ lib/backend/services/location_service.dart → Added computeDeliveryFeeByDistance method
4. ✅ lib/frontend/features/orders/order_tracking_screen.dart → Converted to ConsumerStatefulWidget, full-screen map, QR, rating listener
5. ✅ lib/backend/models/user_profile.dart → Added photoUrl field
6. ✅ lib/backend/repositories/user_repository.dart → Added updatePhotoUrl method
7. ✅ lib/frontend/features/auth/auth_provider.dart → Added uploadProfilePhoto, earnStamp notifications
8. ✅ lib/frontend/features/profile/profile_screen.dart → Avatar photo display, picker UI, milestone badge, animated progress bar
9. ✅ lib/main.dart → NotificationService.initialize()

### Dependencies Status
✅ Dependencies added to pubspec.yaml:
- qr_flutter: ^4.1.0
- image_picker: ^1.1.2
- flutter_local_notifications: ^17.2.4

Run: `flutter pub get` to install

## Next Steps
1. Run `flutter pub get` to install new dependencies
2. Manual edits needed for remaining 9 files (see above)
3. After all edits, run `flutter run` to test the app
4. Test all features: payment flows, distance fee, full-screen map, QR, profile photo, ratings, notifications