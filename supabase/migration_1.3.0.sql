-- v1.3.0 — jalankan SETELAH migration_1.2.0.sql
alter table vendors add column if not exists cal_token text;
create unique index if not exists vendors_cal_token on vendors(cal_token) where cal_token is not null;
create function set_cal_token(p_vendor uuid,p_token text) returns void language plpgsql security definer set search_path=public as $$
begin if is_admin() or (my_role() in('owner','staff') and my_vendor()=p_vendor and vendor_ok()) then update vendors set cal_token=p_token where id=p_vendor; else raise exception 'tidak berwenang'; end if; end $$;
insert into app_releases(version,notes) values('1.3.0','Sinkron Google Kalender lewat link langganan (iCal) otomatis.');
