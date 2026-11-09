# Panduan pemula: pasang Vendor CRM di Cloudflare Pages lewat GitHub

Perkiraan waktu: 30-45 menit. Biaya: gratis. Anda butuh: file zip aplikasi, akun email, dan data Supabase (URL + Secret key).

## A. Siapkan file
1. Ekstrak zip `wedding-vendor-crm-v1.15.x.zip` ke satu folder (klik kanan → Extract All).
2. Buka folder hasil ekstrak. Pastikan di dalamnya LANGSUNG ada `index.html`, `app.js`, `config.js`, folder `functions`, `lib`, `supabase` (bukan folder di dalam folder).
3. Buka `config.js` dengan Notepad dan cek URL dan KEY Supabase sudah benar. (Kunci `sb_publishable_` aman. Kunci `sb_secret_` TIDAK BOLEH ditulis di file mana pun.)

## B. GitHub
1. Buat akun di github.com (gratis), lalu buka https://repo.new
2. Repository name: mis. `vendor-crm`. Pilih **Private**. Jangan centang README/.gitignore. Klik **Create repository**.
3. Di halaman repo kosong klik **uploading an existing file**.
4. Dari File Explorer, pilih SEMUA isi folder (Ctrl+A) lalu seret ke kotak GitHub. Tunggu semua terunggah (folder ikut terbawa).
5. Di bawah, klik **Commit changes** (cabang `main`). Periksa bahwa `index.html` tampil di daftar file paling atas.

## C. Cloudflare Pages
1. Daftar/login di dash.cloudflare.com (gratis, tanpa kartu kredit).
2. Menu **Workers & Pages** → **Create application** → tab **Pages** → **Import an existing Git repository** (atau **Connect to Git**).
3. Pilih **GitHub**, izinkan (Install & Authorize), pilih repo `vendor-crm` → **Begin setup**.
4. Isi:
   - Project name: mis. `vendorcrm` (jadi alamat `vendorcrm.pages.dev`)
   - Production branch: `main`
   - Framework preset: **None**
   - Build command: **`exit 0`**
   - Build output directory: **`/`** (jika ditolak, isi `.`)
5. Klik **Save and Deploy**. Tunggu sampai status berhasil.

## D. Isi variabel rahasia (wajib untuk fitur Pengguna, Migrasi, Kalender)
1. Buka proyek → **Settings** → **Variables and Secrets** (atau Environment variables).
2. Tambahkan untuk **Production**:
   - `SUPABASE_URL` = alamat Supabase Anda
   - `SUPABASE_SERVICE_ROLE_KEY` = Secret key (tipe **Secret**)
   - `ALLOWED_ORIGINS` = (boleh dikosongkan dulu; nanti isi alamat Netlify jika dipakai sebagai cadangan)
3. Buka **Deployments** → deploy terbaru → **Retry deployment** agar variabel terbaca.

## E. Uji
1. Buka `https://namaproyek.pages.dev` → login admin.
2. Pilih vendor → **Pengguna → Buat akun** (harus berhasil).
3. Menu **Kalender → Sinkron Google Kalender**: buka link `…/cal.ics?t=…`, harus terunduh file kalender.

## F. Memperbarui aplikasi
GitHub → repo → **Add file → Upload files** → seret isi versi baru (timpa file bernama sama) → **Commit changes**. Cloudflare memperbarui otomatis dalam 1-2 menit.

## G. Jika bermasalah
- 404 di alamat pages.dev: `index.html` tidak berada di akar repo atau output directory salah.
- Layar putih: tekan Ctrl+Shift+R; baca pesan di kotak "Aplikasi gagal dimuat".
- "Invalid API key": URL/KEY di `config.js` tidak cocok (harus dari project Supabase yang sama).
- Buat akun gagal / fungsi 404 atau 500: build command bukan `exit 0`, variabel belum diisi, atau belum **Retry deployment**.
- Pilihan Production branch kosong: pastikan sudah ada file di GitHub (langkah B).
