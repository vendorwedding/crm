# Hosting ganda: Cloudflare Pages (utama) + Netlify (cadangan)

Kode di repo ini sama untuk kedua host. Data tetap satu: Supabase. Fungsi server (buat pengguna, migrasi, kalender) ada di
`lib/api.js` dan dipakai oleh `netlify/functions/*` maupun `functions/*` (Cloudflare), tanpa library tambahan.

## 1. Susunan yang disarankan
- **Domain Anda → Cloudflare Pages** (utama). Alasan: file statis tidak dibatasi dan situs tidak "dijeda" saat kuota habis.
- **Netlify tetap aktif** (publish directory `public`) di alamat `namasitus.netlify.app` sebagai cadangan.
- Di `config.js` isi **keduanya dengan alamat utama**, supaya link yang dikirim ke client (portal, tanda tangan, ulasan, kalender) dan panggilan fungsi server tetap hidup walau Netlify mati:
  ```js
  window.CFG={PUBLIC:'https://app.domainanda.com',API:'https://app.domainanda.com',URL:'...',KEY:'...',fetch:...};
  ```
  (Biarkan `PUBLIC` dan `API` kosong `''` jika hanya memakai satu host.)

## 2. Pasang di Cloudflare Pages
1. Daftar/login Cloudflare → **Workers & Pages** → **Create** → **Pages** → **Import an existing Git repository** → pilih repo GitHub ini.
2. Framework preset: **None**. Build command: **`exit 0`** (jangan dikosongkan: Cloudflare menyarankan ini agar fungsi server Pages Functions aktif). Build output directory: **`public`**.
3. Setelah proyek jadi: **Settings → Variables and Secrets**, tambahkan (untuk Production):
   - `SUPABASE_URL` = alamat Supabase Anda
   - `SUPABASE_SERVICE_ROLE_KEY` = Secret key Supabase (jenis **Secret**, jangan pernah di config.js/GitHub)
   - `ALLOWED_ORIGINS` = alamat host lain yang boleh memanggil fungsi ini, dipisah koma, mis. `https://namasitus.netlify.app`
4. **Deployments → Retry deployment** agar variabel terbaca. Uji di `https://namaproyek.pages.dev`.
5. **Custom domains** → tambahkan domain/subdomain Anda dan ikuti petunjuk DNS di layar. (Subdomain biasanya cukup dengan CNAME; domain utama paling mudah bila DNS-nya di Cloudflare.)

## 3. Netlify (cadangan)
- Variabel lingkungan sama: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ALLOWED_ORIGINS` (isi alamat utama Cloudflare Anda).
- Hemat kredit: satu deploy produksi memakan 15 kredit dari 300 per bulan. Atur **Production branch** Netlify ke cabang `stable`, dan hanya perbarui `stable` saat ingin menyegarkan cadangan:
  `git checkout -b stable && git push -u origin stable` lalu, untuk menyegarkan: `git checkout stable && git merge main && git push`.
  Cloudflare tetap membangun dari `main`.

## 4. Supabase
Authentication → URL Configuration: **Site URL** = alamat utama; tambahkan alamat Netlify dan `pages.dev` ke **Redirect URLs**.

## 5. Uji setelah pasang (di kedua host)
- Login admin berhasil, data tampil.
- Menu **Pengguna → Buat akun** berhasil (menguji fungsi server).
- Menu **Kalender → Sinkron Google Kalender**: buka link `…/cal.ics?t=…` di browser, harus terunduh file kalender.
- Buka dari host Netlify: **Buat akun** tetap berhasil (menguji panggilan lintas host ke Cloudflare; butuh `ALLOWED_ORIGINS`).

## 6. Jika Netlify mati / kredit habis
- Pengguna yang sudah pernah membuka aplikasi (terutama yang memasangnya sebagai PWA): aplikasi tetap terbuka dari salinan di perangkat, data tetap lewat Supabase.
- Pengguna lain: berikan alamat Cloudflare/domain utama.
- Bila domain terlanjur diarahkan ke Netlify: ubah DNS-nya ke Cloudflare Pages.

## 7. Batasan
- Pengalihan otomatis (failover) antar host tidak tersedia gratis; pengalihan dilakukan manual seperti di atas.
- Kedua host harus diperbarui bila ada versi baru (Netlify bisa sengaja lebih jarang, lihat bagian 3).
- Halaman bergantung pada Supabase: bila Supabase bermasalah, kedua host ikut terdampak.

## 8. Catatan struktur (v1.16)
File situs ada di `public/`. Cloudflare **Workers** memakai `wrangler.jsonc` + `src/worker.js`; Cloudflare **Pages** memakai `functions/`; Netlify memakai `netlify/functions/` dan `publish = "public"`. Semua memanggil logika yang sama di `lib/api.js`. Panduan pemula: `PANDUAN-CLOUDFLARE.md`.
