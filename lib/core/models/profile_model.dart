// Profile models matching Kotlin Profile.kt parity
import 'dart:math';
import 'package:flutter/material.dart';

/// User profile - each profile has independent settings, Trakt, addons, etc.
class Profile {
  final String id;
  final String name;
  final int avatarColor;
  final int avatarId; // 0 = legacy letter+color, 1-24 = Compose-drawn avatar
  final bool isKidsProfile;
  final String? pin; // 4-5 digit PIN, null if not set
  final bool isLocked;
  final int createdAt;
  final int lastUsedAt;

  const Profile({
    required this.id,
    required this.name,
    this.avatarColor = 0xFFE50914,
    this.avatarId = 0,
    this.isKidsProfile = false,
    this.pin,
    this.isLocked = false,
    this.createdAt = 0,
    this.lastUsedAt = 0,
  });

  Profile copyWith({
    String? id,
    String? name,
    int? avatarColor,
    int? avatarId,
    bool? isKidsProfile,
    String? pin,
    bool? isLocked,
    int? createdAt,
    int? lastUsedAt,
  }) =>
      Profile(
        id: id ?? this.id,
        name: name ?? this.name,
        avatarColor: avatarColor ?? this.avatarColor,
        avatarId: avatarId ?? this.avatarId,
        isKidsProfile: isKidsProfile ?? this.isKidsProfile,
        pin: pin ?? this.pin,
        isLocked: isLocked ?? this.isLocked,
        createdAt: createdAt ?? this.createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );

  factory Profile.create({required String name, int? avatarColor, int? avatarId}) {
    final avatar = ProfileAvatars.random();
    return Profile(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    name: name,
    avatarColor: avatarColor ?? avatar.color,
    avatarId: avatarId ?? avatar.id,
    createdAt: DateTime.now().millisecondsSinceEpoch,
    lastUsedAt: DateTime.now().millisecondsSinceEpoch,
  );
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    avatarColor: json['avatar_color'] as int? ?? 0xFFE50914,
    avatarId: json['avatar_id'] as int? ?? 0,
    isKidsProfile: json['is_kids_profile'] as bool? ?? false,
    pin: json['pin'] as String?,
    isLocked: json['is_locked'] as bool? ?? false,
    createdAt: json['created_at'] as int? ?? 0,
    lastUsedAt: json['last_used_at'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar_color': avatarColor,
    'avatar_id': avatarId,
    'is_kids_profile': isKidsProfile,
    'pin': pin,
    'is_locked': isLocked,
    'created_at': createdAt,
    'last_used_at': lastUsedAt,
  };
}

/// Predefined profile avatar colors (Netflix-style)
class ProfileColors {
  ProfileColors._();

  static const List<int> colors = [
    0xFFE50914, // Netflix Red
    0xFF1DB954, // Green
    0xFF3B82F6, // Blue
    0xFFF59E0B, // Orange
    0xFF8B5CF6, // Purple
    0xFFEC4899, // Pink
    0xFF14B8A6, // Teal
    0xFF6366F1, // Indigo
  ];

  static int random() => colors[Random().nextInt(colors.length)];

  static int getByIndex(int index) => colors[index % colors.length];
}

/// Single avatar entry — an icon rendered on a colored background
class ProfileAvatar {
  final int id;
  final IconData icon;
  final int color;

  const ProfileAvatar({required this.id, required this.icon, required this.color});
}

/// 24 predefined avatars (matching Kotlin app's avatar count)
class ProfileAvatars {
  ProfileAvatars._();

  static const List<ProfileAvatar> avatars = [
    ProfileAvatar(id: 1, icon: Icons.person, color: 0xFFE50914),
    ProfileAvatar(id: 2, icon: Icons.face, color: 0xFF1DB954),
    ProfileAvatar(id: 3, icon: Icons.sentiment_very_satisfied, color: 0xFF3B82F6),
    ProfileAvatar(id: 4, icon: Icons.pets, color: 0xFFF59E0B),
    ProfileAvatar(id: 5, icon: Icons.sports_esports, color: 0xFF8B5CF6),
    ProfileAvatar(id: 6, icon: Icons.music_note, color: 0xFFEC4899),
    ProfileAvatar(id: 7, icon: Icons.auto_awesome, color: 0xFF14B8A6),
    ProfileAvatar(id: 8, icon: Icons.rocket_launch, color: 0xFF6366F1),
    ProfileAvatar(id: 9, icon: Icons.bolt, color: 0xFFEF4444),
    ProfileAvatar(id: 10, icon: Icons.star, color: 0xFFF97316),
    ProfileAvatar(id: 11, icon: Icons.local_fire_department, color: 0xFFD946EF),
    ProfileAvatar(id: 12, icon: Icons.wb_sunny, color: 0xFFFBBF24),
    ProfileAvatar(id: 13, icon: Icons.nightlight, color: 0xFF6D28D9),
    ProfileAvatar(id: 14, icon: Icons.favorite, color: 0xFFF43F5E),
    ProfileAvatar(id: 15, icon: Icons.casino, color: 0xFF0EA5E9),
    ProfileAvatar(id: 16, icon: Icons.science, color: 0xFF10B981),
    ProfileAvatar(id: 17, icon: Icons.palette, color: 0xFFA855F7),
    ProfileAvatar(id: 18, icon: Icons.flight, color: 0xFF06B6D4),
    ProfileAvatar(id: 19, icon: Icons.videogame_asset, color: 0xFFE11D48),
    ProfileAvatar(id: 20, icon: Icons.cookie, color: 0xFFD97706),
    ProfileAvatar(id: 21, icon: Icons.cake, color: 0xFF7C3AED),
    ProfileAvatar(id: 22, icon: Icons.emoji_emotions, color: 0xFF059669),
    ProfileAvatar(id: 23, icon: Icons.emoji_food_beverage, color: 0xFF2563EB),
    ProfileAvatar(id: 24, icon: Icons.celebration, color: 0xFFDB2777),
  ];

  static ProfileAvatar getById(int id) {
    return avatars.firstWhere((a) => a.id == id, orElse: () => avatars[0]);
  }

  static ProfileAvatar random() => avatars[Random().nextInt(avatars.length)];
}
