-- v1.2.0 — jalankan SETELAH migration_1.1.0.sql
alter table clients add column if not exists portal_token text;
create unique index if not exists clients_portal_token on clients(portal_token) where portal_token is not null;
alter table partnerships add column if not exists sign_token text, add column if not exists signed_name text, add column if not exists signed_at timestamptz, add column if not exists signature text;
create unique index if not exists partnerships_sign_token on partnerships(sign_token) where sign_token is not null;

create table reminder_log(id uuid primary key default gen_random_uuid(),vendor_id uuid not null references vendors on delete cascade,ref_id uuid,kind text,sent_at timestamptz default now());
alter table reminder_log enable row level security;
create policy s on reminder_log for select using (is_admin() or (vendor_id=my_vendor() and vendor_ok()));
create policy i on reminder_log for insert with check (is_admin() or (vendor_id=my_vendor() and vendor_ok() and my_role() in('owner','staff')));

-- Ubah isi perjanjian setelah ditandatangani = tanda tangan dihapus (harus tanda tangan ulang)
create function reset_sign() returns trigger language plpgsql as $$
begin if old.signed_at is not null and (new.terms is distinct from old.terms or new.partner_name is distinct from old.partner_name) then new.signed_at=null;new.signed_name=null;new.signature=null; end if; return new; end $$;
create trigger t_rs before update on partnerships for each row execute function reset_sign();

-- Halaman publik (tanpa login) hanya lewat token acak + vendor aktif
create function get_agreement(p_token text) returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('vendor',coalesce(v.app_name,v.name),'partner',p.partner_name,'type',p.type,'terms',p.terms,'signed_at',p.signed_at,'signed_name',p.signed_name)
 from partnerships p join vendors v on v.id=p.vendor_id
 where p_token is not null and p.sign_token=p_token and v.status='active' and (v.expires_at is null or v.expires_at>=current_date) $$;
create function sign_agreement(p_token text,p_name text,p_sig text) returns boolean language plpgsql security definer set search_path=public as $$
begin
 if coalesce(trim(p_name),'')='' or p_sig is null or length(p_sig)>400000 or left(p_sig,22)<>'data:image/png;base64,' then return false; end if;
 update partnerships p set signed_name=left(trim(p_name),120),signed_at=now(),signature=p_sig
  where p.sign_token=p_token and p_token is not null and p.signed_at is null
  and exists(select 1 from vendors v where v.id=p.vendor_id and v.status='active' and (v.expires_at is null or v.expires_at>=current_date));
 return found; end $$;
create function portal_data(p_token text) returns jsonb language plpgsql stable security definer set search_path=public as $$
declare c clients; v vendors;
begin
 select * into c from clients where portal_token=p_token and p_token is not null; if not found then return null; end if;
 select * into v from vendors where id=c.vendor_id and status='active' and (expires_at is null or expires_at>=current_date); if not found then return null; end if;
 return jsonb_build_object('vendor',jsonb_build_object('name',coalesce(v.app_name,v.name),'logo',v.logo_url,'wa',v.wa_phone),'client',c.name,
 'bookings',(select coalesce(jsonb_agg(jsonb_build_object('package',package,'date',event_date,'total',total,'status',status) order by event_date),'[]') from bookings where client_id=c.id),
 'invoices',(select coalesce(jsonb_agg(jsonb_build_object('number',i.number,'type',i.type,'amount',i.amount,'due',i.due_date,'status',i.status,'paid',(select coalesce(sum(amount),0) from payments where invoice_id=i.id)) order by i.due_date),'[]') from invoices i where i.client_id=c.id),
 'events',(select coalesce(jsonb_agg(jsonb_build_object('title',title,'date',event_date,'venue',venue) order by event_date),'[]') from events where client_id=c.id),
 'meetings',(select coalesce(jsonb_agg(jsonb_build_object('at',meet_at,'place',place,'status',status) order by meet_at),'[]') from meetings where client_id=c.id),
 'deliverables',(select coalesce(jsonb_agg(jsonb_build_object('title',d.title,'due',d.due_date,'status',d.status,'link',d.link)),'[]') from deliverables d join bookings b on b.id=d.booking_id where b.client_id=c.id));
end $$;
grant execute on function get_agreement(text),sign_agreement(text,text,text),portal_data(text) to anon,authenticated;
insert into app_releases(version,notes) values('1.2.0','Pengingat client (antrean WA), tanda tangan digital kerjasama, portal client.');
