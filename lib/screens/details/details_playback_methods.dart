part of '../details_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  PLAYBACK METHODS
// ═══════════════════════════════════════════════════════════════════════════════

mixin DetailsPlaybackMethods on _DetailsScreenBase {

@override
void _playStremioStream(
  Map<String, dynamic> stream, {
  Duration? startPosition,
}) async {
  // Handle externalUrl streams (e.g. "More Like This" addon)
  final externalUrl = stream['externalUrl']?.toString();
  if (externalUrl != null && externalUrl.isNotEmpty) {
    final streamAddonBaseUrl =
        stream['_addonBaseUrl']?.toString() ?? _selectedSourceId;
    await _handleExternalUrl(externalUrl, addonBaseUrl: streamAddonBaseUrl);
    return;
  }

  final useDebrid = await _settings.useDebridForStreams();
  final debridService = await _settings.getDebridService();

  // Determine stremio item ID for resume (custom ID or IMDB ID)
  final stremioId = widget.stremioItem?['id']?.toString() ?? _movie.imdbId;
  final stremioAddonBaseUrl =
      stream['_addonBaseUrl']?.toString() ?? _selectedSourceId;

  if (stream['url'] != null) {
    if (!mounted) return;
    final playTitle = _movie.mediaType == 'tv'
        ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode'
        : _movie.title;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: stream['url'],
          title: playTitle,
          headers: Map<String, String>.from(
            stream['behaviorHints']?['proxyHeaders']?['request'] ?? {},
          ),
          movie: _movie,
          selectedSeason: _movie.mediaType == 'tv' ? _selectedSeason : null,
          selectedEpisode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
          startPosition: startPosition,
          activeProvider: 'stremio_direct',
          stremioId: stremioId,
          stremioAddonBaseUrl: stremioAddonBaseUrl,
        ),
      ),
    );
  } else if (stream['infoHash'] != null) {
    // Build a proper magnet link:
    // - include display name from stream title
    // - include tracker URLs from the 'sources' list
    //   (Stremio addons provide these as "tracker:udp://...", "tracker:http://...")
    final infoHash = stream['infoHash'] as String;
    final streamTitle = (stream['title'] ?? stream['name'] ?? '').toString();
    final dn = streamTitle.isNotEmpty
        ? '&dn=${Uri.encodeComponent(streamTitle)}'
        : '';

    // Extract trackers from sources
    final sources = stream['sources'];
    final trackerParams = StringBuffer();
    if (sources is List) {
      for (final src in sources) {
        if (src is String && src.startsWith('tracker:')) {
          final tracker = src.substring('tracker:'.length);
          trackerParams.write('&tr=${Uri.encodeComponent(tracker)}');
        }
      }
    }

    final magnet = 'magnet:?xt=urn:btih:$infoHash$dn$trackerParams';

    // fileIdx tells us exactly which file to play — no metadata poll needed

    if (!mounted) return;
    _streamCancelled = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (_) => LoadingOverlay(
        movie: _movie,
        message: useDebrid && debridService != 'None'
            ? 'Resolving with $debridService...'
            : 'Starting Torrent Engine...',
        onCancel: () {
          _streamCancelled = true;
          Navigator.of(context).pop();
        },
      ),
    );
    final navigator = Navigator.of(context);
    String? url;
    int? resolvedFileIndex;
    try {
      if (useDebrid && debridService != 'None') {
        final debrid = DebridApi();
        final files = debridService == 'Real-Debrid'
            ? await debrid.resolveRealDebrid(magnet)
            : await debrid.resolveTorBox(magnet);
        if (_streamCancelled) return;
        if (files.isNotEmpty) {
          if (_movie.mediaType == 'tv') {
            final s = 'S${_selectedSeason.toString().padLeft(2, '0')}';
            final e = 'E${_selectedEpisode.toString().padLeft(2, '0')}';
            final match = files
                .where(
                  (f) =>
                      f.filename.toUpperCase().contains(s) &&
                      f.filename.toUpperCase().contains(e),
                )
                .toList();
            if (match.isNotEmpty) {
              resolvedFileIndex = files.indexOf(match.first);
              url = match.first.downloadUrl;
            } else {
              files.sort((a, b) => b.filesize.compareTo(a.filesize));
              url = files.first.downloadUrl;
            }
          } else {
            files.sort((a, b) => b.filesize.compareTo(a.filesize));
            url = files.first.downloadUrl;
          }
        }
      } else {
        url = await TorrentStreamService().streamTorrent(
          magnet,
          season: _movie.mediaType == 'tv' ? _selectedSeason : null,
          episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
        );
        if (_streamCancelled) return;
        if (url != null) {
          final idx = Uri.parse(url).queryParameters['index'];
          if (idx != null) resolvedFileIndex = int.tryParse(idx);
        }
      }
    } catch (e) {
      debugPrint('Stremio hash error: $e');
    }
    if (_streamCancelled) return;
    if (navigator.canPop()) navigator.pop();
    if (url != null && mounted) {
      final playTitle = _movie.mediaType == 'tv'
          ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode'
          : _movie.title;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            streamUrl: url!,
            title: playTitle,
            magnetLink: magnet,
            movie: _movie,
            selectedSeason: _movie.mediaType == 'tv' ? _selectedSeason : null,
            selectedEpisode: _movie.mediaType == 'tv'
                ? _selectedEpisode
                : null,
            fileIndex: resolvedFileIndex,
            startPosition: startPosition,
            activeProvider: 'stremio_direct',
            stremioId: stremioId,
            stremioAddonBaseUrl: stremioAddonBaseUrl,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resolve stream.')),
      );
    }
  }
}

