import { test } from 'node:test';
import assert from 'node:assert/strict';
import { login } from '../src/auth/login.ts';

// AICode: 기본 동작 테스트
test('토큰을 받으면 세션을 만든다', async () => {
  const session = await login(async () => 'token-123', 'u1', 50);
  assert.equal(session.token, 'token-123');
});
