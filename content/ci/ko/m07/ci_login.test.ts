import { test } from 'node:test';
import assert from 'node:assert/strict';
import { login } from '../src/auth/login.ts';

test('[CI] 응답이 없으면 AUTH_TIMEOUT', async () => {
  await assert.rejects(login(() => new Promise(() => {}), 'u1', 30), { message: 'AUTH_TIMEOUT' });
});
test('[CI] 토큰이 없으면 AUTH_FAILED (타임아웃과 구분)', async () => {
  await assert.rejects(login(async () => null, 'u1', 30), { message: 'AUTH_FAILED' });
});
test('[CI] 인증 서버 에러는 그대로 전달한다', async () => {
  await assert.rejects(login(async () => { throw new Error('IDP_DOWN'); }, 'u1', 30), { message: 'IDP_DOWN' });
});
test('[CI] 정상 로그인', async () => {
  const s = await login(async () => 'tok', 'u9', 30);
  assert.equal(s.userId, 'u9');
  assert.equal(s.token, 'tok');
});
