// Adapter Cloudflare Pages Functions -> logika bersama di lib/api.js (rute: /api/migrate-users)
import api from '../../lib/api.js';
export async function onRequest({ request, env }) {
  const u = new URL(request.url);
  const r = await api.handle('migrate-users', { method: request.method, headers: k => request.headers.get(k), body: request.method === 'POST' ? await request.text() : '', query: Object.fromEntries(u.searchParams) }, env);
  return new Response(r.body, { status: r.status, headers: r.headers });
}
