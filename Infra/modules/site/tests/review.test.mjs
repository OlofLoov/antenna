// Runs review.js as CloudFront runs a viewer-request function, against the
// files scripts/make-review-xtream.py writes. Run with: node --test Infra/modules/site/tests
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { after, describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../../../..');
const code = readFileSync(join(here, '..', 'review.js'), 'utf8');
const context = vm.createContext({});
vm.runInContext(code, context);

const samples = 'https://devstreaming-cdn.apple.com/videos/streaming/examples/';
const login = { username: 'review', password: 'tunein' };
const site = mkdtempSync(join(tmpdir(), 'review-server-'));
execFileSync('python3', [
  join(root, 'scripts/make-review-xtream.py'),
  join(root, 'Web/review/antuna-review.m3u'),
  join(site, 'review/xtream'),
  'https://antuna.app/review'
]);
after(() => rmSync(site, { recursive: true, force: true }));

function run(uri, query = {}) {
  const querystring = {};
  for (const [key, value] of Object.entries(query)) {
    querystring[key] = { value };
  }
  const event = {
    version: '1.0',
    context: { eventType: 'viewer-request' },
    viewer: { ip: '192.0.2.1' },
    request: { method: 'GET', uri, querystring, headers: { host: { value: 'antuna.app' } }, cookies: {} }
  };
  return JSON.parse(JSON.stringify(context.handler(event)));
}

function file(uri, query) {
  const answer = run(uri, query);
  assert.equal(answer.statusCode, undefined, `${uri} ${JSON.stringify(query)} answered ${answer.statusCode}`);
  assert.deepEqual(answer.querystring, {});
  assert.ok(existsSync(join(site, answer.uri)), `${answer.uri} was not written`);
  return JSON.parse(readFileSync(join(site, answer.uri), 'utf8'));
}

function api(query) {
  return file('/review/player_api.php', { ...login, ...query });
}

function redirect(uri) {
  const answer = run(uri);
  assert.equal(answer.statusCode, 302, uri);
  return answer.headers.location.value;
}

describe('app-release/app-review-can-open-movies-and-series', () => {
  test('the account answers for the demo login', () => {
    const account = api({});
    assert.equal(account.user_info.auth, 1);
    assert.equal(account.user_info.status, 'Active');
  });

  test('every list action the app sends has a file, with and without a category', () => {
    const lists = {
      get_live_categories: 'get_live_streams',
      get_vod_categories: 'get_vod_streams',
      get_series_categories: 'get_series'
    };
    for (const [categories, streams] of Object.entries(lists)) {
      const rows = api({ action: categories });
      assert.ok(rows.length > 0, categories);
      assert.ok(api({ action: streams }).length > 0, streams);
      for (const row of rows) {
        assert.ok(api({ action: streams, category_id: row.category_id }).length > 0, `${streams} ${row.category_id}`);
      }
    }
  });

  test('every movie and series has its details', () => {
    for (const movie of api({ action: 'get_vod_streams' })) {
      assert.equal(api({ action: 'get_vod_info', vod_id: String(movie.stream_id) }).movie_data.stream_id, movie.stream_id);
    }
    for (const series of api({ action: 'get_series' })) {
      assert.ok(Object.keys(api({ action: 'get_series_info', series_id: String(series.series_id) }).episodes).length > 0);
    }
  });

  test('the guide is the playlist guide', () => {
    const answer = run('/review/xmltv.php', login);
    assert.equal(answer.uri, '/review/guide.xml');
    assert.deepEqual(answer.querystring, {});
  });

  test('every channel, movie and episode redirects to an Apple sample stream', () => {
    const streams = [];
    for (const channel of api({ action: 'get_live_streams' })) {
      streams.push(`/review/live/review/tunein/${channel.stream_id}.ts`);
    }
    for (const movie of api({ action: 'get_vod_streams' })) {
      streams.push(`/review/movie/review/tunein/${movie.stream_id}.${movie.container_extension}`);
    }
    for (const series of api({ action: 'get_series' })) {
      const info = api({ action: 'get_series_info', series_id: String(series.series_id) });
      for (const episode of Object.values(info.episodes).flat()) {
        streams.push(`/review/series/review/tunein/${episode.id}.${episode.container_extension}`);
      }
    }
    assert.equal(streams.length, 4 + 5 + 3);
    for (const stream of streams) {
      const location = redirect(stream);
      assert.ok(location.startsWith(samples) && location.endsWith('.m3u8'), `${stream} -> ${location}`);
    }
  });

  test('a percent-encoded login is the same login', () => {
    assert.ok(redirect('/review/live/%72eview/tune%69n/1.ts').startsWith(samples));
    assert.equal(api({ username: '%72eview' }).user_info.auth, 1);
  });

  test('the playlist, its guide and the art pass through', () => {
    for (const uri of ['/review/antuna-review.m3u', '/review/guide.xml', '/review/art/movie-101-poster.jpg']) {
      assert.equal(run(uri).uri, uri);
    }
  });

  test('every outside address in the function is an Apple sample stream', () => {
    const addresses = code.match(/https?:\/\/[^'"\s]+/g);
    assert.deepEqual(addresses, [samples]);
  });

  test('the function fits CloudFront\'s 10 KB limit', () => {
    assert.ok(Buffer.byteLength(code) < 10240);
  });
});

describe('app-release/the-review-server-answers-only-the-demo-login', () => {
  test('a wrong or missing login gets auth 0', () => {
    for (const query of [{ username: 'review', password: 'wrong' }, { username: 'other', password: 'tunein' }, {}]) {
      for (const action of [undefined, 'get_live_streams', 'get_vod_info']) {
        const answer = file('/review/player_api.php', action ? { ...query, action, vod_id: '101' } : query);
        assert.deepEqual(answer, { user_info: { auth: 0 } });
      }
    }
  });

  test('a stream or the guide with another login is refused', () => {
    assert.equal(run('/review/live/review/wrong/1.ts').statusCode, 403);
    assert.equal(run('/review/movie/someone/tunein/101.m3u8').statusCode, 403);
    assert.equal(run('/review/xmltv.php', { username: 'review', password: 'wrong' }).statusCode, 403);
  });

  test('unknown streams, actions and ids are not found', () => {
    assert.equal(run('/review/live/review/tunein/99.ts').statusCode, 404);
    assert.equal(run('/review/series/review/tunein/101.m3u8').statusCode, 404);
    assert.equal(run('/review/player_api.php', { ...login, action: 'get_short_epg' }).statusCode, 404);
    assert.equal(run('/review/player_api.php', { ...login, action: 'get_vod_info', vod_id: '../account' }).statusCode, 404);
    assert.equal(run('/review/player_api.php', { ...login, action: 'get_vod_streams', category_id: 'x' }).statusCode, 404);
  });

  test('the answer files cannot be read by their own addresses', () => {
    for (const uri of ['/review/xtream/account.json', '/review/xtream/get_vod_info/101.json']) {
      assert.equal(run(uri).statusCode, 404);
    }
  });
});
