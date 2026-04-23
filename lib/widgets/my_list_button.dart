import 'package:flutter/material.dart';
import '../services/my_list_service.dart';
import '../models/movie.dart';
import '../utils/app_theme.dart';

/// Shared My List add/remove button used on movie & stremio cards.
class MyListButton extends StatelessWidget {
  final Movie? movie;
  final Map<String, dynamic>? stremioItem;

  const MyListButton.movie({required Movie this.movie}) : stremioItem = null;
  const MyListButton.stremio({required Map<String, dynamic> this.stremioItem}) : movie = null;

  String get _uniqueId {
    if (movie != null) return MyListService.movieId(movie!.id, movie!.mediaType);
    return MyListService.stremioItemId(stremioItem!);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: MyListService.changeNotifier,
      builder: (context, _, _) {
        final inList = MyListService().contains(_uniqueId);
        return GestureDetector(
          onTap: () async {
            if (movie != null) {
              final added = await MyListService().toggleMovie(
                tmdbId: movie!.id,
                imdbId: movie!.imdbId,
                title: movie!.title,
                posterPath: movie!.posterPath,
                mediaType: movie!.mediaType,
                voteAverage: movie!.voteAverage,
                releaseDate: movie!.releaseDate,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(added ? 'Added to My List' : 'Removed from My List'),
                  duration: const Duration(seconds: 1),
                ));
              }
            } else if (stremioItem != null) {
              final added = await MyListService().toggleStremioItem(stremioItem!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(added ? 'Added to My List' : 'Removed from My List'),
                  duration: const Duration(seconds: 1),
                ));
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(
              inList ? Icons.bookmark_rounded : Icons.add_rounded,
              size: 16,
              color: inList ? AppTheme.primaryColor : Colors.white70,
            ),
          ),
        );
      },
    );
  }
}
