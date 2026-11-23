import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getDisplayName } from '../src/users/displayName.ts';

test('이름과 성을 공백 하나로 연결한다', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: 'Choi' }), 'Mina Choi');
});

test('앞뒤 공백을 제거한다', () => {
  assert.equal(getDisplayName({ firstName: '  Mina ', lastName: ' Choi  ' }), 'Mina Choi');
});

test('성이 없으면 이름만 표시한다', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: null }), 'Mina');
});

test('이름이 없으면 성만 표시한다', () => {
  assert.equal(getDisplayName({ lastName: 'Choi' }), 'Choi');
});

test('둘 다 비어 있으면 Unknown User를 표시한다', () => {
  assert.equal(getDisplayName({ firstName: '   ', lastName: undefined }), 'Unknown User');
});
