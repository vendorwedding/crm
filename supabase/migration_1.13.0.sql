-- v1.13.0 — jalankan SETELAH migration_1.12.0.sql
alter table vendors add column if not exists address text, add column if not exists email text, add column if not exists website text, add column if not exists npwp text, add column if not exists signer_name text, add column if not exists signer_title text;
create function set_vendor_profile(p_vendor uuid,p_address text,p_email text,p_website text,p_npwp text,p_signer text,p_signer_title text) returns void language plpgsql security definer set search_path=public as $$
begin if is_admin() or (my_role()='owner' and my_vendor()=p_vendor) then
 update vendors set address=p_address,email=p_email,website=p_website,npwp=p_npwp,signer_name=p_signer,signer_title=p_signer_title where id=p_vendor;
else raise exception 'tidak berwenang'; end if; end $$;
insert into app_releases(version,notes) values('1.13.0','Tampilan form & tabel profesional; dokumen cetak (invoice, penawaran, kwitansi, perjanjian, laporan) dengan kop surat/logo; profil vendor (alamat, email, NPWP, penanda tangan); Matriks Kebutuhan: pencarian booking, pengelompokan.');
