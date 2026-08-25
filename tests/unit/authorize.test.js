const test = require('node:test');
const assert = require('node:assert/strict');
const { ROLE_PERMISSIONS } = require('../../src/middleware/authorize');

test('cashier can create sales but cannot adjust inventory', () => {
  assert.equal(ROLE_PERMISSIONS.cashier.has('sale:create'), true);
  assert.equal(ROLE_PERMISSIONS.cashier.has('inventory:write'), false);
});

test('viewer is read-only', () => {
  assert.equal(ROLE_PERMISSIONS.viewer.has('product:read'), true);
  assert.equal(ROLE_PERMISSIONS.viewer.has('sale:create'), false);
  assert.equal(ROLE_PERMISSIONS.viewer.has('inventory:write'), false);
});

test('unknown roles have no permissions', () => {
  assert.equal(ROLE_PERMISSIONS.unknown, undefined);
});
