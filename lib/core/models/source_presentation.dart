import 'package:flutter/material.dart';
import 'package:streame/core/models/stream_models.dart';
import 'package:streame/core/theme/app_theme.dart';

/// Parsed source presentation matching Kotlin's SourcePresentation
class SourcePresentation {
  final StreamSource stream;
  final String title;
  final String addonLabel;
  final String resolutionLabel;
  final int resolutionScore;
  final String? releaseLabel;
  final int releaseScore;
  final String? codecLabel;
  final String? audioLabel;
  final String? transportLabel;
  final String? multiSourceLabel;
  final String? languageLabel;
  final List<({String label, Color color})> chips;
  final Color qualityColor;
  final int sizeBytes;
  final bool sortCached;
  final bool sortDirect;

  const SourcePresentation({
    required this.stream,
    required this.title,
    required this.addonLabel,
    required this.resolutionLabel,
    required this.resolutionScore,
    this.releaseLabel,
    required this.releaseScore,
    this.codecLabel,
    this.audioLabel,
    this.transportLabel,
    this.multiSourceLabel,
    this.languageLabel,
    required this.chips,
    required this.qualityColor,
    required this.sizeBytes,
    required this.sortCached,
    required this.sortDirect,
  });
}

// Regex patterns matching Kotlin app
final _av1Re = RegExp(r'\bAV1\b', caseSensitive: false);
final _hevcRe = RegExp(r'\b(HEVC|X265|H265)\b', caseSensitive: false);
final _h264Re = RegExp(r'\b(H264|X264|AVC)\b', caseSensitive: false);
final _remuxRe = RegExp(r'\bREMUX\b', caseSensitive: false);
final _blurayRe = RegExp(r'\b(BLURAY|BDRIP|BDREMUX)\b', caseSensitive: false);
final _webdlRe = RegExp(r'\b(WEB[- .]?DL|WEBDL)\b', caseSensitive: false);
final _webripRe = RegExp(r'\bWEB[- .]?RIP\b', caseSensitive: false);
final _hdtvRe = RegExp(r'\bHDTV\b', caseSensitive: false);
final _camRe = RegExp(r'\b(CAM|TS|TELESYNC|HDCAM)\b', caseSensitive: false);
final _atmosRe = RegExp(r'\bATMOS\b', caseSensitive: false);
final _truehdRe = RegExp(r'\bTRUEHD\b', caseSensitive: false);
final _dtsRe = RegExp(r'\b(DTS[- .]?HD|DTS|DDP|EAC3|AC3|AAC)\b', caseSensitive: false);
final _ch71Re = RegExp(r'\b7[ .]?1\b', caseSensitive: false);
final _ch51Re = RegExp(r'\b5[ .]?1\b', caseSensitive: false);
final _multiAudioRe = RegExp(r'\b(MULTI|DUAL[ .-]?AUDIO|MULTI[ .-]?AUDIO)\b', caseSensitive: false);
final _langHintRe = RegExp(r'\b(ENG|ENGLISH|HIN|HINDI|TAM|TAMIL|TEL|TELUGU|JPN|JAPANESE|KOR|KOREAN|SPA|SPANISH|FRE|FRENCH|GER|GERMAN|ITA|ITALIAN)\b', caseSensitive: false);
final _dvRe = RegExp(r'\b(DV|DoVi|Dolby[\s._-]*Vision)\b', caseSensitive: false);
final _hdrRe = RegExp(r'\bHDR(10\+?|10)?\b', caseSensitive: false);
final _imaxRe = RegExp(r'\bIMAX\b', caseSensitive: false);

