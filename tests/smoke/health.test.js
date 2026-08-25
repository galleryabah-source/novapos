const assert = require('node:assert/strict');

describe('NovaPOS health contract', () => {
  it('defines the expected health payload shape', () => {
    const payload = { status: 'ok', service: 'novapos-api', version: '2.0-foundation' };
    assert.equal(payload.status, 'ok');
    assert.equal(payload.service, 'novapos-api');
  });
});
