// Adapter Cloudflare Pages Functions -> feed kalender iCal (rute: /cal.ics)
import api from '../lib/api.js';
export async function onRequest({ request, env }) {
  const u = new URL(request.url);
  const r = await api.handle('calendar', { method: request.method, headers: k => request.headers.get(k), body: '', query: Object.fromEntries(u.searchParams) }, env);
  return new Response(r.body, { status: r.status, headers: r.headers });
}
