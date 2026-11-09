-- v1.9.0 — jalankan SETELAH migration_1.8.0.sql
create table followups(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),client_id uuid references clients on delete cascade,booking_id uuid references bookings on delete cascade,ctx text,code text,title text,due_date date,channel text default 'WhatsApp',template_key text,status text default 'terjadwal',done_at timestamptz,note text);
create table targets(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),ym text,income numeric default 0,bookings int default 0);
do $$ declare t text; v text:='is_admin() or (vendor_id=my_vendor() and vendor_ok() and '; begin
foreach t in array array['followups','targets'] loop
 execute format('alter table %I enable row level security',t);
 execute format('create policy s on %I for select using ('||v||'mod_lvl(%L)<>''none''))',t,t);
 execute format('create policy i on %I for insert with check ('||v||'mod_lvl(%L)=''w''))',t,t);
 execute format('create policy u on %I for update using ('||v||'mod_lvl(%L)=''w''))',t,t);
 execute format('create policy d on %I for delete using ('||v||'mod_lvl(%L)=''w'' and my_role()=''owner''))',t,t);
 execute format('create trigger t_audit after insert or update or delete on %I for each row execute function audit_fn()',t);
end loop; end $$;

create or replace function import_bulk(p_table text,p_rows jsonb,p_first boolean default false) returns int language plpgsql security definer set search_path=public as $$
declare n int;
begin
 if not is_admin() then raise exception 'hanya admin'; end if;
 if p_table<>all(array['vendors','profiles','clients','packages','bookings','events','meetings','invoices','payments','partnerships','deliverables','requirements','wa_templates','quotes','expenses','blocked_dates','assignments','reviews','followups','targets','vendor_bills','reminder_log','category_matrix','wa_defaults','app_releases','audit_log']) then raise exception 'tabel tidak diizinkan'; end if;
 perform set_config('app.import','1',true);
 if p_first and p_table in('category_matrix','wa_defaults','app_releases') then execute format('delete from %I',p_table); end if;
 if p_table='audit_log' then
  insert into audit_log(created_at,vendor_id,user_id,user_name,table_name,row_id,action,old_data,new_data)
  select created_at,vendor_id,user_id,user_name,table_name,row_id,action,old_data,new_data from jsonb_populate_recordset(null::audit_log,p_rows);
 else execute format('insert into %1$I select * from jsonb_populate_recordset(null::%1$I,$1) on conflict do nothing',p_table) using p_rows; end if;
 get diagnostics n=row_count; return n;
end $$;

insert into wa_defaults values
('fu_sapa','FU Lead: Sapa & kirim paket','Halo Kak {{nama}}, terima kasih sudah menghubungi {{vendor}} 🙏 Berikut informasi paket kami. Boleh tahu rencana tanggal acaranya dan kebutuhan utamanya?'),
('fu_2','FU Lead: Tanya kabar','Halo Kak {{nama}}, kami dari {{vendor}} ingin menanyakan kabar rencana acaranya. Apakah ada yang ingin ditanyakan atau didiskusikan?'),
('fu_meeting','FU Lead: Ajak meeting','Halo Kak {{nama}}, bagaimana kalau kita jadwalkan konsultasi singkat (online/offline) supaya kami bisa menyesuaikan paket dengan kebutuhan Kakak? Kapan waktu yang nyaman?'),
('fu_terakhir','FU Lead: Follow up terakhir','Halo Kak {{nama}}, kami follow up terakhir ya. Jika tanggal acara masih tersedia, kami siap membantu. Kabari kami kapan pun Kakak siap 🙏'),
('fu_reaktivasi','FU Lead: Reaktivasi','Halo Kak {{nama}}, apa kabar? {{vendor}} ingin menanyakan apakah rencana acaranya masih berjalan. Ada penawaran terbaru yang mungkin cocok untuk Kakak.'),
('fu_terimakasih_meeting','FU Lead: Terima kasih meeting','Halo Kak {{nama}}, terima kasih sudah meluangkan waktu untuk meeting dengan {{vendor}} 🙏 Kami akan kirimkan ringkasan dan penawarannya segera.'),
('fu_penawaran','FU Lead: Penawaran','Halo Kak {{nama}}, penawaran dari {{vendor}} sudah kami kirim. Mohon dicek ya, dan kabari kami jika ada yang ingin disesuaikan.'),
('fu_negosiasi','FU Lead: Negosiasi','Halo Kak {{nama}}, kami bisa bantu menyesuaikan paket sesuai budget Kakak. Bagaimana menurut Kakak?'),
('bk_terimakasih','FU Booking: Terima kasih','Halo Kak {{nama}}, terima kasih sudah mempercayakan acara {{tanggal}} kepada {{vendor}} 🙏 Kami akan kabarkan detail selanjutnya.'),
('bk_dp','FU Booking: Cek DP','Halo Kak {{nama}}, kami ingin memastikan pembayaran DP untuk acara {{tanggal}} sudah kami terima dan tercatat. Mohon info jika ada kendala ya.'),
('bk_detail','FU Booking: H-60 detail','Halo Kak {{nama}}, acara {{tanggal}} tinggal sekitar 2 bulan lagi. Mari kita konfirmasi detail kebutuhan (konsep, jumlah tamu, lokasi) agar persiapan lancar.'),
('bk_h30','FU Booking: H-30','Halo Kak {{nama}}, acara {{tanggal}} tinggal 30 hari lagi. Mengingatkan pelunasan dan finalisasi rundown/kebutuhan ya 🙏'),
('bk_h14','FU Booking: H-14','Halo Kak {{nama}}, 2 minggu menuju acara {{tanggal}}. Mohon konfirmasi akhir jumlah, lokasi, dan jadwal agar tim kami siap.'),
('bk_h7','FU Booking: H-7','Halo Kak {{nama}}, seminggu lagi acara {{tanggal}}! Kami kirim briefing final dan kontak tim lapangan. Ada yang perlu diubah?'),
('bk_h1','FU Booking: H-1','Halo Kak {{nama}}, besok acara {{tanggal}}. Tim {{vendor}} siap hadir. Selamat mempersiapkan hari bahagia Kakak 🙏'),
('bk_pasca','FU Booking: Pasca acara','Halo Kak {{nama}}, terima kasih sudah mempercayakan acara kemarin kepada {{vendor}} 🙏 Semoga berkesan. Kami akan segera menyiapkan hasilnya.'),
('bk_hasil','FU Booking: Hasil & ulasan','Halo Kak {{nama}}, hasil pekerjaan acara {{tanggal}} sudah bisa Kakak cek. Jika ada revisi atau masukan, kabari kami ya. Boleh juga bantu beri ulasan 🙏'),
('bk_30','FU Booking: H+30 tanya kabar','Halo Kak {{nama}}, apa kabar? Kami dari {{vendor}} ingin menanyakan kesan setelah acara. Jika ada kebutuhan lain, kami siap membantu.'),
('bk_anniv','FU Booking: Anniversary','Halo Kak {{nama}}, selamat hari jadi/anniversary! 🎉 Dari {{vendor}}, semoga selalu bahagia. Jika ada teman atau keluarga yang butuh layanan kami, kami senang sekali dikenalkan.');
insert into wa_templates(vendor_id,key,title,body) select v.id,d.key,d.title,d.body from vendors v,wa_defaults d where not exists(select 1 from wa_templates w where w.vendor_id=v.id and w.key=d.key);
insert into app_releases(version,notes) values('1.9.0','Analitik manajemen (tren, proyeksi, per paket/sumber, umur piutang, musiman, target) dan rencana follow-up client otomatis.');
