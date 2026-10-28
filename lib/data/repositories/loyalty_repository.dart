import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/errors/failures.dart';

class LoyaltyRepository {
  LoyaltyRepository({FirebaseFirestore? firestore, Uuid? uuid})
      : _firestore = firestore,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore? _firestore;
  final Uuid _uuid;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      firestore.collection('users');

  /// L1: Earn stamp (increments stamps count by 1)
  Future<void> earnStamp(String uid) async {
    try {
      await _usersCol.doc(uid).update({
        'stamps': FieldValue.increment(1),
      });
    } catch (e) {
      throw ValidationFailure('Failed to earn stamp: $e');
    }
  }

  /// L2: Redeem stamps for free drink (atomic: requires >= 8 stamps, deducts 8, returns reward code)
  Future<String> redeemStamps(String uid) async {
    final userRef = _usersCol.doc(uid);

    return firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw const NotFoundFailure('User profile not found');
      }

      final currentStamps = (snapshot.data()?['stamps'] as num?)?.toInt() ?? 0;
      if (currentStamps < 8) {
        throw ValidationFailure(
          'Insufficient stamps for reward. Current: $currentStamps, required: 8',
        );
      }

      transaction.update(userRef, {
        'stamps': currentStamps - 8,
      });

      final rewardCode = 'REWARD-${_uuid.v4().substring(0, 8).toUpperCase()}';
      return rewardCode;
    });
  }

  /// L3: Watch user's stamp count (live stream)
  Stream<int> watchStamps(String uid) {
    return _usersCol.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return 0;
      return (doc.data()?['stamps'] as num?)?.toInt() ?? 0;
    });
  }
}
