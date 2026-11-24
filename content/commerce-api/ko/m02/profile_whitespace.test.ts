import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getDisplayName } from '../src/users/displayName.ts';

test('탭과 줄바꿈만 있는 이름은 비어 있는 것으로 처리한다', () => {
  assert.equal(getDisplayName({ firstName: '\t\n', lastName: '  박  ' }), '박');
});

test('성이 생략되면 이름의 앞뒤 공백만 제거한다', () => {
  assert.equal(getDisplayName({ firstName: '\t지민\n' }), '지민');
});
