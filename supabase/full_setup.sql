-- ============================================================
-- VENDOR CRM — INSTALASI LENGKAP (v1.7.1), untuk project Supabase BARU/KOSONG
-- Jalankan SEKALI di Supabase > SQL Editor (tempel seluruh isi file ini, klik Run)
-- Setelah sukses, jalankan 01_create_admin.sql
-- ============================================================

-- ---------- schema.sql ----------
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

-- ---------- migration_1.1.0.sql ----------
-- v1.1.0 — jalankan SETELAH schema.sql (aman dijalankan sekali)
alter table payments add column if not exists proof_path text;
alter table category_matrix add column if not exists id uuid default gen_random_uuid();
alter table category_matrix add primary key (id);
alter table category_matrix add column if not exists created_at timestamptz default now();

-- Akses per modul: permissions.modules = {"invoices":"none|r|w"}; kosong = default peran
create or replace function mod_lvl(t text) returns text language sql stable security definer set search_path=public as $$
 select case when role='owner' then 'w' else coalesce(permissions->'modules'->>t,
  case when role='staff' and coalesce(permissions->>'write','true')<>'false' then 'w' else 'r' end) end
 from profiles where id=auth.uid() and active $$;
do $$ declare t text; v text:='is_admin() or (vendor_id=my_vendor() and vendor_ok() and '; begin
foreach t in array array['clients','bookings','events','meetings','invoices','payments','partnerships','deliverables','requirements','wa_templates'] loop
 execute format('drop policy if exists s on %I',t);execute format('drop policy if exists i on %I',t);
 execute format('drop policy if exists u on %I',t);execute format('drop policy if exists d on %I',t);
 execute format('create policy s on %I for select using ('||v||'mod_lvl(%L)<>''none''))',t,t);
 execute format('create policy i on %I for insert with check ('||v||'mod_lvl(%L)=''w''))',t,t);
 execute format('create policy u on %I for update using ('||v||'mod_lvl(%L)=''w''))',t,t);
 execute format('create policy d on %I for delete using ('||v||'mod_lvl(%L)=''w'' and my_role()=''owner''))',t,t);
end loop; end $$;

-- Bukti pembayaran: bucket privat, maks 2 MB
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('proofs','proofs',false,2097152,array['image/jpeg','image/png','application/pdf']) on conflict do nothing;
create policy proof_ins on storage.objects for insert to authenticated with check (bucket_id='proofs' and (is_admin() or ((storage.foldername(name))[1]=my_vendor()::text and vendor_ok() and mod_lvl('payments')='w')));
create policy proof_sel on storage.objects for select to authenticated using (bucket_id='proofs' and (is_admin() or ((storage.foldername(name))[1]=my_vendor()::text and vendor_ok())));
insert into app_releases(version,notes) values('1.1.0','Kalender visual, laporan + grafik, ekspor Excel(CSV)/PDF, upload bukti bayar, editor matriks kategori, akses per modul.');

-- ---------- migration_1.2.0.sql ----------
-- v1.2.0 — jalankan SETELAH migration_1.1.0.sql
alter table clients add column if not exists portal_token text;
create unique index if not exists clients_portal_token on clients(portal_token) where portal_token is not null;
alter table partnerships add column if not exists sign_token text, add column if not exists signed_name text, add column if not exists signed_at timestamptz, add column if not exists signature text;
create unique index if not exists partnerships_sign_token on partnerships(sign_token) where sign_token is not null;

create table reminder_log(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,ref_id uuid,kind text,sent_at timestamptz default now());
alter table reminder_log enable row level security;
create policy s on reminder_log for select using (is_admin() or (vendor_id=my_vendor() and vendor_ok()));
create policy i on reminder_log for insert with check (is_admin() or (vendor_id=my_vendor() and vendor_ok() and my_role() in('owner','staff')));

