const test = require('node:test');
const assert = require('node:assert/strict');

function calculateVariance(currentQuantity, movements) {
  const ledgerQuantity = movements.reduce((sum, movement) => sum + movement, 0);
  return Number((currentQuantity - ledgerQuantity).toFixed(3));
}

test('reconciliation reports zero variance when inventory matches ledger', () => {
  assert.equal(calculateVariance(7, [10, -2, -1]), 0);
});

test('reconciliation exposes variance instead of silently masking it', () => {
  assert.equal(calculateVariance(8, [10, -1]), -1);
});
