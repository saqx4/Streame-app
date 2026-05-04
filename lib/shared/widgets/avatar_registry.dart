// Avatar Registry — programmatic avatar drawing (1-24 avatars)
// Matches Kotlin AvatarRegistry — no image assets needed
import 'package:flutter/material.dart';
import 'package:streame/core/models/profile_model.dart';

class AvatarRegistry {
  AvatarRegistry._();

  static const int avatarCount = 24;

  /// Build an avatar widget for the given avatarId and color
  static Widget build({
    required int avatarId,
    required int avatarColor,
    double size = 48,
  }) {
    final color = Color(ProfileColors.getByIndex(avatarColor));
    final id = avatarId.clamp(0, avatarCount - 1);
    final icon = _avatarIcons[id % _avatarIcons.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Center(
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }

  static const List<IconData> _avatarIcons = [
    Icons.person,
    Icons.face,
    Icons.star,
    Icons.favorite,
    Icons.movie,
    Icons.tv,
    Icons.music_note,
    Icons.sports_esports,
    Icons.pets,
    Icons.rocket_launch,
    Icons.bolt,
    Icons.wb_sunny,
    Icons.nightlight,
    Icons.cloud,
    Icons.local_fire_department,
    Icons.diamond,
    Icons.shield,
    Icons.palette,
    Icons.code,
    Icons.science,
    Icons.flight,
    Icons.sailing,
    Icons.terrain,
    Icons.water,
  ];
}