/// Present a stream source with full metadata parsing — matches Kotlin's presentSource()
SourcePresentation presentSource(StreamSource stream, String addonName) {
  final title = (stream.behaviorHints?.filename?.isNotEmpty == true)
      ? stream.behaviorHints!.filename!
      : stream.source;
  final addonLabel = addonName.split(' - ').first.trim();

  final searchBlob = '${stream.quality} ${stream.source} ${stream.behaviorHints?.filename ?? ''}';

  // Resolution
  final resolutionLabel = _detectResolution(searchBlob, stream.quality);
  final resolutionScore = _resolutionScore(resolutionLabel);
  final qualityColor = _qualityColor(resolutionLabel);

  // Release type
  final releaseLabel = _detectRelease(searchBlob);
  final releaseScore = _releaseScore(releaseLabel);

  // Codec
  final codecLabel = _detectCodec(searchBlob);

  // Audio
  final audioLabel = _detectAudio(searchBlob);

  // Transport
  final addonLower = addonLabel.toLowerCase();
  final isTorrentProvider = addonLower.contains('torrentio') ||
      addonLower.contains('torrent') ||
      addonLower.contains('debrid') ||
      addonLower.contains('realdebrid') ||
      addonLower.contains('premiumize') ||
      addonLower.contains('alldebrid') ||
      searchBlob.toLowerCase().contains('magnet:');
  final hasDirectHttp = stream.url != null && stream.url!.isNotEmpty && stream.url!.startsWith('http');

  final transportLabel = stream.behaviorHints?.cached == true
      ? 'Cached'
      : (stream.infoHash != null && stream.infoHash!.isNotEmpty) || stream.sources.isNotEmpty || isTorrentProvider
          ? 'Torrent'
          : hasDirectHttp
              ? 'Direct'
              : null;

  // Multi-source
  final multiSourceLabel = stream.sources.length > 1
      ? '${stream.sources.length} sources'
      : stream.sources.length == 1
          ? '1 source'
          : null;

  // Language
  final subtitleLangs = stream.subtitles.map((s) => s.lang).where((l) => l.isNotEmpty).toList();
  String? languageLabel;
  if (_multiAudioRe.hasMatch(searchBlob)) {
    languageLabel = 'Multi-audio';
  } else if (subtitleLangs.length > 1) {
    languageLabel = '${subtitleLangs.length} langs';
  } else if (subtitleLangs.length == 1) {
    languageLabel = subtitleLangs.first.toUpperCase();
  } else {
    final m = _langHintRe.firstMatch(searchBlob);
    if (m != null) languageLabel = m.group(0)!.toUpperCase();
  }

  // Build chips with colors
  final chips = <({String label, Color color})>[];
  chips.add((label: addonLabel, color: AppTheme.textSecondary));
  if (transportLabel != null) {
    chips.add((label: transportLabel, color: transportLabel == 'Cached' ? Colors.green : AppTheme.textSecondary));
  }
  if (multiSourceLabel != null) chips.add((label: multiSourceLabel, color: AppTheme.textSecondary));
  if (languageLabel != null) chips.add((label: languageLabel, color: AppTheme.textSecondary));
  if (releaseLabel != null) {
    final c = (releaseLabel == 'REMUX' || releaseLabel == 'BluRay') ? AppTheme.accentYellow : AppTheme.textSecondary;
    chips.add((label: releaseLabel, color: c));
  }
  if (codecLabel != null) chips.add((label: codecLabel, color: AppTheme.textSecondary));
  if (_hdrRe.hasMatch(searchBlob)) chips.add((label: 'HDR', color: const Color(0xFFA855F7)));
  if (_dvRe.hasMatch(searchBlob)) chips.add((label: 'DV', color: const Color(0xFFEC4899)));
  if (_imaxRe.hasMatch(searchBlob)) chips.add((label: 'IMAX', color: const Color(0xFF06B6D4)));
  if (audioLabel != null) chips.add((label: audioLabel, color: AppTheme.textSecondary));

  final sizeBytes = stream.sizeBytes ?? _parseSizeBytes(stream.size);

  return SourcePresentation(
    stream: stream,
    title: title,
    addonLabel: addonLabel,
    resolutionLabel: resolutionLabel,
    resolutionScore: resolutionScore,
    releaseLabel: releaseLabel,
    releaseScore: releaseScore,
    codecLabel: codecLabel,
    audioLabel: audioLabel,
    transportLabel: transportLabel,
    multiSourceLabel: multiSourceLabel,
    languageLabel: languageLabel,
    chips: chips,
    qualityColor: qualityColor,
    sizeBytes: sizeBytes,
    sortCached: stream.behaviorHints?.cached == true,
    sortDirect: hasDirectHttp,
  );
}

