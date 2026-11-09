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
Proyek → **Settings** → **Variables and Secrets** → tambahkan:
- `SUPABASE_URL` = alamat Supabase
- `SUPABASE_SERVICE_ROLE_KEY` = Secret key (tipe Secret)
- `ALLOWED_ORIGINS` = boleh kosong dulu
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
- Error nama (name mismatch) saat deploy: samakan `"name"` di wrangler.jsonc dengan nama proyek.
- 404: pastikan folder `public` berisi index.html di GitHub.
- Layar putih: Ctrl+Shift+R, baca kotak pesan error.
- Buat akun gagal: variabel belum diisi / belum build ulang.