-- Ubah isi perjanjian setelah ditandatangani = tanda tangan dihapus (harus tanda tangan ulang)
create function reset_sign() returns trigger language plpgsql as $$
begin if old.signed_at is not null and (new.terms is distinct from old.terms or new.partner_name is distinct from old.partner_name) then new.signed_at=null;new.signed_name=null;new.signature=null; end if; return new; end $$;
create trigger t_rs before update on partnerships for each row execute function reset_sign();

-- Halaman publik (tanpa login) hanya lewat token acak + vendor aktif
create function get_agreement(p_token text) returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('vendor',coalesce(v.app_name,v.name),'partner',p.partner_name,'type',p.type,'terms',p.terms,'signed_at',p.signed_at,'signed_name',p.signed_name)
 from partnerships p join vendors v on v.id=p.vendor_id
 where p_token is not null and p.sign_token=p_token and v.status='active' and (v.expires_at is null or v.expires_at>=current_date) $$;
create function sign_agreement(p_token text,p_name text,p_sig text) returns boolean language plpgsql security definer set search_path=public as $$
begin
 if coalesce(trim(p_name),'')='' or p_sig is null or length(p_sig)>400000 or left(p_sig,22)<>'data:image/png;base64,' then return false; end if;
 update partnerships p set signed_name=left(trim(p_name),120),signed_at=now(),signature=p_sig
  where p.sign_token=p_token and p_token is not null and p.signed_at is null
  and exists(select 1 from vendors v where v.id=p.vendor_id and v.status='active' and (v.expires_at is null or v.expires_at>=current_date));
 return found; end $$;
create function portal_data(p_token text) returns jsonb language plpgsql stable security definer set search_path=public as $$
declare c clients; v vendors;
begin
 select * into c from clients where portal_token=p_token and p_token is not null; if not found then return null; end if;
 select * into v from vendors where id=c.vendor_id and status='active' and (expires_at is null or expires_at>=current_date); if not found then return null; end if;
 return jsonb_build_object('vendor',jsonb_build_object('name',coalesce(v.app_name,v.name),'logo',v.logo_url,'wa',v.wa_phone),'client',c.name,
 'bookings',(select coalesce(jsonb_agg(jsonb_build_object('package',package,'date',event_date,'total',total,'status',status) order by event_date),'[]') from bookings where client_id=c.id),
 'invoices',(select coalesce(jsonb_agg(jsonb_build_object('number',i.number,'type',i.type,'amount',i.amount,'due',i.due_date,'status',i.status,'paid',(select coalesce(sum(amount),0) from payments where invoice_id=i.id)) order by i.due_date),'[]') from invoices i where i.client_id=c.id),
 'events',(select coalesce(jsonb_agg(jsonb_build_object('title',title,'date',event_date,'venue',venue) order by event_date),'[]') from events where client_id=c.id),
 'meetings',(select coalesce(jsonb_agg(jsonb_build_object('at',meet_at,'place',place,'status',status) order by meet_at),'[]') from meetings where client_id=c.id),
 'deliverables',(select coalesce(jsonb_agg(jsonb_build_object('title',d.title,'due',d.due_date,'status',d.status,'link',d.link)),'[]') from deliverables d join bookings b on b.id=d.booking_id where b.client_id=c.id));
end $$;
grant execute on function get_agreement(text),sign_agreement(text,text,text),portal_data(text) to anon,authenticated;
insert into app_releases(version,notes) values('1.2.0','Pengingat client (antrean WA), tanda tangan digital kerjasama, portal client.');

-- ---------- migration_1.3.0.sql ----------
-- v1.3.0 — jalankan SETELAH migration_1.2.0.sql
alter table vendors add column if not exists cal_token text;
create unique index if not exists vendors_cal_token on vendors(cal_token) where cal_token is not null;
create function set_cal_token(p_vendor uuid,p_token text) returns void language plpgsql security definer set search_path=public as $$
begin if is_admin() or (my_role() in('owner','staff') and my_vendor()=p_vendor and vendor_ok()) then update vendors set cal_token=p_token where id=p_vendor; else raise exception 'tidak berwenang'; end if; end $$;
insert into app_releases(version,notes) values('1.3.0','Sinkron Google Kalender lewat link langganan (iCal) otomatis.');

