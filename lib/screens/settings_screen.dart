import 'package:flutter/material.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'settings/settings_widgets.dart';
import 'settings/backup_restore_section.dart';
import 'settings/appearance_section.dart';
import 'settings/playback_section.dart';
import 'settings/search_torrents_section.dart';
import 'settings/providers_addons_section.dart';
import 'settings/debrid_section.dart';
import 'settings/trakt_section.dart';
import 'settings/simkl_section.dart';
import 'settings/mdblist_section.dart';
import 'settings/navbar_section.dart';
import 'settings/lists_section.dart';
import 'settings/update_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundDecoration,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Premium Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.current.primaryColor,
                              AppTheme.current.accentColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [AppShadows.glow(0.2)],
                        ),
                        child: const Center(
                          child: Icon(Icons.settings_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settings',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 28,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Customize your experience',
                              style: TextStyle(
                                color: AppTheme.textDisabled,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── General Section ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _categoryHeader('General'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const ExpandableSection(
                      icon: Icons.backup_rounded,
                      title: 'Backup & Restore',
                      children: [BackupRestoreSection()],
                    ),
                    const ExpandableSection(
                      icon: Icons.palette_rounded,
                      title: 'Appearance',
                      children: [AppearanceSection()],
                    ),
                    const ExpandableSection(
                      icon: Icons.play_circle_outline_rounded,
                      title: 'Playback',
                      children: [PlaybackSection()],
                    ),
                    const ExpandableSection(
                      icon: Icons.tab_rounded,
                      title: 'Navigation Bar',
                      children: [NavbarSection()],
                    ),
                  ]),
                ),
              ),

              // ── Content Section ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _categoryHeader('Content & Search'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const ExpandableSection(
                      icon: Icons.search_rounded,
                      title: 'Search & Torrents',
                      children: [SearchTorrentsSection()],
                    ),
                    const ExpandableSection(
                      icon: Icons.extension_rounded,
                      title: 'Providers & Addons',
                      children: [ProvidersAddonsSection()],
                    ),
                    const ExpandableSection(
                      icon: Icons.cloud_download_rounded,
                      title: 'Debrid',
                      children: [DebridSection()],
                    ),
                  ]),
                ),
              ),

              // ── Accounts Section ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _categoryHeader('Accounts & Sync'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ExpandableSection(
                      icon: Icons.sync_rounded,
                      title: 'Accounts & Sync',
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'TRAKT',
                            style: TextStyle(
                              color: AppTheme.current.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const TraktSection(),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'SIMKL',
                            style: TextStyle(
                              color: AppTheme.current.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const SimklSection(),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'MDBLIST',
                            style: TextStyle(
                              color: AppTheme.current.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const MdblistSection(),
                      ],
                    ),
                    const ExpandableSection(
                      icon: Icons.list_alt_rounded,
                      title: 'Lists',
                      children: [ListsSection()],
                    ),
                  ]),
                ),
              ),

              // ── About Section ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _categoryHeader('About'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const ExpandableSection(
                      icon: Icons.system_update_rounded,
                      title: 'App Updates',
                      children: [UpdateSection()],
                    ),
                  ]),
                ),
              ),

              // ── Footer ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: GlassColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: GlassColors.borderSubtle, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.current.primaryColor.withValues(alpha: 0.6),
                                AppTheme.current.accentColor.withValues(alpha: 0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Streame Native v1.1.5',
                          style: TextStyle(
                            color: AppTheme.textDisabled,
                            fontSize: 12,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.current.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: AppTheme.current.primaryColor,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
