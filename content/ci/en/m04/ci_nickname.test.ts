import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getDisplayName } from '../src/users/displayName.ts';

test('[CI] the nickname feature still works', () => {
  assert.equal(getDisplayName({ firstName: 'Sophie', lastName: 'Lee', nickname: 'soso' }), 'soso');
});
test('[CI] nickname whitespace is trimmed', () => {
  assert.equal(getDisplayName({ nickname: '  soso ' }), 'soso');
});
test('[CI] a blank nickname falls back to the name rules', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: 'Choi', nickname: '   ' }), 'Mina Choi');
});
test('[CI] without a nickname the #001 rules apply', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: null, nickname: null }), 'Mina');
  assert.equal(getDisplayName({}), 'Unknown User');
});
