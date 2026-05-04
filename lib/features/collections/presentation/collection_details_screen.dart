import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/core/theme/app_theme.dart';

class CollectionDetailsScreen extends ConsumerWidget {
  final String catalogId;

  const CollectionDetailsScreen({super.key, required this.catalogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: Text('Collection: $catalogId'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Center(
        child: Text(
          'Collection: $catalogId',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}