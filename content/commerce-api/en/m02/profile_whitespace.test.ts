import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getDisplayName } from '../src/users/displayName.ts';

test('tabs and newlines alone count as an empty name', () => {
  assert.equal(getDisplayName({ firstName: '\t\n', lastName: '  Park  ' }), 'Park');
});

test('trims the given name when the surname is omitted', () => {
  assert.equal(getDisplayName({ firstName: '\tJimin\n' }), 'Jimin');
});
