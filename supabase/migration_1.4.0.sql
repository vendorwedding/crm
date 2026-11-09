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
