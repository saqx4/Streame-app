// Person detail modal — shows cast/crew member details
import 'package:flutter/material.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';
import 'package:streame/core/theme/app_theme.dart';

class PersonModal extends StatelessWidget {
  final String name;
  final String? character;
  final String? profilePath;
  final String? biography;
  final String? birthday;
  final String? placeOfBirth;
  final double? popularity;

  const PersonModal({
    super.key,
    required this.name,
    this.character,
    this.profilePath,
    this.biography,
    this.birthday,
    this.placeOfBirth,
    this.popularity,
  });

  static void show(BuildContext context, {
    required String name,
    String? character,
    String? profilePath,
    String? biography,
    String? birthday,
    String? placeOfBirth,
    double? popularity,
  }) {
    showDialog(
      context: context,
      builder: (_) => PersonModal(
        name: name,
        character: character,
        profilePath: profilePath,
        biography: biography,
        birthday: birthday,
        placeOfBirth: placeOfBirth,
        popularity: popularity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with image and name
                Row(
                  children: [
                    if (profilePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ResilientNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w185$profilePath',
                          width: 80,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 80, height: 120,
                            color: AppTheme.backgroundElevated,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 80, height: 120,
                            color: AppTheme.backgroundElevated,
                            child: const Icon(Icons.person, color: AppTheme.textTertiary),
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold,
                          )),
                          if (character != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('as $character', style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 14,
                              )),
                            ),
                          if (birthday != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(birthday!, style: const TextStyle(
                                color: AppTheme.textTertiary, fontSize: 12,
                              )),
                            ),
                          if (placeOfBirth != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(placeOfBirth!, style: const TextStyle(
                                color: AppTheme.textTertiary, fontSize: 12,
                              )),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (biography != null && biography!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.borderLight),
                  const SizedBox(height: 12),
                  Text(biography!, style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14, height: 1.5,
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
