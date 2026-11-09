-- v1.5.0 — jalankan SETELAH migration_1.4.0.sql
create table audit_log(id bigint generated always as identity primary key,created_at timestamptz default now(),vendor_id uuid,user_id uuid,user_name text,table_name text,row_id text,action text,old_data jsonb,new_data jsonb);
create index audit_log_v on audit_log(vendor_id,created_at desc);
alter table audit_log enable row level security;
create policy s on audit_log for select using (is_admin() or (vendor_id=my_vendor() and my_role()='owner'));
-- Sengaja TIDAK ada policy insert/update/delete: log tidak bisa diubah/dihapus lewat aplikasi/API.

create function audit_fn() returns trigger language plpgsql security definer set search_path=public as $$
declare s text[]:=array['signature','sign_token','portal_token','cal_token'];of jsonb;nf jsonb;od jsonb;nd jsonb;f jsonb;vid uuid;un text;
begin
 if tg_op<>'INSERT' then of:=to_jsonb(old)-s; od:=of; end if;
 if tg_op<>'DELETE' then nf:=to_jsonb(new)-s; nd:=nf; end if;
 if tg_op='UPDATE' then
  select coalesce(jsonb_object_agg(e.key,e.value),'{}') into od from jsonb_each(of) e where nf->e.key is distinct from e.value;
  select coalesce(jsonb_object_agg(e.key,e.value),'{}') into nd from jsonb_each(nf) e where of->e.key is distinct from e.value;
  if nd='{}'::jsonb then return new; end if;
 end if;
 f:=coalesce(nf,of);
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
