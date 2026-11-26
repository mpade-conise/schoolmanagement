create table public.school_library_books (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 isbn text, title text not null check(length(trim(title)) between 1 and 240), author text not null default '' check(length(author)<=240),
 category text not null default 'general' check(length(category)<=80), publisher text, published_year int check(published_year between 1000 and 2200),
 description text, active boolean not null default true, created_by uuid not null references public.school_memberships(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(school_id,isbn)
);
create index school_library_books_school_title on public.school_library_books(school_id,title);
create table public.school_library_copies (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 book_id uuid not null references public.school_library_books(id) on delete cascade, accession_number text not null,
 condition text not null default 'good' check(condition in ('new','good','fair','damaged')),
 status text not null default 'available' check(status in ('available','issued','lost','damaged','withdrawn')),
 created_at timestamptz not null default now(), unique(school_id,accession_number)
);
create index school_library_copies_book_status on public.school_library_copies(book_id,status);
create table public.school_library_loans (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 copy_id uuid not null references public.school_library_copies(id), borrower_type text not null check(borrower_type in ('student','staff')),
 student_id uuid references public.students(id), borrower_membership_id uuid references public.school_memberships(id),
 issued_at timestamptz not null default now(), due_date date not null, returned_at timestamptz,
 issued_by uuid not null references public.school_memberships(id), returned_by uuid references public.school_memberships(id),
 notes text, check((borrower_type='student' and student_id is not null and borrower_membership_id is null) or (borrower_type='staff' and borrower_membership_id is not null and student_id is null)),
 check(returned_at is null or returned_at>=issued_at)
);
create unique index school_library_one_active_loan_per_copy on public.school_library_loans(copy_id) where returned_at is null;
create index school_library_loans_school_due on public.school_library_loans(school_id,due_date) where returned_at is null;
create index school_library_loans_student on public.school_library_loans(student_id,issued_at desc) where student_id is not null;
alter table public.school_library_books enable row level security; alter table public.school_library_books force row level security;
alter table public.school_library_copies enable row level security; alter table public.school_library_copies force row level security;
alter table public.school_library_loans enable row level security; alter table public.school_library_loans force row level security;
revoke all on public.school_library_books,public.school_library_copies,public.school_library_loans from public,anon;
grant select,insert,update,delete on public.school_library_books,public.school_library_copies,public.school_library_loans to authenticated;
create schema if not exists private; revoke all on schema private from public,anon; grant usage on schema private to authenticated;
create or replace function private.can_manage_school_library(p_school_id uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.school_memberships m where m.school_id=p_school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
$$;
revoke all on function private.can_manage_school_library(uuid) from public,anon; grant execute on function private.can_manage_school_library(uuid) to authenticated;
create policy library_books_manage on public.school_library_books for all to authenticated using(private.can_manage_school_library(school_id)) with check(private.can_manage_school_library(school_id) and exists(select 1 from public.school_memberships m where m.id=created_by and m.school_id=school_library_books.school_id and m.is_active));
create policy library_copies_manage on public.school_library_copies for all to authenticated using(private.can_manage_school_library(school_id)) with check(private.can_manage_school_library(school_id) and exists(select 1 from public.school_library_books b where b.id=book_id and b.school_id=school_library_copies.school_id));
create policy library_loans_manage on public.school_library_loans for all to authenticated using(private.can_manage_school_library(school_id)) with check(private.can_manage_school_library(school_id) and exists(select 1 from public.school_library_copies c where c.id=copy_id and c.school_id=school_library_loans.school_id) and exists(select 1 from public.school_memberships m where m.id=issued_by and m.school_id=school_library_loans.school_id and m.is_active) and (student_id is null or exists(select 1 from public.students s where s.id=student_id and s.school_id=school_library_loans.school_id)) and (borrower_membership_id is null or exists(select 1 from public.school_memberships m where m.id=borrower_membership_id and m.school_id=school_library_loans.school_id and m.is_active)));
create or replace function public.sync_school_library_copy_status() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if tg_op='INSERT' then update public.school_library_copies set status='issued' where id=new.copy_id and status='available'; if not found then raise exception 'Copy is not available for issue'; end if; return new;
 elsif tg_op='UPDATE' and old.returned_at is null and new.returned_at is not null then update public.school_library_copies set status=case when condition='damaged' then 'damaged' else 'available' end where id=new.copy_id and status='issued'; return new;
 elsif tg_op='DELETE' and old.returned_at is null then update public.school_library_copies set status='available' where id=old.copy_id and status='issued'; return old; end if; return new;
end $$;
revoke all on function public.sync_school_library_copy_status() from public,anon,authenticated;
create trigger school_library_copy_loan_status after insert or update of returned_at or delete on public.school_library_loans for each row execute function public.sync_school_library_copy_status();
create or replace function public.touch_school_library_book() returns trigger language plpgsql as $$ begin new.updated_at=now();return new;end $$;
revoke all on function public.touch_school_library_book() from public,anon,authenticated;
create trigger school_library_book_updated_at before update on public.school_library_books for each row execute function public.touch_school_library_book();

drop policy library_loans_manage on public.school_library_loans;
create policy library_loans_read on public.school_library_loans for select to authenticated using(private.can_manage_school_library(school_id));
create policy library_loans_insert on public.school_library_loans for insert to authenticated with check(private.can_manage_school_library(school_id) and exists(select 1 from public.school_library_copies c join public.school_library_books b on b.id=c.book_id where c.id=copy_id and c.school_id=school_library_loans.school_id and b.active and c.status='available') and exists(select 1 from public.school_memberships m where m.id=issued_by and m.school_id=school_library_loans.school_id and m.user_id=(select auth.uid()) and m.is_active) and (student_id is null or exists(select 1 from public.students s where s.id=student_id and s.school_id=school_library_loans.school_id and s.status='active')) and (borrower_membership_id is null or exists(select 1 from public.school_memberships m where m.id=borrower_membership_id and m.school_id=school_library_loans.school_id and m.is_active)));
create policy library_loans_update on public.school_library_loans for update to authenticated using(private.can_manage_school_library(school_id)) with check(private.can_manage_school_library(school_id) and exists(select 1 from public.school_library_copies c where c.id=copy_id and c.school_id=school_library_loans.school_id) and exists(select 1 from public.school_memberships m where m.id=issued_by and m.school_id=school_library_loans.school_id and m.is_active) and (returned_by is null or exists(select 1 from public.school_memberships m where m.id=returned_by and m.school_id=school_library_loans.school_id and m.user_id=(select auth.uid()) and m.is_active)) and (student_id is null or exists(select 1 from public.students s where s.id=student_id and s.school_id=school_library_loans.school_id)) and (borrower_membership_id is null or exists(select 1 from public.school_memberships m where m.id=borrower_membership_id and m.school_id=school_library_loans.school_id and m.is_active)));
create policy library_loans_delete on public.school_library_loans for delete to authenticated using(private.can_manage_school_library(school_id));
