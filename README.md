# Vendor CRM v1.7.1 (Netlify + GitHub + Supabase)
> Hosting ganda Cloudflare Pages + Netlify: lihat `DEPLOY-DUAL.md`; pemula: `PANDUAN-CLOUDFLARE.md`.

## Instalasi baru (project Supabase kosong)
1. Supabase → SQL Editor → New query → tempel isi `supabase/full_setup.sql` → Run (sekali saja).
2. Authentication → Users → Add user → Create new user (email + password, centang Auto Confirm).
3. SQL Editor → tempel `supabase/01_create_admin.sql` (ganti email) → Run.
4. `config.js` sudah berisi URL + publishable key. Push repo ke GitHub → Netlify (publish dir `.`).
5. Netlify → Site configuration → Environment variables: `SUPABASE_URL` (sama dengan URL di config.js) dan `SUPABASE_SERVICE_ROLE_KEY` (Secret key `sb_secret_...` atau legacy service_role dari Supabase → Settings → API Keys). JANGAN taruh di config.js/GitHub. Deploy ulang.
6. Supabase → Authentication → URL Configuration → Site URL = domain Anda. Pasang domain di Netlify.
7. Buka aplikasi → login admin → menu Vendor → tambah vendor → menu Pengguna → buat akun owner.
Upgrade dari versi lama: jalankan file `migration_x.y.z.sql` yang belum dijalankan, berurutan. Pindah server: `MIGRASI.md`.