-- ---------- migration_1.4.0.sql ----------
-- v1.4.0 — jalankan SETELAH migration_1.3.0.sql
alter table vendors add column if not exists slug text, add column if not exists booking_cap int default 1, add column if not exists bank_info text, add column if not exists qris_url text;
create unique index if not exists vendors_slug on vendors(slug) where slug is not null;
alter table clients add column if not exists stage text default 'deal', add column if not exists source text, add column if not exists desired_date date;
alter table clients alter column stage set default 'inquiry';

create table packages(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),name text,description text,price numeric default 0,status text default 'aktif');
create table quotes(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),number text,client_id uuid references clients on delete set null,package_id uuid references packages on delete set null,title text,items text,total numeric default 0,valid_until date,status text default 'draft',booking_id uuid references bookings on delete set null);
create table expenses(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),booking_id uuid references bookings on delete set null,category text,description text,amount numeric default 0,paid_at date default current_date,payee text);
create table blocked_dates(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),blocked_on date not null,reason text);
do $$ declare t text; v text:='is_admin() or (vendor_id=my_vendor() and vendor_ok() and '; begin
foreach t in array array['packages','quotes','expenses','blocked_dates'] loop
 execute format('alter table %I enable row level security',t);
 execute format('create policy s on %I for select using ('||v||'mod_lvl(%L)<>''none''))',t,t);
 execute format('create policy i on %I for insert with check ('||v||'mod_lvl(%L)=''w''))',t,t);
 execute format('create policy u on %I for update using ('||v||'mod_lvl(%L)=''w''))',t,t);
 execute format('create policy d on %I for delete using ('||v||'mod_lvl(%L)=''w'' and my_role()=''owner''))',t,t);
end loop; end $$;

-- Tagihan langganan vendor (admin menulis; owner vendor hanya melihat tagihannya)
create table vendor_bills(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),plan text,amount numeric default 0,period_start date,period_end date,status text default 'unpaid',paid_at date,note text);
alter table vendor_bills enable row level security;
create policy s on vendor_bills for select using (is_admin() or (vendor_id=my_vendor() and my_role()='owner'));
create policy w on vendor_bills for all using (is_admin()) with check (is_admin());

create function set_vendor_settings(p_vendor uuid,p_cap int,p_slug text,p_bank text,p_qris text) returns void language plpgsql security definer set search_path=public as $$
begin if is_admin() or (my_role()='owner' and my_vendor()=p_vendor) then update vendors set booking_cap=greatest(coalesce(p_cap,1),1),slug=p_slug,bank_info=p_bank,qris_url=p_qris where id=p_vendor; else raise exception 'tidak berwenang'; end if; end $$;

-- Form booking publik (tanpa login, via alamat/slug vendor)
create function get_vendor_public(p_slug text) returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('name',coalesce(v.app_name,v.name),'logo',v.logo_url,'packages',(select coalesce(jsonb_agg(jsonb_build_object('name',k.name,'price',k.price)),'[]') from packages k where k.vendor_id=v.id and k.status='aktif'))
 from vendors v where p_slug is not null and v.slug=p_slug and v.status='active' and (v.expires_at is null or v.expires_at>=current_date) $$;
create function check_date(p_slug text,p_date date) returns boolean language sql stable security definer set search_path=public as $$
 select not exists(select 1 from blocked_dates b where b.vendor_id=v.id and b.blocked_on=p_date)
  and (select count(*) from bookings k where k.vendor_id=v.id and k.event_date=p_date and k.status<>'cancelled')<coalesce(v.booking_cap,1)
 from vendors v where p_slug is not null and v.slug=p_slug and v.status='active' and (v.expires_at is null or v.expires_at>=current_date) $$;
