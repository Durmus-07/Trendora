const assert = require('node:assert/strict');
const { test } = require('node:test');

const { detectPeriod } = require('../services/trend/intentEngine');

test('understands standalone weekly, monthly and yearly periods', () => {
  assert.equal(detectPeriod('haftalık analiz').days, 7);
  assert.equal(detectPeriod('aylık beklenti').days, 30);
  assert.equal(detectPeriod('yıllık görünüm').days, 365);
});

test('preserves explicit numeric horizons', () => {
  assert.equal(detectPeriod('önümüzdeki 3 ay').days, 90);
  assert.equal(detectPeriod('2 yıllık tahmin').days, 730);
});
