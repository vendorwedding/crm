-- Vendor CRM v1.0.0 — jalankan di Supabase > SQL Editor
create extension if not exists pgcrypto;
create table vendors(id uuid primary key default gen_random_uuid(),name text not null,category text,app_name text,logo_url text,wa_phone text,
 status text not null default 'active' check (status in('active','inactive')),
 access_type text not null default 'lifetime' check (access_type in('lifetime','duration','until_date')),
 duration_days int,expires_at date,created_at timestamptz default now());
create table profiles(id uuid primary key references auth.users on delete cascade,vendor_id uuid references vendors on delete cascade,
 role text not null check (role in('admin','owner','staff','guest')),full_name text,active boolean default true,permissions jsonb default '{"write":true}');

create function my_role() returns text language sql stable security definer set search_path=public as $$select role from profiles where id=auth.uid() and active$$;
create function my_vendor() returns uuid language sql stable security definer set search_path=public as $$select vendor_id from profiles where id=auth.uid() and active$$;
create function is_admin() returns boolean language sql stable security definer set search_path=public as $$select coalesce(my_role()='admin',false)$$;
create function vendor_ok() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from vendors v where v.id=my_vendor() and v.status='active' and (v.expires_at is null or v.expires_at>=current_date))$$;
create function can_write() returns boolean language sql stable security definer set search_path=public as $$
 select coalesce(my_role() in('owner','staff'),false) and coalesce((select permissions->>'write' from profiles where id=auth.uid()),'true')<>'false'$$;

create table clients(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),name text not null,phone text,email text,address text,notes text);
create table bookings(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),client_id uuid references clients on delete set null,package text,event_date date,total numeric default 0,status text default 'inquiry',notes text);
create table events(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),client_id uuid references clients on delete set null,booking_id uuid references bookings on delete set null,title text,event_date date,venue text,notes text);
create table meetings(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),client_id uuid references clients on delete set null,meet_at timestamptz,place text,status text default 'dijadwalkan',notes text);
create table invoices(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),client_id uuid references clients on delete set null,booking_id uuid references bookings on delete set null,number text,type text default 'dp',amount numeric default 0,due_date date,status text default 'unpaid');
create table payments(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),invoice_id uuid references invoices on delete set null,amount numeric default 0,paid_at date default current_date,method text,receipt_no text,proof_url text);
create table partnerships(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),partner_name text,type text,terms text,status text default 'aktif');
create table deliverables(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),booking_id uuid references bookings on delete set null,title text,due_date date,status text default 'proses',link text);
create table requirements(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),booking_id uuid references bookings on delete set null,item text,qty int default 1,status text default 'todo');
create table wa_templates(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),key text,title text,body text);
create table wa_defaults(key text,title text,body text);
create table category_matrix(category text,item text);
create table app_releases(id uuid primary key default gen_random_uuid(),version text not null,released_at date default current_date,notes text,created_at timestamptz default now());

-- RLS tabel data vendor: admin = semua; vendor = hanya miliknya & hanya jika akun aktif/belum kedaluwarsa
-- guest = baca saja; staff = baca/tulis (bisa dibatasi permissions.write=false); owner = + hapus
do $$ declare t text; begin
foreach t in array array['clients','bookings','events','meetings','invoices','payments','partnerships','deliverables','requirements','wa_templates'] loop
 execute format('alter table %I enable row level security',t);
 execute format('create policy s on %I for select using (is_admin() or (vendor_id=my_vendor() and vendor_ok()))',t);
 execute format('create policy i on %I for insert with check (is_admin() or (vendor_id=my_vendor() and vendor_ok() and can_write()))',t);
 execute format('create policy u on %I for update using (is_admin() or (vendor_id=my_vendor() and vendor_ok() and can_write()))',t);
 execute format('create policy d on %I for delete using (is_admin() or (vendor_id=my_vendor() and vendor_ok() and my_role()=''owner''))',t);
