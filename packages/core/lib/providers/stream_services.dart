class StreamProviders {
  static final Map<String, dynamic> providers = {
    'webstreamr': {
      'name': 'WebStreamr',
      'movie': (tmdbId) => 'https://webstreamr.hayd.uk/stream/movie/$tmdbId.json',
      'tv': (tmdbId, s, e) => 'https://webstreamr.hayd.uk/stream/series/$tmdbId:$s:$e.json',
    },
    'vidlink': {
      'name': 'VidLink',
      'movie': (tmdbId) => 'https://vidlink.pro/movie/$tmdbId',
      'tv': (tmdbId, s, e) => 'https://vidlink.pro/tv/$tmdbId/$s/$e',
    },
    'mappl': {
      'name': 'Mappl',
      'movie': (tmdbId) => 'https://mappl.tv/watch/movie/$tmdbId',
      'tv': (tmdbId, s, e) => 'https://mappl.tv/watch/tv/$tmdbId-$s-$e',
    },
    'vixsrc': {
      'name': 'VixSrc',
      'movie': (tmdbId) => 'https://vixsrc.to/movie/$tmdbId/',
      'tv': (tmdbId, s, e) => 'https://vixsrc.to/tv/$tmdbId/$s/$e/',
    },
    'vidnest': {
      'name': 'VidNest',
      'movie': (tmdbId) => 'https://vidnest.fun/movie/$tmdbId',
      'tv': (tmdbId, s, e) => 'https://vidnest.fun/tv/$tmdbId/$s/$e',
    },
    'anitaro4k': {
      'name': 'Anitaro 4K',
      'movie': (tmdbId) => 'https://api.anitaro.live/cdn/movie/$tmdbId',
      'tv': (tmdbId, s, e) => 'https://api.anitaro.live/cdn/tv/$tmdbId/$s/$e',
    },
    '111movies': {
      'name': '111Movies',
      'movie': (tmdbId) => 'https://111movies.com/movie/$tmdbId',
      'tv': (tmdbId, s, e) => 'https://111movies.com/tv/$tmdbId/$s/$e',
    },
  };
}
