# Riwayat Rilis
## 1.16.3
- Fungsi server mendeteksi bila SUPABASE_SERVICE_ROLE_KEY berisi kunci publik (publishable/anon) dan menampilkan pesan jelas; pesan "profil tidak terbaca" diperjelas.
## 1.16.2
- Perbaikan "unauthorized" saat Buat akun/Migrasi: token pengguna kini diverifikasi dengan kunci publik (publishable) bukan kunci rahasia; browser mengirim header apikey; SUPABASE_ANON_KEY di wrangler.jsonc. Pesan error 401 kini menyebutkan penyebab (token, sesi, atau profil).
## 1.16.1
- Perbaikan: error "Invalid URL: /auth/v1/user" saat Buat akun (variabel server tidak terbaca di Cloudflare Workers). SUPABASE_URL kini ada di wrangler.jsonc, keep_vars aktif, dan fungsi server menampilkan pesan jelas bila variabel belum diisi.
## 1.16.0
- Struktur repo universal: file situs dipindah ke public/; tambah wrangler.jsonc + src/worker.js (Cloudflare Workers, perbaikan error "functions directory and static files in its root"); functions/ tetap untuk Cloudflare Pages; Netlify publish = public. Folder supabase/, lib/, dokumen tidak ikut dipublikasikan.
## 1.15.1
- Koreksi panduan hosting: Build command Cloudflare Pages harus `exit 0` (bukan kosong) agar fungsi server aktif. Tambah PANDUAN-CLOUDFLARE.md (langkah demi langkah untuk pemula).
## 1.15.0
- Hosting ganda: kode siap dipasang di Cloudflare Pages dan Netlify sekaligus (fungsi server memakai logika bersama lib/api.js tanpa library; adapter untuk kedua host; /api/* dan /cal.ics). config.js punya PUBLIC (alamat tetap untuk link publik) dan API (alamat fungsi server) agar cadangan tetap berfungsi.
- PWA: bila host mati/dijeda, file aplikasi dilayani dari salinan di perangkat. Panduan: DEPLOY-DUAL.md.
## 1.14.0
- Warna tema per vendor: pilih warna utama sendiri (kotak warna + pilihan cepat, pratinjau langsung) di Pengaturan; berlaku di seluruh aplikasi dan dokumen cetak. Warna terlalu terang ditolak demi keterbacaan.
- Tooltip Analitik Client kini menjelaskan arti tiap status (Lead baru, Lead belum ada follow-up, Booking belum ada invoice, dll.) beserta tindak lanjutnya; label keterkaitan di tabel Client/Booking juga punya penjelasan.
## 1.13.0
- Matriks Kebutuhan: cari/pilih booking dengan mengetik (daftar otomatis menyaring), kelompokkan menurut booking/kebutuhan/status; tombol Muat matriks tidak menggandakan item.
- Tampilan profesional: header dengan logo/monogram, formulir 2 kolom dengan judul berwarna, tabel zebra dengan header tetap, kartu, tombol dan kolom isian yang konsisten.
- Dokumen cetak/PDF dengan kop surat (logo, nama, alamat, kontak, NPWP): Invoice, Penawaran, Kwitansi (terbilang), Perjanjian Kerjasama (dengan tanda tangan), laporan dan semua ekspor PDF, ringkasan Client/Booking; ekspor Excel diberi judul dan tanggal cetak.
- Profil vendor di Pengaturan: alamat, email, website, NPWP, nama dan jabatan penanda tangan.
- Pilihan booking di semua formulir kini menampilkan paket - client - tanggal acara.
## 1.12.2
- Ketahanan tampilan: layar tidak lagi putih diam-diam. Jika ada error, muncul pesan jelas + tombol Bersihkan cache; halaman yang gagal menampilkan pesan, bukan kosong; menu punya cadangan bila pengelompokan gagal.
## 1.12.1
- Menu dikelompokkan menurut fungsi dan diurutkan dari yang terpenting (Utama, Client & Penjualan, Jadwal, Keuangan, Operasional, Komunikasi, Laporan & Analitik, Pengaturan & Data, Bantuan; Admin Platform khusus admin); kelompok bisa dilipat, ada pencarian menu, daftar menu bisa di-scroll; header dan menu tetap terlihat saat halaman di-scroll.
## 1.12.0
- Invoice/penawaran terhitung otomatis: DP % dari total booking, pelunasan = sisa belum ditagihkan, diskon, biaya tambahan, pajak termasuk/ditambahkan (centang); nominal tetap bisa manual. Status invoice otomatis (unpaid/partial/paid) dari pembayaran; form pembayaran mengisi sisa tagihan.
- Daftar Crew dengan tugas bercentang (multi-tugas), penugasan terhubung ke crew, Laporan Crew (pekerjaan, honor, riwayat pembayaran).
- Analitik Client per bulan/tahun/semua/rentang dengan status bisa dicentang + daftar tindak lanjut; client bisa disaring/dikelompokkan menurut status keterkaitan.
## 1.11.0
- Keterkaitan data: kolom Keterkaitan (label berwarna) di Client/Booking/Invoice/Penawaran; Ringkasan Client dan Booking (semua data terkait + tambah cepat + riwayat); rincian Invoice; nama client/booking/invoice menjadi link di semua tabel, Pipeline, Pengingat, dan Follow-up.
## 1.10.0
- Tooltip penjelasan pada semua menu, tombol, kartu, kolom tabel, isian, dan dropdown (bisa dimatikan lewat tombol Bantuan); halaman Cara Pakai: checklist mulai cepat, pencarian topik, panduan per fitur, dan link langsung ke halaman/sumber terkait.
## 1.9.0
- Analitik manajemen: KPI, target vs capaian, tren 12 bulan (YoY, arus kas), proyeksi 6 bulan, per paket, per sumber lead, umur piutang, musiman, keterisian tanggal; menu Target.
- Follow-up client otomatis: rencana lead (per tahap pipeline) dan booking (konfirmasi sampai H-60...H-1, pasca acara, H+30, anniversary); halaman Follow-up dengan Kirim WA/Selesai/Tunda/Lewati; 19 template WA baru.
## 1.8.0
- Kolom Client/Booking/Invoice dll bisa dicari dengan mengetik + dropdown; Sumber lead & Paket bisa pilih dari daftar atau ketik manual (harga paket terisi otomatis di booking); No. Invoice (INV-YYMM-001), No. Kwitansi (KW-...) dan Penawaran (QT-...) otomatis tapi bisa diubah; tanggal terbit invoice (default hari ini); klik judul kolom untuk mengurutkan di semua tabel.
## 1.7.3
- config.js diarahkan ke project Supabase vemlizysczqplrusnvoq.
## 1.7.2
- Perbaikan "Invalid API key" saat memakai kunci baru Supabase (sb_publishable_/sb_secret_): kunci dikirim hanya lewat header apikey (aplikasi, halaman publik, dan Netlify Functions).
## 1.7.1
- Skrip instalasi tunggal supabase/full_setup.sql + 01_create_admin.sql; config.js terisi untuk project Supabase Anda.
## 1.7.0
- Migrasi penuh antar Supabase (admin): ekspor ZIP (semua tabel, pengguna tanpa password, file logo/QRIS/bukti bayar) dan impor ke instance baru; tombol Ubah password.
## 1.6.0
- Impor CSV (client, booking, pengeluaran); Dashboard Platform + peringatan masa aktif; jadwal cicilan otomatis (invoice bertahap) + diskon/pajak/biaya tambahan di invoice & penawaran; tim & honor crew (cek bentrok, honor dibayar otomatis jadi pengeluaran); ulasan client (review.html, tampil di form booking, masuk Pengingat); pulihkan backup.
## 1.5.0
- Audit log (siapa mengubah apa & kapan, tidak bisa diubah dari aplikasi); PWA (pasang di HP/PC, data terakhir tetap bisa dilihat saat offline, cache dihapus saat logout); backup data JSON per vendor/semua vendor + catatan backup terakhir.
## 1.4.0
- Form booking publik (book.html) + pipeline lead; peringatan bentrok jadwal, kuota & blokir tanggal; paket & penawaran (jadi booking+invoice DP); invoice/penawaran PDF dengan logo, rekening, QRIS; pengeluaran & laba rugi per acara; tagihan langganan vendor (bayar = masa aktif otomatis diperpanjang).
- Perbaikan: edit data oleh admin pada mode "Semua vendor"; dropdown vendor admin kini menampilkan pilihan aktif.
## 1.3.0
- Sinkron Google Kalender: link langganan iCal per vendor (acara, booking, meeting), bisa dibuat ulang/dicabut.
## 1.2.0
- Pengingat client (antrean WA semi-otomatis, anti-duplikat 3 hari); tanda tangan digital kerjasama via link publik (sign.html); portal client read-only via link acak (portal.html), link bisa dibuat ulang/dicabut.
## 1.1.0
- Kalender visual; Laporan dengan grafik + filter tanggal; ekspor Excel (CSV) & PDF di semua tabel; upload bukti bayar (privat, maks 2 MB); editor matriks kebutuhan per kategori (admin); akses per modul (tidak boleh lihat / baca / tulis) per pengguna.
## 1.0.0 — rilis awal
- Multi-vendor, peran admin/owner/staff/guest, masa aktif akun (selamanya/durasi/tanggal), CRM, invoice, bukti bayar, template WA, branding.
