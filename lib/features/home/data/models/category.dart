import 'media_item.dart';

class Category {
  final String id;
  final String title;
  final List<MediaItem> items;

  const Category({
    required this.id,
    required this.title,
    required this.items,
  });
}