create function submit_inquiry(p_slug text,p_name text,p_phone text,p_email text,p_date date,p_package text,p_notes text) returns jsonb language plpgsql security definer set search_path=public as $$
declare v vendors; ok boolean;
begin
 select * into v from vendors where p_slug is not null and slug=p_slug and status='active' and (expires_at is null or expires_at>=current_date);
 if not found or coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then return jsonb_build_object('ok',false); end if;
 if (select count(*) from clients where vendor_id=v.id and source='Form online' and created_at>now()-interval '1 hour')>=20 then return jsonb_build_object('ok',false,'limit',true); end if;
 ok:=coalesce(check_date(p_slug,p_date),true);
 insert into clients(vendor_id,name,phone,email,stage,source,desired_date,notes)
 values(v.id,left(trim(p_name),120),left(trim(p_phone),30),left(p_email,120),'inquiry','Form online',p_date,
  left(coalesce('Paket: '||p_package||E'\n','')||coalesce(p_notes,'')||case when ok then '' else E'\n⚠ Tanggal bentrok/penuh' end,1000));
 return jsonb_build_object('ok',true,'available',ok);
end $$;
grant execute on function get_vendor_public(text),check_date(text,date),submit_inquiry(text,text,text,text,date,text,text) to anon,authenticated;
insert into app_releases(version,notes) values('1.4.0','Form booking publik, pipeline lead, cegah bentrok jadwal, paket & penawaran, invoice PDF, pengeluaran & laba rugi, tagihan langganan vendor.');

-- ---------- migration_1.5.0.sql ----------
-- v1.5.0 — jalankan SETELAH migration_1.4.0.sql
create table audit_log(id bigint generated always as identity primary key,created_at timestamptz default now(),vendor_id uuid,user_id uuid,user_name text,table_name text,row_id text,action text,old_data jsonb,new_data jsonb);
create index audit_log_v on audit_log(vendor_id,created_at desc);
alter table audit_log enable row level security;
create policy s on audit_log for select using (is_admin() or (vendor_id=my_vendor() and my_role()='owner'));
-- Sengaja TIDAK ada policy insert/update/delete: log tidak bisa diubah/dihapus lewat aplikasi/API.

create function audit_fn() returns trigger language plpgsql security definer set search_path=public as $$
declare s text[]:=array['signature','sign_token','portal_token','cal_token'];ofull jsonb;nfull jsonb;od jsonb;nd jsonb;f jsonb;vid uuid;un text;
begin
 if tg_op<>'INSERT' then ofull:=to_jsonb(old)-s; od:=ofull; end if;
 if tg_op<>'DELETE' then nfull:=to_jsonb(new)-s; nd:=nfull; end if;
 if tg_op='UPDATE' then
  select coalesce(jsonb_object_agg(e.key,e.value),'{}') into od from jsonb_each(ofull) e where nfull->e.key is distinct from e.value;
  select coalesce(jsonb_object_agg(e.key,e.value),'{}') into nd from jsonb_each(nfull) e where ofull->e.key is distinct from e.value;
  if nd='{}'::jsonb then return new; end if;
 end if;
 f:=coalesce(nfull,ofull);
 vid:=coalesce((f->>'vendor_id')::uuid,case when tg_table_name='vendors' then (f->>'id')::uuid end);
 select coalesce(full_name,'(tanpa nama)')||' ('||role||')' into un from profiles where id=auth.uid();
 un:=coalesce(un,case when auth.uid() is null then 'sistem/publik' else 'pengguna' end);
 insert into audit_log(vendor_id,user_id,user_name,table_name,row_id,action,old_data,new_data) values(vid,auth.uid(),un,tg_table_name,f->>'id',tg_op,od,nd);
 return coalesce(new,old);
end $$;
do $$ declare t text; begin
foreach t in array array['vendors','profiles','clients','bookings','events','meetings','invoices','payments','partnerships','deliverables','requirements','wa_templates','packages','quotes','expenses','blocked_dates','vendor_bills'] loop
 execute format('create trigger t_audit after insert or update or delete on %I for each row execute function audit_fn()',t);
end loop; end $$;

