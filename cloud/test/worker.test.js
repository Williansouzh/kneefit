// Roda o Worker no Node contra um S3 local (o SeaweedFS do docker compose do GymApp, porta 8333).
import assert from 'node:assert/strict';
import { before, test } from 'node:test';
import { AwsClient } from 'aws4fetch';

import worker from '../src/index.js';

const env = {
  TOKEN: 'token-de-teste-bem-comprido',
  BUCKET_NAME: 'fitknee-test',
  R2_ACCESS_KEY_ID: 'devkey',
  R2_SECRET_ACCESS_KEY: 'devsecret',
  S3_ENDPOINT: process.env.TEST_S3_ENDPOINT ?? 'http://localhost:8333',
};

const call = (method, path, { body, token = env.TOKEN } = {}) =>
  worker.fetch(
    new Request(`https://worker.test${path}`, {
      method,
      headers: { authorization: `Bearer ${token}`, ...(body ? { 'content-type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    }),
    env,
  );

before(async () => {
  const s3 = new AwsClient({ accessKeyId: 'devkey', secretAccessKey: 'devsecret', service: 's3', region: 'auto' });
  const res = await s3.fetch(`${env.S3_ENDPOINT}/${env.BUCKET_NAME}`, { method: 'PUT' });
  assert.ok(res.ok || res.status === 409, `criar bucket: ${res.status}`);
  for (const f of await (await call('GET', '/files')).json()) await call('DELETE', `/files/${f.name}`);
});

test('sem o token certo, nada', async () => {
  assert.equal((await call('GET', '/files', { token: 'errado' })).status, 401);
  assert.equal((await call('GET', '/files', { token: env.TOKEN.slice(0, -1) + 'X' })).status, 401);
  assert.equal((await worker.fetch(new Request('https://worker.test/files'), env)).status, 401);
  assert.equal((await call('GET', '/files', { token: 'curto' })).status, 401);
  assert.equal((await call('GET', '/files')).status, 200);
});

test('sobe, lista, baixa e apaga direto no bucket', async () => {
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 1, 2, 3, 4]);
  const put = await (await call('POST', '/sign', { body: { method: 'PUT', name: 'photo_a_front_1.jpg' } })).json();
  const up = await fetch(put.url, { method: 'PUT', body: bytes });
  assert.equal(up.status, 200, await up.text());

  const files = await (await call('GET', '/files')).json();
  assert.deepEqual(files, [{ name: 'photo_a_front_1.jpg', size: 7 }]);

  const get = await (await call('POST', '/sign', { body: { method: 'GET', name: 'photo_a_front_1.jpg' } })).json();
  const down = await fetch(get.url);
  assert.deepEqual(new Uint8Array(await down.arrayBuffer()), bytes);
  assert.equal((await fetch(get.url.split('?')[0])).status, 403); // sem assinatura, o bucket nega

  assert.equal((await call('DELETE', '/files/photo_a_front_1.jpg')).status, 204);
  assert.deepEqual(await (await call('GET', '/files')).json(), []);
});

test('nomes e métodos estranhos são recusados', async () => {
  for (const name of ['../x', 'a/b.jpg', '', '.env']) {
    assert.equal((await call('POST', '/sign', { body: { method: 'PUT', name } })).status, 400, name);
  }
  assert.equal((await call('POST', '/sign', { body: { method: 'DELETE', name: 'a.jpg' } })).status, 400);
  assert.equal((await call('DELETE', '/files/..%2Fx')).status, 400);
  assert.equal((await call('GET', '/outra')).status, 404);
});
