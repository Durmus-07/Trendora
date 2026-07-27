const assert = require('node:assert/strict');
const http = require('node:http');
const { after, before, test } = require('node:test');

process.env.NODE_ENV = 'test';
process.env.ALLOWED_ORIGINS = 'https://trendora.example';
process.env.REQUEST_LIMIT = '1000';

const { startServer } = require('../server');

let server;
let baseUrl;

function request(path, options = {}) {
  const target = new URL(path, baseUrl);

  return new Promise((resolve, reject) => {
    const req = http.request(target, options, response => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', chunk => { body += chunk; });
      response.on('end', () => {
        resolve({
          status: response.statusCode,
          headers: response.headers,
          body: body ? JSON.parse(body) : null
        });
      });
    });

    req.on('error', reject);
    req.end(options.body);
  });
}

before(async () => {
  server = startServer({ port: 0, host: '127.0.0.1' });
  await new Promise(resolve => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (server) await new Promise(resolve => server.close(resolve));
});

test('health landing endpoint returns the API catalog', async () => {
  const response = await request('/');

  assert.equal(response.status, 200);
  assert.equal(response.body.success, true);
  assert.equal(response.headers['x-content-type-options'], 'nosniff');
  assert.equal(response.headers['x-powered-by'], undefined);
});

test('unknown endpoints return JSON 404', async () => {
  const response = await request('/does-not-exist');

  assert.equal(response.status, 404);
  assert.equal(response.body.success, false);
});

test('unapproved browser origins are rejected', async () => {
  const response = await request('/', {
    headers: { origin: 'https://malicious.example' }
  });

  assert.equal(response.status, 403);
  assert.equal(response.body.success, false);
});

test('refresh operations require an admin key', async () => {
  const response = await request('/api/opportunities/bim/refresh');

  assert.equal(response.status, 503);
  assert.equal(response.body.success, false);
});

test('AI chat is disabled by default', async () => {
  const response = await request('/api/ai', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ message: 'Merhaba' })
  });

  assert.equal(response.status, 503);
  assert.equal(response.body.code, 'AI_DISABLED');
});

test('feature policy keeps analysis public and AI suspended for premium', async () => {
  const response = await request('/api/features');

  assert.equal(response.status, 200);
  assert.equal(response.body.features.statisticalAnalysis.enabled, true);
  assert.equal(response.body.features.statisticalAnalysis.audience, 'all-users');
  assert.equal(response.body.features.statisticalAnalysis.usesAi, false);
  assert.equal(response.body.features.ai.enabled, false);
  assert.equal(response.body.features.ai.audience, 'premium');
  assert.equal(response.body.features.ai.status, 'suspended');
});

test('data-backed trend analysis stays available while AI is disabled', async () => {
  const response = await request('/api/trends/analyze', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ query: '' })
  });

  assert.equal(response.status, 400);
  assert.equal(response.body.success, false);
  assert.equal(response.body.code, undefined);
});

test('chart endpoint rejects empty queries without market provider calls', async () => {
  const response = await request('/api/trends/chart?query=');

  assert.equal(response.status, 400);
  assert.equal(response.body.success, false);
});

test('source health endpoint is backward-compatible and observable', async () => {
  await request('/api/news?limit=1');
  const response = await request('/api/source-health');
  assert.equal(response.status, 200);
  assert.equal(response.body.success, true);
  assert.ok(Array.isArray(response.body.sources));
});

test('weather search endpoint validates without calling its provider', async () => {
  const response = await request('/api/weather/search?q=x');
  assert.equal(response.status, 400);
  assert.equal(response.body.success, false);
});