create function log_export(p_vendor uuid) returns void language plpgsql security definer set search_path=public as $$
begin if is_admin() or (my_role()='owner' and my_vendor()=p_vendor) then
 insert into audit_log(vendor_id,user_id,user_name,table_name,action) select p_vendor,auth.uid(),coalesce(full_name,'?')||' ('||role||')','(semua)','export' from profiles where id=auth.uid();
else raise exception 'tidak berwenang'; end if; end $$;
insert into app_releases(version,notes) values('1.5.0','Audit log, PWA (pasang di HP, cache offline baca-saja), backup data JSON.');

-- ---------- migration_1.6.0.sql ----------
-- v1.6.0 — jalankan SETELAH migration_1.5.0.sql
alter table invoices add column if not exists subtotal numeric, add column if not exists discount numeric default 0, add column if not exists extra numeric default 0, add column if not exists tax_pct numeric default 0;
alter table quotes add column if not exists subtotal numeric, add column if not exists discount numeric default 0, add column if not exists extra numeric default 0, add column if not exists tax_pct numeric default 0;
create table assignments(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),booking_id uuid references bookings on delete cascade,crew_name text,phone text,role text,fee numeric default 0,status text default 'ditugaskan',note text);
create table reviews(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),booking_id uuid references bookings on delete set null,client_id uuid references clients on delete set null,token text,rating int check(rating between 1 and 5),comment text,status text default 'menunggu',public_show text default 'ya',submitted_at timestamptz);
create unique index reviews_token on reviews(token) where token is not null;
do $$ declare t text; v text:='is_admin() or (vendor_id=my_vendor() and vendor_ok() and '; begin
foreach t in array array['assignments','reviews'] loop
 execute format('alter table %I enable row level security',t);
 execute format('create policy s on %I for select using ('||v||'mod_lvl(%L)<>''none''))',t,t);
 execute format('create policy i on %I for insert with check ('||v||'mod_lvl(%L)=''w''))',t,t);
 execute format('create policy u on %I for update using ('||v||'mod_lvl(%L)=''w''))',t,t);
 execute format('create policy d on %I for delete using ('||v||'mod_lvl(%L)=''w'' and my_role()=''owner''))',t,t);
 execute format('create trigger t_audit after insert or update or delete on %I for each row execute function audit_fn()',t);
end loop; end $$;

-- Ulasan: halaman publik via token
create function get_review(p_token text) returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('vendor',coalesce(v.app_name,v.name),'logo',v.logo_url,'package',b.package,'status',r.status)
 from reviews r join vendors v on v.id=r.vendor_id left join bookings b on b.id=r.booking_id
 where p_token is not null and r.token=p_token and v.status='active' and (v.expires_at is null or v.expires_at>=current_date) $$;
create function submit_review(p_token text,p_rating int,p_comment text) returns boolean language plpgsql security definer set search_path=public as $$
begin
 if p_rating is null or p_rating not between 1 and 5 then return false; end if;
 update reviews r set rating=p_rating,comment=left(p_comment,1000),status='terisi',submitted_at=now()
  where r.token=p_token and p_token is not null and r.status='menunggu'
  and exists(select 1 from vendors v where v.id=r.vendor_id and v.status='active' and (v.expires_at is null or v.expires_at>=current_date));
 return found; end $$;
create or replace function get_vendor_public(p_slug text) returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('name',coalesce(v.app_name,v.name),'logo',v.logo_url,
  'packages',(select coalesce(jsonb_agg(jsonb_build_object('name',k.name,'price',k.price)),'[]') from packages k where k.vendor_id=v.id and k.status='aktif'),
  'reviews',(select coalesce(jsonb_agg(jsonb_build_object('rating',x.rating,'comment',x.comment)),'[]') from (select rating,comment from reviews where vendor_id=v.id and status='terisi' and public_show='ya' and rating>=4 and coalesce(comment,'')<>'' order by submitted_at desc limit 5) x))
 from vendors v where p_slug is not null and v.slug=p_slug and v.status='active' and (v.expires_at is null or v.expires_at>=current_date) $$;
