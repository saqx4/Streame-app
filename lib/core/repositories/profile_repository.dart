import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streame/core/models/profile_model.dart';

class ProfileRepository {
  final SharedPreferences _prefs;
  static const String _profilesKey = 'profiles_v1';
  static const String _activeProfileKey = 'active_profile_v1';
  static const int maxProfiles = 5;

  ProfileRepository({
    required SharedPreferences prefs,
  })  : _prefs = prefs;

  Future<List<Profile>> loadProfiles() async {
    final raw = _prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Profile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProfiles(List<Profile> profiles) async {
    final json = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await _prefs.setString(_profilesKey, json);
  }

  Future<Profile?> getActiveProfile() async {
    final id = _prefs.getString(_activeProfileKey);
    if (id == null) return null;
    final profiles = await loadProfiles();
    try {
      return profiles.firstWhere((p) => p.id == id);
    } catch (_) {
      return profiles.isNotEmpty ? profiles.first : null;
    }
  }

  Future<void> setActiveProfile(String id) async {
    await _prefs.setString(_activeProfileKey, id);
    // Update lastUsedAt
    final profiles = await loadProfiles();
    final idx = profiles.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      profiles[idx] = profiles[idx].copyWith(
        lastUsedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await saveProfiles(profiles);
    }
  }

  Future<Profile> createProfile({
    required String name,
    int? avatarColor,
    int? avatarId,
    bool isKidsProfile = false,
    String? pin,
  }) async {
    final profile = Profile.create(
      name: name,
      avatarColor: avatarColor,
      avatarId: avatarId,
    ).copyWith(
      isKidsProfile: isKidsProfile,
      pin: pin,
    );
    final profiles = await loadProfiles();
    if (profiles.length >= maxProfiles) {
      throw Exception('Maximum $maxProfiles profiles allowed');
    }
    profiles.add(profile);
    await saveProfiles(profiles);
    return profile;
  }

  Future<void> updateProfile(Profile profile) async {
    final profiles = await loadProfiles();
    final idx = profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      profiles[idx] = profile;
      await saveProfiles(profiles);
    }
  }

  Future<void> deleteProfile(String id) async {
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == id);
    await saveProfiles(profiles);
    // If deleted profile was active, switch to first
    final activeId = _prefs.getString(_activeProfileKey);
    if (activeId == id && profiles.isNotEmpty) {
      await setActiveProfile(profiles.first.id);
    } else if (profiles.isEmpty) {
      await _prefs.remove(_activeProfileKey);
    }
  }

  Future<bool> verifyPin(String id, String pin) async {
    final profiles = await loadProfiles();
    try {
      final profile = profiles.firstWhere((p) => p.id == id);
      return profile.pin == pin;
    } catch (_) {
      return false;
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  throw UnimplementedError('Initialize in main');
});

final profilesProvider = FutureProvider<List<Profile>>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.loadProfiles();
});

final activeProfileProvider = FutureProvider<Profile?>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getActiveProfile();
});

final activeProfileIdProvider = Provider<String?>((ref) {
  final asyncProfile = ref.watch(activeProfileProvider);
  return asyncProfile.valueOrNull?.id;
});