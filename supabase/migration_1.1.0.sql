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
