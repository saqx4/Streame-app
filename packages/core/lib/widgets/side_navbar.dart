import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../utils/app_theme.dart';

import 'streame_logo.dart';



class SideNavbar extends StatefulWidget {

  final String activeItem;

  final bool isMobile;
  final void Function(String label)? onNavigate;

  const SideNavbar({super.key, required this.activeItem, this.isMobile = false, this.onNavigate});



  @override

  State<SideNavbar> createState() => _SideNavbarState();

}



class _SideNavbarState extends State<SideNavbar> {

  bool _isStreamingMode = false;



  final Map<String, bool> _navbarItems = {

    'Home': true,

    'Discover': true,

    'Library': true,

    'Search': true,

    'Play Magnet': true,

  };



  @override

  void initState() {

    super.initState();

    _loadSettings();

  }



  Future<void> _loadSettings() async {

    final enabled = await SettingsService().isStreamingModeEnabled();

    if (mounted) {

      setState(() {

        _isStreamingMode = enabled;

      });

    }

  }



  void _showSettingsMenu() {

    showDialog(

      context: context,

      builder: (context) {

        return StatefulBuilder(

          builder: (context, setDialogState) {

            return AlertDialog(

              backgroundColor: AppTheme.current.surfaceContainerHigh,

              title: Row(

                children: [

                  Icon(Icons.settings, color: AppTheme.current.primaryColor),

                  const SizedBox(width: 12),

                  Text('Settings', style: TextStyle(color: AppTheme.current.textPrimary)),

                ],

              ),

              content: Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  SwitchListTile(

                    title: Text('Streaming Mode', style: TextStyle(color: AppTheme.current.textPrimary)),

                    subtitle: Text('Extract direct links from web providers', style: TextStyle(color: AppTheme.current.textSecondary, fontSize: 12)),

                    value: _isStreamingMode,

                    activeThumbColor: AppTheme.current.primaryColor,

                    onChanged: (value) async {

                      await SettingsService().setStreamingMode(value);

                      setDialogState(() => _isStreamingMode = value);

                      setState(() => _isStreamingMode = value);

                    },

                  ),

                ],

              ),

              actions: [

                TextButton(

                  onPressed: () => Navigator.pop(context),

                  child: Text('Close', style: TextStyle(color: AppTheme.current.textSecondary)),

                ),

              ],

            );

          },

        );

      },

    );

  }



  void _showNavbarContextMenu(Offset position) {

    showMenu(

      context: context,

      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),

      color: AppTheme.current.surfaceContainerHigh,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      items: _navbarItems.keys.map((item) {

        return PopupMenuItem(

          child: Row(

            children: [

              Icon(

                _navbarItems[item]! ? Icons.check_box : Icons.check_box_outline_blank,

                color: AppTheme.current.primaryColor,

                size: 20,

              ),

              const SizedBox(width: 12),

              Text(item, style: TextStyle(color: AppTheme.current.textPrimary)),

            ],

          ),

          onTap: () {

            setState(() {

              _navbarItems[item] = !_navbarItems[item]!;

            });

          },

        );

      }).toList(),

    );

  }



  IconData _getIconForItem(String item) {

    switch (item) {

      case 'Home': return Icons.home;

      case 'Discover': return Icons.explore;

      case 'Library': return Icons.video_library;

      case 'Search': return Icons.search;

      case 'Play Magnet': return Icons.link;

      default: return Icons.circle;

    }

  }



  @override

  Widget build(BuildContext context) {

    final width = widget.isMobile ? 60.0 : 80.0;

    

    return GestureDetector(

      onSecondaryTapDown: (details) {

        _showNavbarContextMenu(details.globalPosition);

      },

      child: Container(

        width: width,

        decoration: BoxDecoration(

          color: AppTheme.current.surfaceDim,

          border: Border(right: BorderSide(color: AppTheme.current.border)),

        ),

        child: ClipRect(

          child: Container(

            decoration: BoxDecoration(

              color: Colors.black.withValues(alpha: 0.3), // Glass effect

            ),

            child: Column(

              children: [

                SizedBox(height: widget.isMobile ? 10 : 20),

                StreameLogo(size: widget.isMobile ? 28 : 36, showGlow: false, compact: true),

                Expanded(

                  child: ListView(

                    children: _navbarItems.entries

                        .where((entry) => entry.value)

                        .map((entry) => _buildNavItem(entry.key, _getIconForItem(entry.key)))

                        .toList(),

                  ),

                ),

                _buildNavItem('Settings', Icons.settings, onTap: _showSettingsMenu),

                SizedBox(height: widget.isMobile ? 10 : 20),

              ],

            ),

          ),

        ),

      ),

    );

  }



  Widget _buildNavItem(String label, IconData icon, {VoidCallback? onTap}) {
    final isActive = widget.activeItem == label;
    final iconSize = widget.isMobile ? 20.0 : 24.0;
    final fontSize = widget.isMobile ? 8.0 : 9.0;
    final height = widget.isMobile ? 56.0 : 64.0;
    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Tooltip(
          message: label,
          child: MouseRegion(
            onEnter: (_) => setState(() => isHovered = true),
            onExit: (_) => setState(() => isHovered = false),
            child: InkWell(
              onTap: onTap ?? () {
                if (isActive) return;
                if (widget.onNavigate != null) {
                  widget.onNavigate!(label);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                height: height,
                padding: EdgeInsets.symmetric(vertical: widget.isMobile ? 6 : 8, horizontal: widget.isMobile ? 2 : 4),
                decoration: isActive || isHovered
                    ? BoxDecoration(
                        color: isActive
                            ? AppTheme.current.primaryColor.withValues(alpha: 0.15)
                            : AppTheme.current.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: isActive ? AppTheme.current.primaryColor : AppTheme.current.textSecondary,
                      size: iconSize,
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isActive ? AppTheme.current.textPrimary : AppTheme.current.textSecondary,
                          fontSize: fontSize,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

}

