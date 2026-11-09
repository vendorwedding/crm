-- Jalankan SETELAH full_setup.sql dan SETELAH membuat user di Authentication > Users > Add user (centang Auto Confirm User).
-- GANTI email di bawah dengan email admin yang baru Anda buat.
insert into profiles(id,role,full_name)
select id,'admin','Admin' from auth.users where email='GANTI_DENGAN_EMAIL_ADMIN'
on conflict (id) do update set role='admin',active=true;
