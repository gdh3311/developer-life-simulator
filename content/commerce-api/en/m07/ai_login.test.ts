import { test } from 'node:test';
import assert from 'node:assert/strict';
import { login } from '../src/auth/login.ts';

// AICode: basic behaviour test
test('creates a session when a token is returned', async () => {
  const session = await login(async () => 'token-123', 'u1', 50);
  assert.equal(session.token, 'token-123');
});