/// Handles a Stremio externalUrl: stremio:///detail, stremio:///search, or web URLs.
@override
Future<void> _handleExternalUrl(String url, {String? addonBaseUrl}) async {
  // Try parsing as a stremio:// link
  final parsed = StremioService.parseMetaLink(url);
  if (parsed != null) {
    switch (parsed['action']) {
      case 'detail':
        var id = parsed['id']?.toString() ?? '';
        final type = parsed['type']?.toString() ?? 'movie';
        // Extract IMDB ID from prefixed IDs like "mlt-rec-tt14905854"
        if (!id.startsWith('tt')) {
          final imdbMatch = RegExp(r'(tt\d+)').firstMatch(id);
          if (imdbMatch != null) {
            id = imdbMatch.group(1)!;
          }
        }
        await _openRecommendation({'id': id, 'type': type, 'name': ''});
        return;

      case 'search':
        final query = parsed['query']?.toString() ?? '';
        if (query.isNotEmpty && mounted) {
          // Pop back to MainScreen, then fire the search notifier
          Navigator.popUntil(context, (route) => route.isFirst);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            MainScreen.stremioSearchNotifier.value = null;
            MainScreen.stremioSearchNotifier.value = {
              'query': query,
              'addonBaseUrl': addonBaseUrl ?? '',
            };
          });
        }
        return;

      case 'discover':
        // Open the catalog screen for this discover link
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StremioCatalogScreen()),
          );
        }
        return;
    }
  }

  // Regular https:// URL → open in external browser
  if (url.startsWith('http://') || url.startsWith('https://')) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to handle this link')),
    );
  }
}

@override
void _playTorrent(TorrentResult result, {Duration? startPosition}) async {
  final useDebrid = await _settings.useDebridForStreams();
  final debridService = await _settings.getDebridService();
  if (!mounted) return;

  _streamCancelled = false;
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black,
    builder: (_) => LoadingOverlay(
      movie: _movie,
      message: useDebrid && debridService != 'None'
          ? 'Resolving with $debridService...'
          : 'Starting Torrent Engine...',
      onCancel: () {
        _streamCancelled = true;
        Navigator.of(context).pop();
      },
    ),
  );

  String? url;
  String? magnetLink = result.magnet;
  int? resolvedFileIndex;

  try {
    if (!magnetLink.startsWith('magnet:')) {
      if (!mounted || _streamCancelled) return;
      Navigator.pop(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black,
        builder: (_) => LoadingOverlay(
          movie: _movie,
          message: 'Resolving download link...',
          onCancel: () {
            _streamCancelled = true;
            Navigator.of(context).pop();
          },
        ),
      );
      try {
        final resolved = await _linkResolver.resolve(magnetLink);
        if (_streamCancelled) return;
        if (resolved.isMagnet) {
          magnetLink = resolved.link;
        } else if (resolved.torrentBytes != null) {
          if (!mounted) return;
          if (Navigator.canPop(context)) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Torrent file downloads not yet supported. Please use magnet links.',
              ),
            ),
          );
          return;
        }
      } catch (e) {
        if (_streamCancelled) return;
        if (!mounted) return;
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        return;
      }
      if (!mounted || _streamCancelled) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black,
        builder: (_) => LoadingOverlay(
          movie: _movie,
          message: useDebrid && debridService != 'None'
              ? 'Resolving with $debridService...'
              : 'Starting Torrent Engine...',
          onCancel: () {
            _streamCancelled = true;
            Navigator.of(context).pop();
          },
        ),
      );
    }

    if (useDebrid && debridService != 'None') {
      final debrid = DebridApi();
      final files = debridService == 'Real-Debrid'
          ? await debrid.resolveRealDebrid(magnetLink)
          : await debrid.resolveTorBox(magnetLink);
      if (_streamCancelled) return;
      if (files.isNotEmpty) {
        if (_movie.mediaType == 'tv') {
          final s = 'S${_selectedSeason.toString().padLeft(2, '0')}';
          final e = 'E${_selectedEpisode.toString().padLeft(2, '0')}';
          final match = files
              .where(
                (f) =>
                    f.filename.toUpperCase().contains(s) &&
                    f.filename.toUpperCase().contains(e),
              )
              .toList();
          if (match.isNotEmpty) {
            resolvedFileIndex = files.indexOf(match.first);
            url = match.first.downloadUrl;
          } else {
            files.sort((a, b) => b.filesize.compareTo(a.filesize));
            url = files.first.downloadUrl;
          }
        } else {
          files.sort((a, b) => b.filesize.compareTo(a.filesize));
          url = files.first.downloadUrl;
        }
      }
    } else {
      url = await TorrentStreamService().streamTorrent(
        magnetLink,
        season: _movie.mediaType == 'tv' ? _selectedSeason : null,
        episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
      );
      if (_streamCancelled) return;
      if (url != null) {
        final idx = Uri.parse(url).queryParameters['index'];
        if (idx != null) resolvedFileIndex = int.tryParse(idx);
      }
    }
  } catch (e) {
    debugPrint('Stream error: $e');
    if (mounted && !_streamCancelled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  if (!mounted || _streamCancelled) return;
  if (Navigator.canPop(context)) Navigator.pop(context);

  if (url != null) {
    final playTitle = _movie.mediaType == 'tv'
        ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode'
        : result.name;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: url!,
          title: playTitle,
          magnetLink: magnetLink,
          movie: _movie,
          selectedSeason: _movie.mediaType == 'tv' ? _selectedSeason : null,
          selectedEpisode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
          fileIndex: resolvedFileIndex,
          startPosition: startPosition,
          activeProvider: 'torrent',
        ),
      ),
    );
  }
}
}
