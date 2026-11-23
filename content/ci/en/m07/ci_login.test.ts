import { test } from 'node:test';
import assert from 'node:assert/strict';
import { login } from '../src/auth/login.ts';

test('[CI] no response gives AUTH_TIMEOUT', async () => {
  await assert.rejects(login(() => new Promise(() => {}), 'u1', 30), { message: 'AUTH_TIMEOUT' });
});
test('[CI] no token gives AUTH_FAILED (not a timeout)', async () => {
  await assert.rejects(login(async () => null, 'u1', 30), { message: 'AUTH_FAILED' });
});
test('[CI] identity provider errors pass through', async () => {
  await assert.rejects(login(async () => { throw new Error('IDP_DOWN'); }, 'u1', 30), { message: 'IDP_DOWN' });
});
test('[CI] successful login', async () => {
  const s = await login(async () => 'tok', 'u9', 30);
  assert.equal(s.userId, 'u9');
  assert.equal(s.token, 'tok');
});
