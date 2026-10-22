import { AwsClient } from 'aws4fetch';

/// Nomes de arquivo aceitos: os que o app gera (photo_..., video_..., fitknee.json). Sem barras.
const validName = /^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/;

/// Backup do FitKnee no Cloudflare R2. O Worker só confere o token e assina links: fotos, vídeos
/// e o JSON vão do celular direto para o bucket (privado) e voltam dele, sem passar por aqui.
///
///   POST   /sign          {"method": "PUT" | "GET", "name": "..."}  →  {"url": "..."} (vale 1 hora)
///   GET    /files                                                    →  [{"name", "size"}]
///   DELETE /files/:name
export default {
  async fetch(req, env) {
    try {
      return await handle(req, env);
    } catch (err) {
      console.error(err);
      return json({ error: 'Erro no servidor.' }, 500);
    }
  },
};

async function handle(req, env) {
  if (!authorized(req, env.TOKEN)) return json({ error: 'Token inválido.' }, 401);
  const url = new URL(req.url);
  const s3 = new AwsClient({
    accessKeyId: env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY,
    service: 's3',
    region: 'auto',
  });
  // S3_ENDPOINT só existe nos testes (S3 local); em produção é o endpoint do R2 da conta.
  const bucketUrl = `${env.S3_ENDPOINT ?? `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`}/${env.BUCKET_NAME}`;

  if (req.method === 'POST' && url.pathname === '/sign') {
    const { method, name } = await req.json().catch(() => ({}));
    if (!['PUT', 'GET'].includes(method) || !validName.test(name ?? '')) return json({ error: 'Pedido inválido.' }, 400);
    const target = new URL(`${bucketUrl}/${name}`);
    target.searchParams.set('X-Amz-Expires', '3600');
    const signed = await s3.sign(target, { method, aws: { signQuery: true } });
    return json({ url: signed.url });
  }

  if (req.method === 'GET' && url.pathname === '/files') {
    const files = [];
    let token = null;
    do {
      const list = new URL(bucketUrl);
      list.searchParams.set('list-type', '2');
      if (token) list.searchParams.set('continuation-token', token);
      const res = await s3.fetch(list);
      if (!res.ok) throw new Error(`list ${res.status}: ${await res.text()}`);
      const xml = await res.text();
      for (const [, item] of xml.matchAll(/<Contents>([\s\S]*?)<\/Contents>/g)) {
        files.push({ name: unescapeXml(tag(item, 'Key')), size: Number(tag(item, 'Size')) });
      }
      token = tag(xml, 'IsTruncated') === 'true' ? unescapeXml(tag(xml, 'NextContinuationToken')) : null;
    } while (token);
    return json(files);
  }

  if (req.method === 'DELETE' && url.pathname.startsWith('/files/')) {
    const name = decodeURIComponent(url.pathname.slice('/files/'.length));
    if (!validName.test(name)) return json({ error: 'Pedido inválido.' }, 400);
    const res = await s3.fetch(`${bucketUrl}/${name}`, { method: 'DELETE' });
    if (!res.ok && res.status !== 404) throw new Error(`delete ${res.status}`);
    return new Response(null, { status: 204 });
  }

  return json({ error: 'Não encontrado.' }, 404);
}

/// Compara o token sem vazar, pelo tempo de resposta, quantos caracteres bateram.
function authorized(req, token) {
  if (!token || token.length < 16) return false;
  const got = new TextEncoder().encode((req.headers.get('authorization') ?? '').replace(/^Bearer /, ''));
  const want = new TextEncoder().encode(token);
  if (got.length !== want.length) return false;
  let diff = 0;
  for (let i = 0; i < got.length; i++) diff |= got[i] ^ want[i];
  return diff === 0;
}

const tag = (xml, name) => xml.match(new RegExp(`<${name}>([\\s\\S]*?)</${name}>`))?.[1] ?? '';
const unescapeXml = (s) =>
  s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, '&');

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json; charset=utf-8' } });
