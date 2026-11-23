import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getDisplayName } from '../src/users/displayName.ts';

test('[CI] 닉네임 기능이 유지된다', () => {
  assert.equal(getDisplayName({ firstName: 'Sophie', lastName: 'Lee', nickname: 'soso' }), 'soso');
});
test('[CI] 닉네임 앞뒤 공백은 제거한다', () => {
  assert.equal(getDisplayName({ nickname: '  soso ' }), 'soso');
});
test('[CI] 공백뿐인 닉네임은 무시하고 이름 규칙을 따른다', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: 'Choi', nickname: '   ' }), 'Mina Choi');
});
test('[CI] 닉네임이 없으면 기존 이름 규칙 (#001)', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: null, nickname: null }), 'Mina');
  assert.equal(getDisplayName({}), 'Unknown User');
});
