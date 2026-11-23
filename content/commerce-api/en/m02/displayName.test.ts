import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getDisplayName } from '../src/users/displayName.ts';

test('joins first and last name with one space', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: 'Choi' }), 'Mina Choi');
});

test('trims surrounding whitespace', () => {
  assert.equal(getDisplayName({ firstName: '  Mina ', lastName: ' Choi  ' }), 'Mina Choi');
});

test('shows only the first name when there is no last name', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: null }), 'Mina');
});

test('shows only the last name when there is no first name', () => {
  assert.equal(getDisplayName({ lastName: 'Choi' }), 'Choi');
});

test('shows Unknown User when both are empty', () => {
  assert.equal(getDisplayName({ firstName: '   ', lastName: undefined }), 'Unknown User');
});
