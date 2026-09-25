import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/database/firestore_instance.dart';
import '../models/schedule_profile.dart';
import 'profile_provider.dart';
import 'schedule_provider.dart';
import 'sound_settings_provider.dart';

class UserSetupState {
  final bool isSetupCompleted;
  final String role;
  final String countryCode;
  final String regionCode;
  final String city;
  final String organizationName;
  final String organizationShort;
  final String organizationColorHex;
  final String selectedToneId;
  final int reminderLeadMinutes;

  const UserSetupState({
    this.isSetupCompleted = false,
    this.role = 'school',
    this.countryCode = 'PH',
    this.regionCode = 'R11',
    this.city = 'Digos City',
    this.organizationName = 'University of Mindanao (UM Digos College)',
    this.organizationShort = 'UM Digos',
    this.organizationColorHex = '#DC2626',
    this.selectedToneId = 'crystal_chime',
    this.reminderLeadMinutes = 15,
  });

  UserSetupState copyWith({
    bool? isSetupCompleted,
    String? role,
    String? countryCode,
    String? regionCode,
    String? city,
    String? organizationName,
    String? organizationShort,
    String? organizationColorHex,
    String? selectedToneId,
    int? reminderLeadMinutes,
  }) {
    return UserSetupState(
      isSetupCompleted: isSetupCompleted ?? this.isSetupCompleted,
      role: role ?? this.role,
      countryCode: countryCode ?? this.countryCode,
      regionCode: regionCode ?? this.regionCode,
      city: city ?? this.city,
      organizationName: organizationName ?? this.organizationName,
      organizationShort: organizationShort ?? this.organizationShort,
      organizationColorHex: organizationColorHex ?? this.organizationColorHex,
      selectedToneId: selectedToneId ?? this.selectedToneId,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
    );
  }
}

class UserSetupNotifier extends StateNotifier<UserSetupState> {
  static const String settingsBox = 'app_settings_box';
  Box? _box;

  UserSetupNotifier() : super(const UserSetupState()) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(settingsBox);
    final completed = _box?.get('isSetupCompleted', defaultValue: false) as bool;
    final role      = _box?.get('userRole', defaultValue: 'school') as String;
    final country   = _box?.get('userCountry', defaultValue: 'PH') as String;
    final region    = _box?.get('userRegionCode', defaultValue: 'R11') as String;
    final city      = _box?.get('userCity', defaultValue: 'Digos City') as String;
    final orgName   = _box?.get('userOrgName', defaultValue: 'University of Mindanao (UM Digos College)') as String;
    final orgShort  = _box?.get('userOrgShort', defaultValue: 'UM Digos') as String;
    final orgColor  = _box?.get('userOrgColor', defaultValue: '#DC2626') as String;
    final toneId    = _box?.get('default_alarm_tone_id', defaultValue: 'crystal_chime') as String;
    final leadMins  = _box?.get('defaultReminderLead', defaultValue: 15) as int;