grant execute on function get_review(text),submit_review(text,int,text),get_vendor_public(text) to anon,authenticated;

insert into wa_defaults values('ulasan','Minta Ulasan','Halo Kak {{nama}}, terima kasih sudah mempercayakan acara {{tanggal}} kepada {{vendor}} 🙏 Boleh minta penilaian singkatnya di sini: {{link}}');
insert into wa_templates(vendor_id,key,title,body) select v.id,d.key,d.title,d.body from vendors v,wa_defaults d where d.key='ulasan' and not exists(select 1 from wa_templates w where w.vendor_id=v.id and w.key='ulasan');
insert into app_releases(version,notes) values('1.6.0','Impor CSV, dashboard platform, cicilan + diskon/pajak, tim & honor crew, ulasan client, pulihkan backup.');

-- ---------- migration_1.7.0.sql ----------
-- v1.7.0 — jalankan SETELAH migration_1.6.0.sql
-- Saat impor migrasi (app.import=1): trigger audit & seed template dilewati
create or replace function audit_fn() returns trigger language plpgsql security definer set search_path=public as $$
declare s text[]:=array['signature','sign_token','portal_token','cal_token'];ofull jsonb;nfull jsonb;od jsonb;nd jsonb;f jsonb;vid uuid;un text;
begin
 if current_setting('app.import',true)='1' then return coalesce(new,old); end if;
 if tg_op<>'INSERT' then ofull:=to_jsonb(old)-s; od:=ofull; end if;
 if tg_op<>'DELETE' then nfull:=to_jsonb(new)-s; nd:=nfull; end if;
 if tg_op='UPDATE' then
  select coalesce(jsonb_object_agg(e.key,e.value),'{}') into od from jsonb_each(ofull) e where nfull->e.key is distinct from e.value;
  select coalesce(jsonb_object_agg(e.key,e.value),'{}') into nd from jsonb_each(nfull) e where ofull->e.key is distinct from e.value;
  if nd='{}'::jsonb then return new; end if;
 end if;
 f:=coalesce(nfull,ofull);
 vid:=coalesce((f->>'vendor_id')::uuid,case when tg_table_name='vendors' then (f->>'id')::uuid end);
 select coalesce(full_name,'(tanpa nama)')||' ('||role||')' into un from profiles where id=auth.uid();
 un:=coalesce(un,case when auth.uid() is null then 'sistem/publik' else 'pengguna' end);
 insert into audit_log(vendor_id,user_id,user_name,table_name,row_id,action,old_data,new_data) values(vid,auth.uid(),un,tg_table_name,f->>'id',tg_op,od,nd);
 return coalesce(new,old);
end $$;
create or replace function seed_vendor() returns trigger language plpgsql security definer set search_path=public as $$
begin if current_setting('app.import',true)='1' then return new; end if;
 insert into wa_templates(vendor_id,key,title,body) select new.id,key,title,body from wa_defaults; return new; end $$;

create function import_bulk(p_table text,p_rows jsonb,p_first boolean default false) returns int language plpgsql security definer set search_path=public as $$
declare n int;
begin
 if not is_admin() then raise exception 'hanya admin'; end if;
 if p_table<>all(array['vendors','profiles','clients','packages','bookings','events','meetings','invoices','payments','partnerships','deliverables','requirements','wa_templates','quotes','expenses','blocked_dates','assignments','reviews','vendor_bills','reminder_log','category_matrix','wa_defaults','app_releases','audit_log']) then raise exception 'tabel tidak diizinkan'; end if;
 perform set_config('app.import','1',true);
 if p_first and p_table in('category_matrix','wa_defaults','app_releases') then execute format('delete from %I',p_table); end if;
 if p_table='audit_log' then
  insert into audit_log(created_at,vendor_id,user_id,user_name,table_name,row_id,action,old_data,new_data)
  select created_at,vendor_id,user_id,user_name,table_name,row_id,action,old_data,new_data from jsonb_populate_recordset(null::audit_log,p_rows);
 else execute format('insert into %1$I select * from jsonb_populate_recordset(null::%1$I,$1) on conflict do nothing',p_table) using p_rows; end if;
 get diagnostics n=row_count; return n;