end loop;
foreach t in array array['wa_defaults','category_matrix','app_releases'] loop
 execute format('alter table %I enable row level security',t);
 execute format('create policy s on %I for select to authenticated using (true)',t);
 execute format('create policy w on %I for all using (is_admin()) with check (is_admin())',t);
end loop; end $$;

alter table vendors enable row level security;
create policy vs on vendors for select using (is_admin() or id=my_vendor());
create policy vw on vendors for all using (is_admin()) with check (is_admin());
alter table profiles enable row level security;
create policy ps on profiles for select using (id=auth.uid() or is_admin() or (my_role()='owner' and vendor_id=my_vendor()));
create policy pu on profiles for update using (is_admin() or (my_role()='owner' and vendor_id=my_vendor() and role<>'admin'))
 with check (is_admin() or (my_role()='owner' and vendor_id=my_vendor() and role<>'admin'));

create function update_branding(p_vendor uuid,p_app text,p_logo text) returns void language plpgsql security definer set search_path=public as $$
begin if is_admin() or (my_role()='owner' and my_vendor()=p_vendor) then update vendors set app_name=p_app,logo_url=p_logo where id=p_vendor; else raise exception 'tidak berwenang'; end if; end $$;
create function seed_vendor() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into wa_templates(vendor_id,key,title,body) select new.id,key,title,body from wa_defaults; return new; end $$;
create trigger t_seed after insert on vendors for each row execute function seed_vendor();

-- Logo: bucket publik, maks 512 KB
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('logos','logos',true,524288,array['image/png','image/jpeg','image/webp']);
create policy logo_ins on storage.objects for insert to authenticated with check (bucket_id='logos' and (is_admin() or (storage.foldername(name))[1]=my_vendor()::text));

insert into wa_defaults values
('dp','Permintaan DP','Halo Kak {{nama}}, terima kasih telah memilih {{vendor}} untuk acara tanggal {{tanggal}}. Untuk mengunci tanggal, mohon DP {{nominal}} (invoice {{invoice}}) paling lambat {{jatuh_tempo}}. Terima kasih 🙏'),
('pelunasan','Permintaan Pelunasan','Halo Kak {{nama}}, mengingatkan pelunasan acara tanggal {{tanggal}} sebesar {{sisa}} (invoice {{invoice}}), jatuh tempo {{jatuh_tempo}}. Terima kasih 🙏'),
('followup','Follow Up','Halo Kak {{nama}}, kami dari {{vendor}} ingin follow up terkait rencana acara Kakak. Apakah ada yang bisa kami bantu?'),
('reminder','Reminder Acara/Meeting','Halo Kak {{nama}}, mengingatkan jadwal bersama {{vendor}} pada {{tanggal}}. Mohon konfirmasi kehadirannya ya 🙏'),
('terima_kasih','Konfirmasi Pembayaran','Halo Kak {{nama}}, pembayaran invoice {{invoice}} sebesar {{nominal}} sudah kami terima. Terima kasih! 🙏');
insert into category_matrix values
('fotografer','Daftar shot wajib'),('fotografer','Jumlah fotografer'),('fotografer','Album & cetak'),('fotografer','Deadline hasil edit'),
('mua','Look & tema makeup'),('mua','Jumlah orang dirias'),('mua','Jadwal mulai rias'),('mua','Touch up'),
('catering','Jumlah porsi'),('catering','Menu final'),('catering','Peralatan & staf'),('catering','Jam sajian'),
('decoration','Konsep & moodboard'),('decoration','Ukuran venue'),('decoration','Jam setup/bongkar'),('decoration','Daftar item dekor'),
('wedding organizer','Rundown acara'),('wedding organizer','Daftar vendor'),('wedding organizer','Jumlah tamu'),('wedding organizer','Tim lapangan'),
('band','Daftar lagu'),('band','Kebutuhan sound & panggung'),('band','Durasi tampil'),('mc','Rundown & naskah'),('mc','Bahasa/gaya MC');
insert into app_releases(version,notes) values('1.0.0','Rilis awal: multi-vendor, peran owner/staff/guest, masa aktif akun, CRM, invoice, template WA, branding.');
