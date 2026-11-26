create table if not exists public.school_discipline_cases (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete restrict,
 incident_date date not null default current_date,
 incident_type text not null check (incident_type in ('misconduct','bullying','attendance','property_damage','academic_integrity','safety','welfare','other')),
 severity text not null default 'low' check (severity in ('low','medium','high','critical')),
 location text,
 description text not null check (length(trim(description)) between 5 and 5000),
 witnesses text,
 action_taken text,
 action_type text not null default 'recorded' check (action_type in ('recorded','verbal_warning','written_warning','parent_meeting','detention','suspension','counselling','referral','other')),
 status text not null default 'open' check (status in ('open','in_review','resolved','follow_up')),
 follow_up_date date,
 resolution_notes text,
 confidential boolean not null default true,
 assigned_to uuid references public.school_memberships(id) on delete set null,
 created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
 updated_by uuid default auth.uid() references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint discipline_followup_date_check check (follow_up_date is null or follow_up_date >= incident_date)
);
create index if not exists school_discipline_cases_school_date_idx on public.school_discipline_cases(school_id, incident_date desc);
create index if not exists school_discipline_cases_student_idx on public.school_discipline_cases(school_id, student_id, incident_date desc);
create index if not exists school_discipline_cases_status_idx on public.school_discipline_cases(school_id, status, follow_up_date);
alter table public.school_discipline_cases enable row level security;
alter table public.school_discipline_cases force row level security;
revoke all privileges on table public.school_discipline_cases from public, anon, authenticated;
grant select,insert,update,delete on table public.school_discipline_cases to authenticated;
drop policy if exists discipline_leadership_read on public.school_discipline_cases;
create policy discipline_leadership_read on public.school_discipline_cases for select to authenticated using (private.has_school_role(school_id, array['owner','school_admin','headteacher','deputy_headteacher','academic_officer']::text[]));
drop policy if exists discipline_leadership_insert on public.school_discipline_cases;
create policy discipline_leadership_insert on public.school_discipline_cases for insert to authenticated with check (private.has_school_role(school_id, array['owner','school_admin','headteacher','deputy_headteacher','academic_officer']::text[]) and created_by = (select auth.uid()) and exists (select 1 from public.students s where s.id = student_id and s.school_id = school_discipline_cases.school_id));
drop policy if exists discipline_leadership_update on public.school_discipline_cases;
create policy discipline_leadership_update on public.school_discipline_cases for update to authenticated using (private.has_school_role(school_id, array['owner','school_admin','headteacher','deputy_headteacher','academic_officer']::text[])) with check (private.has_school_role(school_id, array['owner','school_admin','headteacher','deputy_headteacher','academic_officer']::text[]) and exists (select 1 from public.students s where s.id = student_id and s.school_id = school_discipline_cases.school_id));
drop policy if exists discipline_leadership_delete on public.school_discipline_cases;
create policy discipline_leadership_delete on public.school_discipline_cases for delete to authenticated using (private.has_school_role(school_id, array['owner','school_admin','headteacher']::text[]));
create or replace function public.validate_school_discipline_case()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
 if not exists (select 1 from public.students s where s.id = new.student_id and s.school_id = new.school_id) then
  raise exception 'Selected student does not belong to this school.';
 end if;
 if new.assigned_to is not null and not exists (select 1 from public.school_memberships m where m.id = new.assigned_to and m.school_id = new.school_id and m.is_active) then
  raise exception 'Assigned staff member is not active in this school.';
 end if;
 new.updated_at = now();
 new.updated_by = auth.uid();
 return new;
end $$;
drop trigger if exists validate_school_discipline_case on public.school_discipline_cases;
create trigger validate_school_discipline_case before insert or update on public.school_discipline_cases for each row execute function public.validate_school_discipline_case();