end $$;
insert into app_releases(version,notes) values('1.7.0','Migrasi penuh antar Supabase (ekspor/impor ZIP), ubah password.');

insert into app_releases(version,notes) values('1.7.1','Skrip instalasi tunggal full_setup.sql + konfigurasi Supabase.');
-- v1.8.0 — jalankan SETELAH full_setup.sql (atau migration_1.7.0.sql)
alter table invoices add column if not exists issue_date date;
update invoices set issue_date=created_at::date where issue_date is null;
alter table invoices alter column issue_date set default current_date;
insert into app_releases(version,notes) values('1.8.0','Pencarian client (ketik+dropdown), sumber lead & paket pilih/ketik, nomor INV/KW otomatis, tanggal terbit invoice, urut kolom di semua tabel.');
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
insert into app_releases(version,notes) values('1.10.0','Tooltip bantuan di semua menu/tombol/isian + halaman Cara Pakai dengan checklist dan link langsung.');
insert into app_releases(version,notes) values('1.11.0','Keterkaitan data: kolom Keterkaitan, Ringkasan Client & Booking, rincian Invoice, link antar data.');
-- v1.12.0 — jalankan SETELAH migration_1.11.0.sql
alter table invoices add column if not exists pct numeric, add column if not exists tax_incl boolean default false;
alter table quotes add column if not exists tax_incl boolean default false;
alter table expenses add column if not exists assignment_id uuid;
create table crew(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,created_at timestamptz default now(),name text not null,phone text,roles jsonb default '[]'::jsonb,status text default 'aktif',notes text);
alter table assignments add column if not exists crew_id uuid references crew on delete set null;
do $$ declare t text; v text:='is_admin() or (vendor_id=my_vendor() and vendor_ok() and '; begin
 t:='crew';
 execute format('alter table %I enable row level security',t);
 execute format('create policy s on %I for select using ('||v||'mod_lvl(%L)<>''none''))',t,t);
 execute format('create policy i on %I for insert with check ('||v||'mod_lvl(%L)=''w''))',t,t);
 execute format('create policy u on %I for update using ('||v||'mod_lvl(%L)=''w''))',t,t);
 execute format('create policy d on %I for delete using ('||v||'mod_lvl(%L)=''w'' and my_role()=''owner''))',t,t);
 execute format('create trigger t_audit after insert or update or delete on %I for each row execute function audit_fn()',t);
end $$;

-- Status invoice otomatis dari pembayaran: paid / partial / unpaid
create function inv_status(p_inv uuid) returns void language plpgsql security definer set search_path=public as $$
declare a numeric; s numeric; st text;
begin select amount into a from invoices where id=p_inv; if not found then return; end if;
 select coalesce(sum(amount),0) into s from payments where invoice_id=p_inv;
 st:=case when a>0 and s>=a then 'paid' when s>0 then 'partial' else 'unpaid' end;
 update invoices set status=st where id=p_inv and status is distinct from st; end $$;
create function trg_pay_status() returns trigger language plpgsql security definer set search_path=public as $$
begin if tg_op<>'INSERT' and old.invoice_id is not null then perform inv_status(old.invoice_id); end if;
 if tg_op<>'DELETE' and new.invoice_id is not null then perform inv_status(new.invoice_id); end if; return null; end $$;
create trigger t_pay_status after insert or update or delete on payments for each row execute function trg_pay_status();
create function trg_inv_amt() returns trigger language plpgsql security definer set search_path=public as $$
declare s numeric;
begin select coalesce(sum(amount),0) into s from payments where invoice_id=new.id;
 new.status:=case when new.amount>0 and s>=new.amount then 'paid' when s>0 then 'partial' else 'unpaid' end; return new; end $$;
create trigger t_inv_amt before update of amount on invoices for each row when (old.amount is distinct from new.amount) execute function trg_inv_amt();
select inv_status(id) from invoices;

