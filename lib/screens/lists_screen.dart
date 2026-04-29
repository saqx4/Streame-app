import 'package:flutter/material.dart';
import 'package:streame_core/api/trakt_service.dart';
import 'package:streame_core/api/mdblist_service.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'lists/lists_widgets.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TraktService _trakt = TraktService();
  final MdblistService _mdblist = MdblistService();

  bool _isTraktLoggedIn = false;
  bool _isMdblistConfigured = false;

  List<Map<String, dynamic>> _traktLists = [];
  List<Map<String, dynamic>> _mdblistLists = [];
  List<Map<String, dynamic>> _mdblistTopLists = [];

  bool _loadingTrakt = true;
  bool _loadingMdblist = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final traktLoggedIn = await _trakt.isLoggedIn();
    final mdblistConfigured = await _mdblist.isConfigured();
    if (mounted) {
      setState(() {
        _isTraktLoggedIn = traktLoggedIn;
        _isMdblistConfigured = mdblistConfigured;
      });
    }
    if (traktLoggedIn) _loadTraktLists();
    if (mdblistConfigured) {
      _loadMdblistLists();
      _loadMdblistTopLists();
    }
  }

  Future<void> _loadTraktLists() async {
    try {
      final lists = await _trakt.getUserLists();
      if (mounted) setState(() { _traktLists = lists; _loadingTrakt = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTrakt = false);
    }
  }

  Future<void> _loadMdblistLists() async {
    try {
      final lists = await _mdblist.getUserLists();
      if (mounted) setState(() { _mdblistLists = lists; _loadingMdblist = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMdblist = false);
    }
  }

  Future<void> _loadMdblistTopLists() async {
    try {
      final lists = await _mdblist.getTopLists();
      if (mounted) setState(() => _mdblistTopLists = lists);
    } catch (_) {}
  }

  Future<void> _createTraktList() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String privacy = 'private';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text('Create Trakt List', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'List name',
                  hintStyle: TextStyle(color: AppTheme.textDisabled),
                  filled: true,
                  fillColor: GlassColors.surfaceSubtle,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: TextStyle(color: AppTheme.textPrimary),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Description (optional)',
                  hintStyle: TextStyle(color: AppTheme.textDisabled),
                  filled: true,
                  fillColor: GlassColors.surfaceSubtle,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: privacy,
                dropdownColor: const Color(0xFF1A1A2E),
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: GlassColors.surfaceSubtle,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                  DropdownMenuItem(value: 'friends', child: Text('Friends')),
                  DropdownMenuItem(value: 'public', child: Text('Public')),
                ],
                onChanged: (v) => setDialogState(() => privacy = v ?? 'private'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: AppTheme.textDisabled)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create', style: TextStyle(color: Color(0xFF00E5FF))),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final created = await _trakt.createList(
        name: nameController.text.trim(),
        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
        privacy: privacy,
      );
      if (created != null) {
        _loadTraktLists();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('List created!')),
          );
        }
      }
    }
    nameController.dispose();
    descController.dispose();
  }

  void _openTraktListItems(Map<String, dynamic> list) {
    final ids = list['ids'] as Map<String, dynamic>? ?? {};
    final slug = ids['slug']?.toString() ?? ids['trakt']?.toString() ?? '';
    final name = list['name']?.toString() ?? 'List';
    final itemCount = list['item_count'] as int? ?? 0;

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => TraktListItemsScreen(
        listId: slug,
        listName: name,
        itemCount: itemCount,
      ),
    ));
  }

  void _openMdblistItems(Map<String, dynamic> list, {bool isUserList = false}) {
    final id = list['id'] as int? ?? 0;
    final name = list['name']?.toString() ?? 'List';

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MdblistItemsScreen(listId: id, listName: name, isUserList: isUserList),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text('Lists', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textDisabled,
          tabs: const [
            Tab(text: 'Trakt'),
            Tab(text: 'MDBlist'),
            Tab(text: 'Top Lists'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTraktTab(),
          _buildMdblistTab(),
          _buildTopListsTab(),
        ],
      ),
    );
  }

  Widget _buildTraktTab() {
    if (!_isTraktLoggedIn) {
      return Center(
        child: Text('Login to Trakt in Settings', style: TextStyle(color: AppTheme.textDisabled, fontSize: 16)),
      );
    }
    if (_loadingTrakt) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _createTraktList,
              icon: const Icon(Icons.add),
              label: const Text('Create New List'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ),
        Expanded(
          child: _traktLists.isEmpty
            ? Center(child: Text('No lists yet', style: TextStyle(color: AppTheme.textDisabled)))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _traktLists.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final list = _traktLists[index];
                  final name = list['name']?.toString() ?? 'Unnamed';
                  final desc = list['description']?.toString() ?? '';
                  final itemCount = list['item_count'] as int? ?? 0;
                  final privacy = list['privacy']?.toString() ?? 'private';

                  return _listCard(
                    name: name,
                    subtitle: '$itemCount items • $privacy',
                    description: desc,
                    icon: Icons.list_rounded,
                    color: const Color(0xFFED1C24),
                    onTap: () => _openTraktListItems(list),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildMdblistTab() {
    if (!_isMdblistConfigured) {
      return Center(
        child: Text('Configure MDBlist in Settings', style: TextStyle(color: AppTheme.textDisabled, fontSize: 16)),
      );
    }
    if (_loadingMdblist) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    return _mdblistLists.isEmpty
      ? Center(child: Text('No lists yet', style: TextStyle(color: AppTheme.textDisabled)))
      : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _mdblistLists.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final list = _mdblistLists[index];
            final name = list['name']?.toString() ?? 'Unnamed';
            final itemCount = list['items'] as int? ?? 0;

            return _listCard(
              name: name,
              subtitle: '$itemCount items',
              icon: Icons.list_alt_rounded,
              color: const Color(0xFF5799EF),
              onTap: () => _openMdblistItems(list, isUserList: true),
            );
          },
        );
  }

  Widget _buildTopListsTab() {
    if (!_isMdblistConfigured) {
      return Center(
        child: Text('Configure MDBlist in Settings', style: TextStyle(color: AppTheme.textDisabled, fontSize: 16)),
      );
    }
    if (_mdblistTopLists.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _mdblistTopLists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final list = _mdblistTopLists[index];
        final name = list['name']?.toString() ?? 'Unnamed';
        final itemCount = list['items'] as int? ?? 0;
        final likes = list['likes'] as int? ?? 0;

        return _listCard(
          name: name,
          subtitle: '$itemCount items • $likes likes',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFFFFD700),
          onTap: () => _openMdblistItems(list),
        );
      },
    );
  }

  Widget _listCard({
    required String name,
    required String subtitle,
    String description = '',
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _HoverListCard(
      name: name,
      subtitle: subtitle,
      description: description,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}

class _HoverListCard extends StatefulWidget {
  final String name;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HoverListCard({
    required this.name,
    required this.subtitle,
    this.description = '',
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HoverListCard> createState() => _HoverListCardState();
}

class _HoverListCardState extends State<_HoverListCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.current.primaryColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AnimationPresets.smoothInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered ? GlassColors.surfaceSubtle.withValues(alpha: 0.9) : GlassColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered ? primary.withValues(alpha: 0.3) : GlassColors.borderSubtle,
              width: _isHovered ? 1.0 : 0.5,
            ),
            boxShadow: _isHovered ? [AppShadows.glow(0.06)] : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppDurations.fast,
                curve: AnimationPresets.smoothInOut,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _isHovered ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(widget.subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    if (widget.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(widget.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.textDisabled, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              AnimatedScale(
                duration: AppDurations.fast,
                scale: _isHovered ? 1.1 : 1.0,
                child: Icon(Icons.chevron_right_rounded, color: _isHovered ? primary : AppTheme.textDisabled),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TRAKT LIST ITEMS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
