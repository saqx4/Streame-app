import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:app_links/app_links.dart';

import 'package:streame_core/api/api_keys.dart';
import 'package:streame_core/api/stremio_service.dart';
import 'package:streame_core/services/settings_service.dart';
import 'package:streame_core/services/torrent_stream_service.dart';
import 'package:streame_core/services/player_pool_service.dart';
import 'package:streame_core/services/watch_history_service.dart';
import 'package:streame_core/utils/webview_cleanup.dart';
import 'package:streame_core/utils/app_logger.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'package:streame_core/utils/env_loader.dart';
import 'package:streame_core/widgets/streame_logo.dart';
import 'package:streame_core/error/error_boundary.dart';
import 'package:streame_core/providers/service_providers.dart';

import 'package:streame/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();
  log.info('[Boot] Flutter binding initialized');

  await EnvLoader.loadEnv();

  if (!ApiKeys.hasTmdbKey) {
    log.warning('[Boot] TMDB_API_KEY not set — metadata lookups will fail. '
      'Add to .env file or pass --dart-define=TMDB_API_KEY=xxx at build time.');
  }
  if (!ApiKeys.hasRdClientId) {
    log.warning('[Boot] RD_CLIENT_ID not set — Real-Debrid login will fail. '
      'Add to .env file or pass --dart-define=RD_CLIENT_ID=xxx at build time.');
  }

  // Configure InAppWebView (Android only — not supported on iOS)
  if (Platform.isAndroid) {
    try {
      log.info('[Boot] Setting up InAppWebView...');
      await InAppWebViewController.setWebContentsDebuggingEnabled(true);
      log.info('[Boot] InAppWebView OK');
    } catch (e) {
      log.warning('[Boot] InAppWebView setup failed (non-fatal): $e');
    }
  }

  if (Platform.isAndroid) {
    SystemChrome.setPreferredOrientations([]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  log.info('[Boot] Initializing MediaKit...');
  MediaKit.ensureInitialized();
  log.info('[Boot] MediaKit OK');

  await SettingsService().initLightMode();
  await AppTheme.initTheme();

  PlayerPoolService().warmUp();
  log.info('[Boot] All init complete — launching app');

  runApp(
    ProviderScope(
      observers: [ProviderLogger()],
      child: const ErrorBoundary(
        child: StreameApp(),
      ),
    ),
  );
}

class StreameApp extends ConsumerWidget {
  const StreameApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _StreameAppWrapper();
  }
}

class _StreameAppWrapper extends StatefulWidget {
  const _StreameAppWrapper();

  @override
  State<_StreameAppWrapper> createState() => _StreameAppWrapperState();
}

class _StreameAppWrapperState extends State<_StreameAppWrapper> with WidgetsBindingObserver {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Deep link handling (Android/iOS)
    _appLinks = AppLinks();
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
    _deepLinkSub = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleDeepLink(Uri uri) {
    final url = uri.toString();
    log.info('[DeepLink] Received: $url');

    if (url.startsWith('stremio://')) {
      final parsed = StremioService.parseMetaLink(url);
      if (parsed != null) {
        switch (parsed['action']) {
          case 'search':
            final query = parsed['query']?.toString() ?? '';
            if (query.isNotEmpty) {
              MainScreen.stremioSearchNotifier.value = {
                'query': query,
                'addonBaseUrl': '',
              };
            }
          case 'detail':
            log.info('[DeepLink] Detail link: ${parsed['id']} (${parsed['type']})');
          case 'discover':
            log.info('[DeepLink] Discover link received');
        }
      }
    } else if (url.startsWith('magnet:')) {
      log.info('[DeepLink] Magnet link received');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      PlayerPoolService().dispose();
      TorrentStreamService().cleanup();
      WatchHistoryService().dispose();
      WebViewCleanup.cleanupWebView2Cache();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Streame',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  double _progress = 0.0;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _initEngine();
  }

  Future<void> _initEngine() async {
    log.info('[Boot] Starting engine initialization...');

    _updateProgress(0.1, 'Checking connectivity...');

    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);

    if (isOffline) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
      return;
    }

    _updateProgress(0.3, 'Starting services...');

    final torrentStream = ref.read(torrentStreamServiceProvider);
    final localServer = ref.read(localServerServiceProvider);

    await Future.wait([
      torrentStream.start().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log.warning('[Boot] TorrentStream startup timed out after 10s');
          return Future.value(false);
        },
      ).catchError((e, st) {
        log.warning('[Boot] TorrentStream error: $e');
        return Future.value(false);
      }),
      localServer.start().catchError((e) {
        log.warning('[Boot] LocalServer error: $e');
        return Future.value(null);
      }),
      WatchHistoryService().ensureInitialized().catchError((e) {
        log.warning('[Boot] WatchHistory init error: $e');
        return Future.value(null);
      }),
    ]);

    _updateProgress(1.0, 'Ready!');

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _updateProgress(double progress, String message) {
    if (mounted) {
      setState(() {
        _progress = progress;
        _statusMessage = message;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundDecoration,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const StreameLogo(size: 128),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [AppTheme.textPrimary, AppTheme.textSecondary, AppTheme.primaryColor],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: Text(
                      'STREAME',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'ENJOY!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                      color: AppTheme.primaryColor.withValues(alpha: 0.6),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 100),
              Column(
                children: [
                  SizedBox(
                    width: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      _statusMessage.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppTheme.textDisabled,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
