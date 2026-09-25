import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/institution_directory.dart';

/// Reactive Riverpod provider that triggers a rebuild whenever cloud institutions update.
final cloudInstitutionsRevisionProvider =
    ChangeNotifierProvider<ValueNotifier<int>>(
  (ref) => InstitutionItem.cloudRevision,
);

class InstitutionSyncService {
  static final InstitutionSyncService _instance = InstitutionSyncService._internal();
  factory InstitutionSyncService() => _instance;
  InstitutionSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  void startListening() {
    try {
      _subscription?.cancel();
      _subscription = _firestore.collection('institutions').snapshots().listen((snapshot) {
        final List<InstitutionItem> cloudList = [];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            final item = InstitutionItem.fromFirestore(data, doc.id);
            cloudList.add(item);
          } catch (e) {
            debugPrint('Error parsing institution doc ${doc.id}: $e');
          }
        }
        InstitutionItem.setCloudInstitutions(cloudList);
        debugPrint('InstitutionSyncService: Synced ${cloudList.length} dynamic institutions from cloud.');
      }, onError: (e) {
        debugPrint('InstitutionSyncService snapshot error: $e');
      });
    } catch (e) {
      debugPrint('Failed to start InstitutionSyncService: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
