import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getDisplayName } from '../src/users/displayName.ts';

test('shows the nickname when there is one', () => {
  assert.equal(getDisplayName({ firstName: 'Sophie', lastName: 'Lee', nickname: 'soso' }), 'soso');
});
