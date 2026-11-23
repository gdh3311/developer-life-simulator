import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getDisplayName } from '../src/users/displayName.ts';

test('[CI] 탭과 줄바꿈도 공백으로 보고 제거한다', () => {
  assert.equal(getDisplayName({ firstName: '\tMina\n', lastName: ' Choi' }), 'Mina Choi');
});
test('[CI] 빈 문자열 이름은 없는 것으로 본다', () => {
  assert.equal(getDisplayName({ firstName: '', lastName: 'Choi' }), 'Choi');
});
test('[CI] 둘 다 null 이면 Unknown User', () => {
  assert.equal(getDisplayName({ firstName: null, lastName: null }), 'Unknown User');
});
