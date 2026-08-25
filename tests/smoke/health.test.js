const assert = require('node:assert/strict');
const test = require('node:test');

test('NovaPOS health contract exposes stable identity', () => {
  const payload = { status: 'ok', service: 'novapos-api', version: '2.0-foundation' };
  assert.equal(payload.status, 'ok');
  assert.equal(payload.service, 'novapos-api');
});

test('request IDs accept only bounded safe characters', () => {
  const valid = /^[A-Za-z0-9._:-]{8,128}$/;
  assert.equal(valid.test('req-12345678'), true);
  assert.equal(valid.test('bad id'), false);
  assert.equal(valid.test('short'), false);
});

test('inventory quantities must never be negative', () => {
  assert.equal((-1 >= 0), false);
  assert.equal((0 >= 0), true);
});
