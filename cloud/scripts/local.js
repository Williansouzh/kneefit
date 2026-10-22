// Roda o Worker no Node contra um S3 local, para testar sem a conta Cloudflare.
// Uso: npm run local   (precisa do S3 do docker compose do GymApp na porta 8333)
import { createServer } from 'node:http';
import { Readable } from 'node:stream';
import { AwsClient } from 'aws4fetch';

import worker from '../src/index.js';

const env = {
  TOKEN: process.env.TOKEN ?? 'token-local-de-desenvolvimento',
  BUCKET_NAME: process.env.BUCKET_NAME ?? 'fitknee-dev',
  R2_ACCESS_KEY_ID: 'devkey',
  R2_SECRET_ACCESS_KEY: 'devsecret',
  S3_ENDPOINT: process.env.S3_ENDPOINT ?? 'http://localhost:8333',
};
const port = Number(process.env.PORT ?? 8787);

const s3 = new AwsClient({ accessKeyId: 'devkey', secretAccessKey: 'devsecret', service: 's3', region: 'auto' });
await s3.fetch(`${env.S3_ENDPOINT}/${env.BUCKET_NAME}`, { method: 'PUT' });

createServer(async (req, res) => {
  const body = ['GET', 'HEAD'].includes(req.method) ? undefined : Readable.toWeb(req);
  const out = await worker.fetch(
    new Request(`http://${req.headers.host}${req.url}`, { method: req.method, headers: req.headers, body, duplex: 'half' }),
    env,
  );
  res.writeHead(out.status, Object.fromEntries(out.headers));
  res.end(Buffer.from(await out.arrayBuffer()));
}).listen(port, '0.0.0.0', () => console.log(`Worker local em http://0.0.0.0:${port} (token: ${env.TOKEN})`));
