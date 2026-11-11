# Panduan pemula: Vendor CRM di Cloudflare lewat GitHub (v1.16)

Struktur repo sekarang cocok untuk dua jenis proyek Cloudflare: **Workers** (yang dibuat dashboard terbaru, memakai "npx wrangler deploy") dan **Pages**.
Folder `public/` = file situs. `src/worker.js` + `wrangler.jsonc` = jalur Workers. `functions/` = jalur Pages. `lib/api.js` = logika fungsi server (dipakai semuanya).

## A. Perbaikan error "functions directory and static files in its root"
Penyebab: struktur lama (v1.15) menaruh file situs di akar repo bersama folder `functions`. Dashboard Workers menolaknya.
1. Ekstrak zip v1.16.x. Pastikan terlihat folder `public`, `src`, `lib`, `functions`, `supabase` dan file `wrangler.jsonc`.
2. GitHub → repo Anda → **Add file → Upload files** → seret SEMUA isi folder (termasuk `public`, `src`, `wrangler.jsonc`) → **Commit changes**.
3. Cek nama proyek di Cloudflare (Workers & Pages). Buka `wrangler.jsonc` di GitHub (ikon pensil) dan pastikan baris `"name"` SAMA PERSIS dengan nama proyek tersebut (bawaan: `vendor-crm`). Ubah bila beda, lalu Commit.
4. Cloudflare membangun otomatis setelah commit. Di log harus muncul `Executing user deploy command: npx wrangler deploy` lalu tanda berhasil.
5. (Opsional) hapus file lama di akar repo yang sudah pindah ke `public/` (index.html, app.js, config.js, style.css, sw.js, version.js, manifest.webmanifest, icon-192.png, icon-512.png, book.html, portal.html, review.html, sign.html, _headers). Tidak wajib; tidak mengganggu.

## B. Variabel rahasia (wajib untuk Pengguna, Migrasi, Kalender)
`SUPABASE_URL` (alamat publik) sudah tertulis di `wrangler.jsonc` bagian `vars`; ubah di sana jika Supabase Anda berbeda.
Yang WAJIB Anda isi sendiri: Proyek → **Settings** → **Variables and Secrets** (yang untuk *runtime*, BUKAN bagian *Build*):
- `SUPABASE_SERVICE_ROLE_KEY` = Secret key Supabase, tipe **Secret**
- `ALLOWED_ORIGINS` = boleh kosong dulu (Text)
Lalu jalankan build ulang (Deployments → Retry / atau commit kecil).

## C. Alamat situs
Jalur Workers: `https://vendor-crm.<akun>.workers.dev` (lihat Settings → Domains & Routes; aktifkan workers.dev bila belum tampil).
Jalur Pages: `https://namaproyek.pages.dev`.

## D. Uji
Login admin → Pengguna → Buat akun (harus berhasil) → Kalender → Sinkron Google Kalender (link `/cal.ics?t=...` harus mengunduh kalender).

## E. Jika memilih Pages (bukan Workers)
Workers & Pages → Create application → tab Pages → Import an existing Git repository. Framework None, Build command `exit 0`, Build output directory `public`.

## F. Memperbarui aplikasi
GitHub → Add file → Upload files → seret isi versi baru (timpa) → Commit. Cloudflare membangun ulang otomatis.

## G. Masalah umum
- Pesan `unauthorized` saat Buat akun: (1) keluar lalu masuk lagi; (2) pastikan tabel `profiles` memuat akun Anda (peran admin/owner, aktif); (3) pastikan `SUPABASE_ANON_KEY` (kunci publishable) ada di wrangler.jsonc dan `SUPABASE_SERVICE_ROLE_KEY` terisi sebagai Secret. Sejak v1.16.2 pesannya menyebutkan penyebab pastinya.
- Pesan `Invalid URL: /auth/v1/user` atau `Pengaturan server belum lengkap`: variabel `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` belum terbaca. Pastikan diisi di Variables and Secrets bagian runtime (bukan Build), kuncinya bertipe Secret, dan sudah deploy ulang. Di v1.16.1 `SUPABASE_URL` sudah ada di wrangler.jsonc dan `keep_vars` aktif agar variabel dashboard tidak terhapus saat deploy.
- Error nama (name mismatch) saat deploy: samakan `"name"` di wrangler.jsonc dengan nama proyek.
- 404: pastikan folder `public` berisi index.html di GitHub.
- Layar putih: Ctrl+Shift+R, baca kotak pesan error.
- Buat akun gagal: variabel belum diisi / belum build ulang.
