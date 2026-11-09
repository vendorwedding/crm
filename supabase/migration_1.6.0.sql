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
