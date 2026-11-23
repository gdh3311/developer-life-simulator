import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getDisplayName } from '../src/users/displayName.ts';

test('닉네임이 있으면 닉네임을 표시한다', () => {
  assert.equal(getDisplayName({ firstName: 'Sophie', lastName: 'Lee', nickname: 'soso' }), 'soso');
});
