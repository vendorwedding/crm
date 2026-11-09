-- v1.7.0 — jalankan SETELAH migration_1.6.0.sql
-- Saat impor migrasi (app.import=1): trigger audit & seed template dilewati
create or replace function audit_fn() returns trigger language plpgsql security definer set search_path=public as $$
declare s text[]:=array['signature','sign_token','portal_token','cal_token'];of jsonb;nf jsonb;od jsonb;nd jsonb;f jsonb;vid uuid;un text;
begin
 if current_setting('app.import',true)='1' then return coalesce(new,old); end if;
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
