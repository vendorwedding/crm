'use strict';
// Logika fungsi server yang dipakai BERSAMA oleh Netlify Functions dan Cloudflare Pages Functions.
// Tanpa library apa pun (hanya fetch), jadi ringan dan tidak perlu "npm install".
const base = env => String(env.SUPABASE_URL || '').replace(/\/$/, '');
const keyH = env => { const k = env.SUPABASE_SERVICE_ROLE_KEY || ''; return k.startsWith('eyJ') ? { apikey: k, Authorization: 'Bearer ' + k } : { apikey: k }; };
const out = (s, b, h = {}, type = 'application/json') => ({ status: s, headers: { 'Content-Type': type, ...h }, body: typeof b === 'string' ? b : JSON.stringify(b) });
const txt = (s, b) => out(s, b, {}, 'text/plain; charset=utf-8');
const sbq = async (env, path, init = {}) => {
  const r = await fetch(base(env) + path, { ...init, headers: { ...keyH(env), 'Content-Type': 'application/json', ...(init.headers || {}) } });
  const t = await r.text(); let d = null; try { d = t ? JSON.parse(t) : null; } catch (e) { d = t; }
  return { ok: r.ok, status: r.status, data: d };
};
function cors(env, origin) {
  const ok = String(env.ALLOWED_ORIGINS || '').split(',').map(x => x.trim()).filter(Boolean);
  return origin && ok.includes(origin) ? { 'Access-Control-Allow-Origin': origin, Vary: 'Origin', 'Access-Control-Allow-Headers': 'Authorization, Content-Type, apikey', 'Access-Control-Allow-Methods': 'POST, GET, OPTIONS', 'Access-Control-Max-Age': '86400' } : {};
}
async function caller(env, req) {
  const tok = String(req.headers('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!tok) return { err: 'unauthorized: token login tidak terkirim (coba keluar lalu masuk lagi)' };
  // Verifikasi token pengguna memakai kunci PUBLIK (publishable/anon), seperti browser.
  // Kunci rahasia (sb_secret_) tidak boleh dipakai di sini: gateway Supabase dapat menggantikan token pengguna.
  const pub = env.SUPABASE_ANON_KEY || req.headers('apikey') || env.SUPABASE_SERVICE_ROLE_KEY;
  const r = await fetch(base(env) + '/auth/v1/user', { headers: { apikey: pub, Authorization: 'Bearer ' + tok } });
  if (!r.ok) return { err: 'unauthorized: sesi login tidak valid atau kedaluwarsa (Supabase menjawab ' + r.status + '). Keluar lalu masuk lagi.' };
  const u = await r.json();
  const p = await sbq(env, `/rest/v1/profiles?id=eq.${encodeURIComponent(u.id)}&select=role,vendor_id,active&limit=1`);
  const me = p.ok && Array.isArray(p.data) ? p.data[0] : null;
  if (!me) return { err: 'unauthorized: profil akun ini belum terdaftar di tabel profiles' + (p.ok ? '' : ' (pembacaan profil gagal: ' + p.status + ', periksa SUPABASE_SERVICE_ROLE_KEY)') };
  return { ...me, id: u.id };
}
async function createUser(req, env) {
  if (req.method !== 'POST') return txt(405, 'method not allowed');
  const me = await caller(env, req);
  if (me.err) return txt(401, me.err);
  if (!me.active || !['admin', 'owner'].includes(me.role)) return txt(403, 'forbidden');
  let b; try { b = JSON.parse(req.body || '{}'); } catch (e) { return txt(400, 'data tidak valid'); }
  const vendor_id = me.role === 'admin' ? b.vendor_id : me.vendor_id;
  if (!vendor_id || !['owner', 'staff', 'guest'].includes(b.role) || !b.email || !b.password) return txt(400, 'data tidak valid');
  const c = await sbq(env, '/auth/v1/admin/users', { method: 'POST', body: JSON.stringify({ email: b.email, password: b.password, email_confirm: true }) });
  if (!c.ok) return txt(400, (c.data && (c.data.msg || c.data.message || c.data.error_description)) || 'gagal membuat akun');
  const uid = c.data.id || (c.data.user && c.data.user.id);
  const p = await sbq(env, '/rest/v1/profiles', { method: 'POST', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ id: uid, vendor_id, role: b.role, full_name: b.name }) });
  if (!p.ok) { await sbq(env, '/auth/v1/admin/users/' + uid, { method: 'DELETE' }); return txt(400, (p.data && (p.data.message || p.data.msg)) || 'gagal menyimpan profil'); }
  return out(200, { ok: true });
}
async function migrateUsers(req, env) {
  if (req.method !== 'POST') return txt(405, 'method not allowed');
  const me = await caller(env, req);
  if (me.err) return txt(401, me.err);
  if (!me.active || me.role !== 'admin') return txt(403, 'hanya admin');
  let b; try { b = JSON.parse(req.body || '{}'); } catch (e) { return txt(400, 'data tidak valid'); }
  if (b.action === 'export') {
    let users = [], page = 1;
    for (;;) {
      const r = await sbq(env, `/auth/v1/admin/users?page=${page}&per_page=1000`);
      if (!r.ok) return txt(500, (r.data && r.data.msg) || 'gagal membaca pengguna');
      const list = (r.data && r.data.users) || [];
      users = users.concat(list.map(u => ({ id: u.id, email: u.email })));
      if (list.length < 1000) break; page++;
    }
    return out(200, { users });
  }
  if (b.action === 'import') {
    if (!b.password || b.password.length < 8) return txt(400, 'password minimal 8 karakter');
    const results = [];
    for (const u of b.users || []) {
      const c = await sbq(env, '/auth/v1/admin/users', { method: 'POST', body: JSON.stringify({ id: u.id, email: u.email, password: b.password, email_confirm: true }) });
      const nid = c.ok ? (c.data.id || (c.data.user && c.data.user.id)) : null;
      if (c.ok && nid === u.id) { results.push({ id: u.id, email: u.email, status: 'created' }); continue; }
      if (c.ok) { await sbq(env, '/auth/v1/admin/users/' + nid, { method: 'DELETE' }); results.push({ id: u.id, email: u.email, status: 'id_unsupported' }); continue; }
      const ex = await sbq(env, '/auth/v1/admin/users/' + u.id);
      results.push({ id: u.id, email: u.email, status: ex.ok ? 'exists_id' : 'email_taken' });
    }
    return out(200, { results });
  }
  return txt(400, 'aksi tidak dikenal');
}
const esc = s => String(s == null ? '' : s).replace(/[\\;,]/g, '\\$&').replace(/\r?\n/g, '\\n');
const d8 = s => s.replace(/-/g, '');
const dt = s => new Date(s).toISOString().replace(/[-:]/g, '').replace(/\.\d+/, '');
async function all(env, table, vid) {
  let o = [], off = 0;
  for (;;) {
    const r = await sbq(env, `/rest/v1/${table}?vendor_id=eq.${vid}&select=*&order=id&limit=1000&offset=${off}`);
    if (!r.ok || !Array.isArray(r.data)) break;
    o = o.concat(r.data); if (r.data.length < 1000) break; off += 1000;
  }
  return o;
}
async function calendar(req, env) {
  const t = req.query && req.query.t;
  if (!t || t.length < 20) return txt(404, 'not found');
  const vr = await sbq(env, `/rest/v1/vendors?cal_token=eq.${encodeURIComponent(t)}&select=id,name,app_name,status,expires_at&limit=1`);
  const v = vr.ok && Array.isArray(vr.data) ? vr.data[0] : null;
  if (!v || v.status !== 'active' || (v.expires_at && v.expires_at < new Date().toISOString().slice(0, 10))) return txt(404, 'not found');
  const [ev, bk, mt, cl] = await Promise.all(['events', 'bookings', 'meetings', 'clients'].map(x => all(env, x, v.id)));
  const cn = id => (cl.find(c => c.id === id) || {}).name || '';
  const L = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Vendor CRM//ID', 'CALSCALE:GREGORIAN', 'X-WR-CALNAME:' + esc(v.app_name || v.name), 'REFRESH-INTERVAL;VALUE=DURATION:PT1H', 'X-PUBLISHED-TTL:PT1H'];
  const stamp = dt(Date.now());
  const allday = (uid, date, sum, desc) => { const n = new Date(date + 'T00:00:00Z'); n.setUTCDate(n.getUTCDate() + 1); L.push('BEGIN:VEVENT', 'UID:' + uid + '@vendor-crm', 'DTSTAMP:' + stamp, 'DTSTART;VALUE=DATE:' + d8(date), 'DTEND;VALUE=DATE:' + d8(n.toISOString().slice(0, 10)), 'SUMMARY:' + esc(sum), 'DESCRIPTION:' + esc(desc), 'END:VEVENT'); };
  ev.filter(x => x.event_date).forEach(x => allday('ev' + x.id, x.event_date, '🎉 ' + (x.title || 'Acara') + (cn(x.client_id) ? ' — ' + cn(x.client_id) : ''), x.venue ? 'Lokasi: ' + x.venue : ''));
  bk.filter(x => x.event_date && x.status !== 'cancelled').forEach(x => allday('bk' + x.id, x.event_date, '📋 Booking: ' + (x.package || '') + (cn(x.client_id) ? ' — ' + cn(x.client_id) : ''), 'Status: ' + x.status));
  mt.filter(x => x.meet_at && x.status !== 'batal').forEach(x => L.push('BEGIN:VEVENT', 'UID:mt' + x.id + '@vendor-crm', 'DTSTAMP:' + stamp, 'DTSTART:' + dt(x.meet_at), 'DTEND:' + dt(new Date(x.meet_at).getTime() + 36e5), 'SUMMARY:' + esc('🤝 Meeting ' + cn(x.client_id)), 'LOCATION:' + esc(x.place), 'DESCRIPTION:' + esc(x.notes), 'END:VEVENT'));
  L.push('END:VCALENDAR');
  return out(200, L.join('\r\n'), { 'Cache-Control': 'max-age=300' }, 'text/calendar; charset=utf-8');
}
async function handle(name, req, env) {
  const c = cors(env, req.headers('origin'));
  if (req.method === 'OPTIONS') return { status: 204, headers: c, body: '' };
  const miss = [];
  if (!/^https?:\/\//.test(String(env.SUPABASE_URL || ''))) miss.push('SUPABASE_URL');
  if (!env.SUPABASE_SERVICE_ROLE_KEY) miss.push('SUPABASE_SERVICE_ROLE_KEY');
  if (miss.length) return out(500, 'Pengaturan server belum lengkap: variabel ' + miss.join(' dan ') + ' belum terbaca oleh host. Isi di Settings > Variables and Secrets (bagian runtime, bukan Build), lalu deploy ulang.', c, 'text/plain; charset=utf-8');
  try {
    const r = name === 'create-user' ? await createUser(req, env) : name === 'migrate-users' ? await migrateUsers(req, env) : name === 'calendar' ? await calendar(req, env) : txt(404, 'not found');
    r.headers = { ...r.headers, ...c };
    return r;
  } catch (e) { return out(500, 'server error: ' + (e.message || e), c, 'text/plain; charset=utf-8'); }
}
module.exports = { handle };
