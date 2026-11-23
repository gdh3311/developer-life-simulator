import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getDisplayName } from '../src/users/displayName.ts';

test('[CI] treats tabs and newlines as whitespace', () => {
  assert.equal(getDisplayName({ firstName: '\tMina\n', lastName: ' Choi' }), 'Mina Choi');
});
test('[CI] an empty string counts as missing', () => {
  assert.equal(getDisplayName({ firstName: '', lastName: 'Choi' }), 'Choi');
});
test('[CI] both null gives Unknown User', () => {
  assert.equal(getDisplayName({ firstName: null, lastName: null }), 'Unknown User');
});
