# Pindah ke Supabase baru (Migrasi Penuh)
1. **Instance lama** — login admin → menu *Migrasi Data* → *Ekspor Migrasi Penuh*. Simpan ZIP (berisi data sensitif, simpan aman).
2. **Supabase baru** — buat project; di SQL Editor jalankan berurutan: `schema.sql`, `migration_1.1.0.sql` … `migration_1.7.0.sql`.
3. Buat admin di project baru: Authentication → Users → Add user (auto-confirm), lalu SQL:
   `insert into profiles(id,role,full_name) values('<UUID-user>','admin','Admin');`
4. Arahkan aplikasi ke project baru: `config.js` (URL + anon key) dan env Netlify `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY`; deploy ulang (atau buat site Netlify kedua untuk uji dulu).
5. Supabase baru → Auth → URL Configuration → isi Site URL dengan domain Anda.
6. Login admin di instance baru → *Migrasi Data* → pilih ZIP, isi password sementara (min 8) → *Mulai impor*.
7. Periksa log (jumlah baris tiap tabel), buka beberapa vendor, coba login satu owner dengan password sementara.
8. Beri tahu semua pengguna: login dengan password sementara lalu klik *Ubah password*.
9. Setelah yakin, nonaktifkan project lama.