-- Migrasi nama crew lama ke Daftar Crew
insert into crew(vendor_id,name,phone,roles)
select vendor_id,min(crew_name),max(phone),coalesce(jsonb_agg(distinct role) filter (where role is not null and role<>''),'[]'::jsonb)
from assignments where crew_name is not null and crew_id is null group by vendor_id,lower(crew_name);
update assignments a set crew_id=c.id from crew c where a.crew_id is null and c.vendor_id=a.vendor_id and lower(c.name)=lower(a.crew_name);

create or replace function import_bulk(p_table text,p_rows jsonb,p_first boolean default false) returns int language plpgsql security definer set search_path=public as $$
declare n int;
begin
 if not is_admin() then raise exception 'hanya admin'; end if;
 if p_table<>all(array['vendors','profiles','clients','packages','bookings','events','meetings','invoices','payments','partnerships','deliverables','requirements','wa_templates','quotes','expenses','blocked_dates','crew','assignments','reviews','followups','targets','vendor_bills','reminder_log','category_matrix','wa_defaults','app_releases','audit_log']) then raise exception 'tabel tidak diizinkan'; end if;
 perform set_config('app.import','1',true);
 if p_first and p_table in('category_matrix','wa_defaults','app_releases') then execute format('delete from %I',p_table); end if;
 if p_table='audit_log' then
  insert into audit_log(created_at,vendor_id,user_id,user_name,table_name,row_id,action,old_data,new_data)
  select created_at,vendor_id,user_id,user_name,table_name,row_id,action,old_data,new_data from jsonb_populate_recordset(null::audit_log,p_rows);
 else execute format('insert into %1$I select * from jsonb_populate_recordset(null::%1$I,$1) on conflict do nothing',p_table) using p_rows; end if;
 get diagnostics n=row_count; return n;
end $$;
insert into app_releases(version,notes) values('1.12.0','Invoice terhitung otomatis (DP %, pelunasan, pajak termasuk/tambah), status bayar otomatis, daftar crew + laporan crew, analitik client per periode/status, urut/kelompok client menurut keterkaitan.');
-- v1.13.0 — jalankan SETELAH migration_1.12.0.sql
alter table vendors add column if not exists address text, add column if not exists email text, add column if not exists website text, add column if not exists npwp text, add column if not exists signer_name text, add column if not exists signer_title text;
create function set_vendor_profile(p_vendor uuid,p_address text,p_email text,p_website text,p_npwp text,p_signer text,p_signer_title text) returns void language plpgsql security definer set search_path=public as $$
begin if is_admin() or (my_role()='owner' and my_vendor()=p_vendor) then
 update vendors set address=p_address,email=p_email,website=p_website,npwp=p_npwp,signer_name=p_signer,signer_title=p_signer_title where id=p_vendor;
else raise exception 'tidak berwenang'; end if; end $$;
insert into app_releases(version,notes) values('1.13.0','Tampilan form & tabel profesional; dokumen cetak (invoice, penawaran, kwitansi, perjanjian, laporan) dengan kop surat/logo; profil vendor (alamat, email, NPWP, penanda tangan); Matriks Kebutuhan: pencarian booking, pengelompokan.');
-- v1.14.0 — jalankan SETELAH migration_1.13.0.sql
alter table vendors add column if not exists theme_color text;
create function set_vendor_theme(p_vendor uuid,p_color text) returns void language plpgsql security definer set search_path=public as $$
begin
 if p_color is not null and p_color !~* '^#[0-9a-f]{6}$' then raise exception 'format warna tidak valid'; end if;
 if is_admin() or (my_role()='owner' and my_vendor()=p_vendor) then update vendors set theme_color=p_color where id=p_vendor;
 else raise exception 'tidak berwenang'; end if; end $$;
insert into app_releases(version,notes) values('1.14.0','Warna tema bisa diatur per vendor (aplikasi dan dokumen cetak); tooltip Analitik Client menjelaskan arti tiap status.');
