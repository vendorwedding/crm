-- v1.8.0 — jalankan SETELAH full_setup.sql (atau migration_1.7.0.sql)
alter table invoices add column if not exists issue_date date;
update invoices set issue_date=created_at::date where issue_date is null;
alter table invoices alter column issue_date set default current_date;
insert into app_releases(version,notes) values('1.8.0','Pencarian client (ketik+dropdown), sumber lead & paket pilih/ketik, nomor INV/KW otomatis, tanggal terbit invoice, urut kolom di semua tabel.');
