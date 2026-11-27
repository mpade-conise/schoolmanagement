create table if not exists public.school_staff_attendance (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 staff_profile_id uuid not null references public.staff_profiles(id) on delete cascade,
 attendance_date date not null,
 status text not null check (status in ('present','absent','late','excused')),
 check_in time,
 check_out time,
 notes text,
 recorded_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(staff_profile_id,attendance_date)
);
create index if not exists school_staff_attendance_school_date_idx on public.school_staff_attendance(school_id,attendance_date);
alter table public.school_staff_attendance enable row level security;
alter table public.school_staff_attendance force row level security;
grant select,insert,update on public.school_staff_attendance to authenticated;
create policy "School leadership reads staff attendance" on public.school_staff_attendance for select to authenticated using (
 exists(select 1 from public.school_memberships m where m.school_id=school_staff_attendance.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','bursar'))
);
create policy "School leadership records staff attendance" on public.school_staff_attendance for insert to authenticated with check (
 recorded_by=(select auth.uid()) and exists(select 1 from public.school_memberships m where m.school_id=school_staff_attendance.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','bursar'))
 and exists(select 1 from public.staff_profiles s where s.id=school_staff_attendance.staff_profile_id and s.school_id=school_staff_attendance.school_id and s.is_active)
);
create policy "School leadership updates staff attendance" on public.school_staff_attendance for update to authenticated using (
 exists(select 1 from public.school_memberships m where m.school_id=school_staff_attendance.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','bursar'))
) with check (
 exists(select 1 from public.school_memberships m where m.school_id=school_staff_attendance.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','bursar'))
 and exists(select 1 from public.staff_profiles s where s.id=school_staff_attendance.staff_profile_id and s.school_id=school_staff_attendance.school_id and s.is_active)
);