    state = UserSetupState(
      isSetupCompleted: completed,
      role: role,
      countryCode: country,
      regionCode: region,
      city: city,
      organizationName: orgName,
      organizationShort: orgShort,
      organizationColorHex: orgColor,
      selectedToneId: toneId,
      reminderLeadMinutes: leadMins,
    );
  }

  void updateRole(String role) {
    if (state.role != role) {
      state = state.copyWith(
        role: role,
        organizationName: '',
        organizationShort: '',
        organizationColorHex: role == 'work'
            ? '#F59E0B'
            : role == 'duty'
                ? '#10B981'
                : role == 'gov'
                    ? '#8B5CF6'
                    : '#2563EB',
      );
    }
  }

  void updateCountry(String countryCode) => state = state.copyWith(
    countryCode: countryCode, regionCode: '', city: '',
    organizationName: '', organizationShort: '',
  );

  void updateRegion(String regionCode) => state = state.copyWith(
    regionCode: regionCode, city: '',
    organizationName: '', organizationShort: '',
  );

  void updateCity(String city) => state = state.copyWith(
    city: city, organizationName: '', organizationShort: '',
  );

  void updateOrganization({
    required String name,
    required String shortName,
    required String colorHex,
  }) {
    state = state.copyWith(
      organizationName: name,
      organizationShort: shortName,
      organizationColorHex: colorHex,
    );
  }

  void updateTone(String toneId) => state = state.copyWith(selectedToneId: toneId);
  void updateReminderLead(int minutes) => state = state.copyWith(reminderLeadMinutes: minutes);

  Future<void> completeSetup(WidgetRef ref) async {
    try {
      _box = Hive.isBoxOpen(settingsBox)
          ? Hive.box(settingsBox)
          : await Hive.openBox(settingsBox);

      await _box?.put('isSetupCompleted', true);
      await _box?.put('userRole', state.role);
      await _box?.put('userCountry', state.countryCode);
      await _box?.put('userRegionCode', state.regionCode);
      await _box?.put('userCity', state.city);
      await _box?.put('userOrgName', state.organizationName);
      await _box?.put('userOrgShort', state.organizationShort);
      await _box?.put('userOrgColor', state.organizationColorHex);
      await _box?.put('default_alarm_tone_id', state.selectedToneId);
      await _box?.put('defaultReminderLead', state.reminderLeadMinutes);
    } catch (e) {
      debugPrint('UserSetupProvider: Failed to save setup to Hive cache: $e');
    }

    state = state.copyWith(isSetupCompleted: true);

    try {
      await ref.read(soundSettingsProvider.notifier).selectTone(state.selectedToneId);
    } catch (e) {
      debugPrint('UserSetupProvider: Failed to apply sound tone setting: $e');
    }

    try {
      final shortTrimmed = state.organizationShort.trim();
      final nameTrimmed = state.organizationName.trim();
      final profileName = shortTrimmed.isNotEmpty
          ? '$shortTrimmed Schedule'
          : nameTrimmed.isNotEmpty
              ? '$nameTrimmed Schedule'
              : 'My Schedule';

      final existingActive = ref.read(activeProfileProvider);
      final ScheduleProfile targetProfile;
      if (existingActive != null) {
        targetProfile = existingActive.copyWith(
          name: profileName,
          type: state.role,
          colorHex: state.organizationColorHex,
          isActive: true,
          updatedAt: DateTime.now(),
        );
      } else {
        targetProfile = ScheduleProfile(
          name: profileName,
          type: state.role,
          colorHex: state.organizationColorHex,
          isActive: true,
        );
      }

      await ref.read(profileListProvider.notifier).addProfile(targetProfile);
      await ref.read(profileListProvider.notifier).setActive(targetProfile.id);
      ref.read(scheduleListProvider.notifier).refreshFromLocal();
    } catch (e) {
      debugPrint('UserSetupProvider: Failed to create or activate initial profile: $e');
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        appFirestore.collection('users').doc(user.uid).set({
          'role': state.role,
          'countryCode': state.countryCode,
          'regionCode': state.regionCode,
          'city': state.city,
          'organizationName': state.organizationName,
          'organizationShort': state.organizationShort,
          'organizationColorHex': state.organizationColorHex,
          'defaultToneId': state.selectedToneId,
          'defaultReminderLead': state.reminderLeadMinutes,
          'isSetupCompleted': true,
          'setupCompletedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).then((_) {
          debugPrint('UserSetupProvider: User setup synced to Firestore.');
        }).catchError((e) {
          debugPrint('UserSetupProvider: Background sync to Firestore failed: $e');
        });
      }
    } catch (e) {
      debugPrint('UserSetupProvider: Failed to sync user setup to Firestore: $e');
    }
  }

  /// Automatically check Firestore for existing user setup and restore it
  Future<bool> checkAndRestoreCloudSetup(String uid) async {
    try {
      final doc = await appFirestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 4));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final role = data['role'] as String? ?? 'school';
        final country = data['countryCode'] as String? ?? 'PH';
        final region = data['regionCode'] as String? ?? 'R11';
        final city = data['city'] as String? ?? 'Digos City';
        final orgName = data['organizationName'] as String? ?? '';
        final orgShort = data['organizationShort'] as String? ?? '';
        final orgColor = data['organizationColorHex'] as String? ?? '#DC2626';
        final toneId = data['defaultToneId'] as String? ?? 'crystal_chime';
        final leadMins = data['defaultReminderLead'] as int? ?? 15;

        _box = Hive.isBoxOpen(settingsBox)
            ? Hive.box(settingsBox)
            : await Hive.openBox(settingsBox);

        await _box?.put('isSetupCompleted', true);
        await _box?.put('userRole', role);
        await _box?.put('userCountry', country);
        await _box?.put('userRegionCode', region);
        await _box?.put('userCity', city);
        await _box?.put('userOrgName', orgName);
        await _box?.put('userOrgShort', orgShort);
        await _box?.put('userOrgColor', orgColor);
        await _box?.put('default_alarm_tone_id', toneId);
        await _box?.put('defaultReminderLead', leadMins);

        state = state.copyWith(
          isSetupCompleted: true,
          role: role,
          countryCode: country,
          regionCode: region,
          city: city,
          organizationName: orgName,
          organizationShort: orgShort,
          organizationColorHex: orgColor,
          selectedToneId: toneId,
          reminderLeadMinutes: leadMins,
        );

        return true;
      }
    } catch (e) {
      // Ignored or offline
    }
    return false;
  }

  /// Reset local setup state on logout or account switch
  Future<void> reset() async {
    try {
      _box = Hive.isBoxOpen(settingsBox)
          ? Hive.box(settingsBox)
          : await Hive.openBox(settingsBox);
      await _box?.delete('isSetupCompleted');
      await _box?.delete('userRole');
      await _box?.delete('userCountry');
      await _box?.delete('userRegionCode');
      await _box?.delete('userCity');
      await _box?.delete('userOrgName');
      await _box?.delete('userOrgShort');
      await _box?.delete('userOrgColor');
    } catch (_) {}
    state = const UserSetupState();
  }
}

final userSetupProvider =
    StateNotifierProvider<UserSetupNotifier, UserSetupState>((ref) {
  return UserSetupNotifier();
});
