// The App Review demo Xtream Codes server at /review: checks the demo login,
// maps player_api.php and xmltv.php to the files scripts/make-review-xtream.py
// writes, and redirects stream addresses to Apple's sample streams.
var USERNAME = 'review';
var PASSWORD = 'tunein';
var FILES = '/review/xtream/';
var SAMPLES = 'https://devstreaming-cdn.apple.com/videos/streaming/examples/';
var BASIC_4X3 = 'bipbop_4x3/bipbop_4x3_variant.m3u8';
var BASIC_16X9 = 'bipbop_16x9/bipbop_16x9_variant.m3u8';
var ADVANCED_FMP4 = 'img_bipbop_adv_example_fmp4/master.m3u8';
var ADVANCED_TS = 'img_bipbop_adv_example_ts/master.m3u8';
var ADVANCED_HEVC = 'bipbop_adv_example_hevc/master.m3u8';
var STREAMS = {
  live: { 1: BASIC_4X3, 2: BASIC_16X9, 3: ADVANCED_FMP4, 4: ADVANCED_HEVC },
  movie: { 101: ADVANCED_FMP4, 102: BASIC_16X9, 103: ADVANCED_TS, 104: ADVANCED_HEVC, 105: BASIC_4X3 },
  series: { 2011: ADVANCED_FMP4, 2012: ADVANCED_TS, 2013: BASIC_16X9 }
};
var LISTS = [
  'get_live_categories', 'get_live_streams', 'get_vod_categories', 'get_vod_streams',
  'get_series_categories', 'get_series'
];
var DETAILS = { get_vod_info: 'vod_id', get_series_info: 'series_id' };

function handler(event) {
  var request = event.request;
  var uri = request.uri;
  var query = request.querystring;

  if (uri.indexOf(FILES) === 0) {
    return status(404, 'Not Found');
  }
  if (uri === '/review/player_api.php') {
    return api(request, query);
  }
  if (uri === '/review/xmltv.php') {
    if (!signedIn(value(query, 'username'), value(query, 'password'))) {
      return status(403, 'Forbidden');
    }
    request.uri = '/review/guide.xml';
    request.querystring = {};
    return request;
  }
  var stream = uri.match(/^\/review\/(live|movie|series)\/([^/]+)\/([^/]+)\/(\d+)\.[A-Za-z0-9]+$/);
  if (stream) {
    if (!signedIn(decode(stream[2]), decode(stream[3]))) {
      return status(403, 'Forbidden');
    }
    var path = STREAMS[stream[1]][stream[4]];
    if (!path) {
      return status(404, 'Not Found');
    }
    return {
      statusCode: 302,
      statusDescription: 'Found',
      headers: { location: { value: SAMPLES + path } }
    };
  }
  return request;
}

function api(request, query) {
  request.querystring = {};
  if (!signedIn(value(query, 'username'), value(query, 'password'))) {
    request.uri = FILES + 'denied.json';
    return request;
  }
  var action = value(query, 'action');
  if (action === undefined || action === '') {
    request.uri = FILES + 'account.json';
    return request;
  }
  if (LISTS.indexOf(action) !== -1) {
    var category = value(query, 'category_id');
    if (category === undefined || category === '') {
      request.uri = FILES + action + '.json';
      return request;
    }
    if (!/^\d+$/.test(category)) {
      return status(404, 'Not Found');
    }
    request.uri = FILES + action + '/' + category + '.json';
    return request;
  }
  if (Object.prototype.hasOwnProperty.call(DETAILS, action)) {
    var id = value(query, DETAILS[action]);
    if (id === undefined || !/^\d+$/.test(id)) {
      return status(404, 'Not Found');
    }
    request.uri = FILES + action + '/' + id + '.json';
    return request;
  }
  return status(404, 'Not Found');
}

function signedIn(username, password) {
  return username === USERNAME && password === PASSWORD;
}

function value(query, key) {
  var entry = query[key];
  if (!entry) {
    return undefined;
  }
  return decode(entry.value.replace(/\+/g, ' '));
}

function decode(text) {
  try {
    return decodeURIComponent(text);
  } catch (e) {
    return text;
  }
}

function status(code, description) {
  return { statusCode: code, statusDescription: description };
}