String _detectResolution(String blob, String quality) {
  if (blob.contains('2160p') || blob.contains('4K')) return '4K';
  if (blob.contains('1080p')) return '1080p';
  if (blob.contains('720p')) return '720p';
  if (_camRe.hasMatch(blob)) return 'CAM';
  final first = quality.split(' ').firstOrNull;
  return (first != null && first.length <= 8) ? first : 'SD';
}

int _resolutionScore(String r) => switch (r) { '4K' => 4, '1080p' => 3, '720p' => 2, 'CAM' => 0, _ => 1 };

Color _qualityColor(String r) => switch (r) {
  '4K' => AppTheme.accentYellow,
  '1080p' => const Color(0xFF3B82F6),
  '720p' => const Color(0xFF06B6D4),
  'CAM' => const Color(0xFFEF4444),
  _ => AppTheme.textSecondary,
};

String? _detectRelease(String blob) {
  if (_remuxRe.hasMatch(blob)) return 'REMUX';
  if (_blurayRe.hasMatch(blob)) return 'BluRay';
  if (_webdlRe.hasMatch(blob)) return 'WEB-DL';
  if (_webripRe.hasMatch(blob)) return 'WEBRip';
  if (_hdtvRe.hasMatch(blob)) return 'HDTV';
  if (_camRe.hasMatch(blob)) return 'CAM';
  return null;
}

int _releaseScore(String? r) => switch (r) { 'REMUX' => 5, 'BluRay' => 4, 'WEB-DL' => 3, 'WEBRip' => 2, 'HDTV' => 1, _ => 0 };

String? _detectCodec(String blob) {
  if (_av1Re.hasMatch(blob)) return 'AV1';
  if (_hevcRe.hasMatch(blob)) return 'HEVC';
  if (_h264Re.hasMatch(blob)) return 'H.264';
  return null;
}

String? _detectAudio(String blob) {
  if (_atmosRe.hasMatch(blob)) return 'Atmos';
  if (_truehdRe.hasMatch(blob)) return 'TrueHD';
  if (_ch71Re.hasMatch(blob)) return '7.1';
  if (_ch51Re.hasMatch(blob)) return '5.1';
  final m = _dtsRe.firstMatch(blob);
  if (m != null) return m.group(0)!.toUpperCase();
  return null;
}

int parseSizeBytes(String sizeStr) {
  if (sizeStr.isEmpty) return 0;
  final normalized = sizeStr.toUpperCase().replaceAll(',', '.').replaceAll(RegExp(r'\s+'), ' ').trim();
  final p1 = RegExp(r'(\d+(?:\.\d+)?)\s*(TB|GB|MB|KB)');
  final m1 = p1.firstMatch(normalized);
  if (m1 != null) {
    final n = double.tryParse(m1.group(1)!) ?? 0;
    return _calcBytes(n, m1.group(2)!);
  }
  final p2 = RegExp(r'(\d+(?:\.\d+)?)\s*(TIB|GIB|MIB|KIB)');
  final m2 = p2.firstMatch(normalized);
  if (m2 != null) {
    final n = double.tryParse(m2.group(1)!) ?? 0;
    return _calcBytes(n, m2.group(2)!.replaceAll('IB', 'B'));
  }
  return 0;
}

int _parseSizeBytes(String sizeStr) => parseSizeBytes(sizeStr);

int _calcBytes(double n, String unit) => switch (unit) {
  'TB' => (n * 1024 * 1024 * 1024 * 1024).round(),
  'GB' => (n * 1024 * 1024 * 1024).round(),
  'MB' => (n * 1024 * 1024).round(),
  'KB' => (n * 1024).round(),
  _ => n.round(),
};

/// Format byte count to human-readable size string.
String? formatSizeBytes(int bytes) {
  if (bytes <= 0) return null;
  if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(0)} MB';
  return null;
}
