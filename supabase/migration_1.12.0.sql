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
