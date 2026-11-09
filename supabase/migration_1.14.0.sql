-- v1.14.0 — jalankan SETELAH migration_1.13.0.sql
alter table vendors add column if not exists theme_color text;
create function set_vendor_theme(p_vendor uuid,p_color text) returns void language plpgsql security definer set search_path=public as $$
begin
 if p_color is not null and p_color !~* '^#[0-9a-f]{6}$' then raise exception 'format warna tidak valid'; end if;
 if is_admin() or (my_role()='owner' and my_vendor()=p_vendor) then update vendors set theme_color=p_color where id=p_vendor;
 else raise exception 'tidak berwenang'; end if; end $$;
insert into app_releases(version,notes) values('1.14.0','Warna tema bisa diatur per vendor (aplikasi dan dokumen cetak); tooltip Analitik Client menjelaskan arti tiap status.');
