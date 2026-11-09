// Cloudflare Workers (static assets): menyajikan folder public/ dan menjalankan fungsi server.
// Rute: /api/create-user, /api/migrate-users, /cal.ics  -> logika bersama di lib/api.js
import api from '../lib/api.js';
const ROUTES = { '/api/create-user': 'create-user', '/api/migrate-users': 'migrate-users', '/cal.ics': 'calendar' };
export default {
  async fetch(request, env) {
    const u = new URL(request.url);
    const name = ROUTES[u.pathname];
    if (!name) return env.ASSETS.fetch(request);
    const r = await api.handle(name, {
      method: request.method,
      headers: k => request.headers.get(k),
      body: request.method === 'POST' ? await request.text() : '',
      query: Object.fromEntries(u.searchParams)
    }, env);
    return new Response(r.body, { status: r.status, headers: r.headers });
  }
};
