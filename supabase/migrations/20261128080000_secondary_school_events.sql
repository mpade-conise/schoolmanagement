create table if not exists public.school_events (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 title text not null check (length(trim(title)) between 3 and 180),
 description text,
 event_type text not null default 'school' check (event_type in ('school','academic','sports','meeting','holiday','other')),
 start_at timestamptz not null,
 end_at timestamptz,
 location text,
 audience text not null default 'school' check (audience in ('school','staff','students','parents','class')),
 status text not null default 'scheduled' check (status in ('scheduled','cancelled')),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint school_events_valid_range check (end_at is null or end_at >= start_at)
);
create index if not exists school_events_school_start_idx on public.school_events(school_id,start_at) where status='scheduled';
alter table public.school_events enable row level security;
alter table public.school_events force row level security;
grant select,insert,update,delete on public.school_events to authenticated;
create policy "School members read school events" on public.school_events for select to authenticated using (
 exists(select 1 from public.school_memberships m where m.school_id=school_events.school_id and m.user_id=(select auth.uid()) and m.is_active)
);
create policy "School leadership manage events" on public.school_events for insert to authenticated with check (
 created_by=(select auth.uid()) and exists(select 1 from public.school_memberships m where m.school_id=school_events.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','academic_officer'))
);
create policy "School leadership update events" on public.school_events for update to authenticated using (
 exists(select 1 from public.school_memberships m where m.school_id=school_events.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','academic_officer'))
) with check (
 exists(select 1 from public.school_memberships m where m.school_id=school_events.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','academic_officer'))
);
create policy "School leadership delete events" on public.school_events for delete to authenticated using (
 exists(select 1 from public.school_memberships m where m.school_id=school_events.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','academic_officer'))
);
