import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
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
              const SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                floating: true,
                title: Text(
                  'Settings',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    fontFamily: 'Poppins',
                  ),
                ),
                centerTitle: false,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Backup & Restore ──
                    const ExpandableSection(
                      icon: Icons.backup_rounded,
                      title: 'Backup & Restore',
                      children: [BackupRestoreSection()],
                    ),

                    // ── Appearance ──
                    const ExpandableSection(
                      icon: Icons.palette_rounded,
                      title: 'Appearance',
                      children: [AppearanceSection()],
                    ),

                    // ── Playback ──
                    const ExpandableSection(
                      icon: Icons.play_circle_outline_rounded,
                      title: 'Playback',
                      children: [PlaybackSection()],
                    ),

                    // ── Search & Torrents ──
                    const ExpandableSection(
                      icon: Icons.search_rounded,
                      title: 'Search & Torrents',
                      children: [SearchTorrentsSection()],
                    ),

                    // ── Providers & Addons ──
                    const ExpandableSection(
                      icon: Icons.extension_rounded,
                      title: 'Providers & Addons',
                      children: [ProvidersAddonsSection()],
                    ),

                    // ── Debrid ──
                    const ExpandableSection(
                      icon: Icons.cloud_download_rounded,
                      title: 'Debrid',
                      children: [DebridSection()],
                    ),

                    // ── Accounts & Sync ──
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

                    // ── Lists ──
                    const ExpandableSection(
                      icon: Icons.list_alt_rounded,
                      title: 'Lists',
                      children: [ListsSection()],
                    ),

                    // ── Navigation Bar ──
                    const ExpandableSection(
                      icon: Icons.tab_rounded,
                      title: 'Navigation Bar',
                      children: [NavbarSection()],
                    ),

                    // ── App Updates ──
                    const ExpandableSection(
                      icon: Icons.system_update_rounded,
                      title: 'App Updates',
                      children: [UpdateSection()],
                    ),

                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        'Streame Native v1.1.5',
                        style: TextStyle(
                          color: AppTheme.textDisabled,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
