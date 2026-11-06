import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/firestore_instance.dart';
import '../models/announcement.dart';

final dismissedAnnouncementsProvider = StateProvider<Set<String>>((ref) => {});

final activeAnnouncementsStreamProvider = StreamProvider<List<AnnouncementModel>>((ref) {
  final firestore = appFirestore;
  return firestore
      .collection('announcements')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      return AnnouncementModel.fromFirestore(doc.data(), doc.id);
    }).toList();
  });
});

final currentVisibleAnnouncementProvider = Provider<AnnouncementModel?>((ref) {
  final asyncList = ref.watch(activeAnnouncementsStreamProvider);
  final dismissed = ref.watch(dismissedAnnouncementsProvider);

  return asyncList.when(
    data: (list) {
      for (final a in list) {
        if (!dismissed.contains(a.id)) {
          return a;
        }
      }
      return null;
    },
    loading: () => null,
    error: (err, stack) => null,
  );
});
