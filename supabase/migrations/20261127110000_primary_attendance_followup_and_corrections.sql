create table if not exists public.primary_attendance_followups (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, attendance_record_id uuid not null references public.attendance_records(id) on delete cascade, absence_reason text not null, follow_up_status text not null default 'pending' check(follow_up_status in ('pending','contacted','resolved','unreachable')), guardian_contacted_at timestamptz, follow_up_notes text, assigned_to uuid references public.school_memberships(id) on delete set null, recorded_by uuid not null references auth.users(id), updated_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(attendance_record_id)
);
create table if not exists public.primary_attendance_correction_requests (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, attendance_record_id uuid not null references public.attendance_records(id) on delete cascade, requested_status text not null check(requested_status in ('present','absent','late','excused')), requested_note text, reason text not null, request_status text not null default 'pending' check(request_status in ('pending','approved','rejected')), requested_by uuid not null references auth.users(id), reviewed_by uuid references auth.users(id), reviewed_at timestamptz, review_notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index if not exists primary_attendance_one_pending_correction_uidx on public.primary_attendance_correction_requests(attendance_record_id) where request_status='pending';
create index if not exists primary_attendance_followups_school_status_idx on public.primary_attendance_followups(school_id,follow_up_status,updated_at desc);
create index if not exists primary_attendance_followups_record_idx on public.primary_attendance_followups(attendance_record_id);
create index if not exists primary_attendance_corrections_school_status_idx on public.primary_attendance_correction_requests(school_id,request_status,created_at desc);
create index if not exists primary_attendance_corrections_record_idx on public.primary_attendance_correction_requests(attendance_record_id);
alter table public.primary_attendance_followups enable row level security;
alter table public.primary_attendance_followups force row level security;
alter table public.primary_attendance_correction_requests enable row level security;
alter table public.primary_attendance_correction_requests force row level security;
revoke all on public.primary_attendance_followups,public.primary_attendance_correction_requests from public,anon,authenticated;
grant select on public.primary_attendance_followups,public.primary_attendance_correction_requests to authenticated;
drop policy if exists primary_attendance_followups_read on public.primary_attendance_followups;
create policy primary_attendance_followups_read on public.primary_attendance_followups for select to authenticated using(exists(select 1 from public.school_memberships m where m.school_id=primary_attendance_followups.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role not in ('parent','student')));
drop policy if exists primary_attendance_corrections_read on public.primary_attendance_correction_requests;
create policy primary_attendance_corrections_read on public.primary_attendance_correction_requests for select to authenticated using(exists(select 1 from public.school_memberships m where m.school_id=primary_attendance_correction_requests.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role not in ('parent','student')));
create or replace function public.manage_primary_attendance_followup(p_school_id uuid,p_record_id uuid,p_reason text,p_status text,p_notes text default null,p_assigned_to uuid default null)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_id uuid;
begin
 if auth.uid() is null or not private.has_school_role(p_school_id,array['owner','proprietor','school_admin','headteacher','deputy_headteacher','academic_officer']::text[]) then raise exception 'You do not have permission to manage attendance follow-up'; end if;
 if coalesce(length(trim(p_reason)),0)<2 or length(p_reason)>1000 then raise exception 'Provide an absence reason'; end if;
 if p_status not in ('pending','contacted','resolved','unreachable') then raise exception 'Invalid follow-up status'; end if;
 if not exists(select 1 from public.attendance_records ar join public.attendance_sessions s on s.id=ar.session_id and s.school_id=ar.school_id where ar.id=p_record_id and ar.school_id=p_school_id and ar.status in ('absent','late')) then raise exception 'Attendance record not found or is not absent/late'; end if;
 if p_assigned_to is not null and not exists(select 1 from public.school_memberships m where m.id=p_assigned_to and m.school_id=p_school_id and m.is_active and m.role in ('owner','proprietor','school_admin','headteacher','deputy_headteacher','academic_officer','teacher','class_teacher')) then raise exception 'Select an active school staff member'; end if;
 insert into public.primary_attendance_followups(school_id,attendance_record_id,absence_reason,follow_up_status,follow_up_notes,assigned_to,recorded_by,updated_by) values(p_school_id,p_record_id,trim(p_reason),p_status,nullif(trim(p_notes),''),p_assigned_to,auth.uid(),auth.uid())
 on conflict(attendance_record_id) do update set absence_reason=excluded.absence_reason,follow_up_status=excluded.follow_up_status,follow_up_notes=excluded.follow_up_notes,assigned_to=excluded.assigned_to,updated_by=auth.uid(),updated_at=now() returning id into v_id;
 return v_id;
end $$;
create or replace function public.request_primary_attendance_correction(p_school_id uuid,p_record_id uuid,p_status text,p_note text,p_reason text)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_session public.attendance_sessions%rowtype; v_membership uuid; v_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_status not in ('present','absent','late','excused') or coalesce(length(trim(p_reason)),0)<5 or length(p_reason)>1000 then raise exception 'Provide a valid correction and reason'; end if;
 select s.* into v_session from public.attendance_sessions s join public.attendance_records ar on ar.session_id=s.id and ar.school_id=s.school_id where ar.id=p_record_id and ar.school_id=p_school_id;
 if not found or v_session.status='locked' then raise exception 'Attendance record is unavailable or locked'; end if;
 select id into v_membership from public.school_memberships where school_id=p_school_id and user_id=auth.uid() and is_active limit 1;
 if not private.has_school_role(p_school_id,array['owner','proprietor','school_admin','headteacher','deputy_headteacher','academic_officer']::text[]) and not exists(select 1 from public.classes c where c.id=v_session.class_id and c.school_id=p_school_id and c.class_teacher_membership_id=v_membership) and not exists(select 1 from public.class_subjects cs where cs.school_id=p_school_id and cs.class_id=v_session.class_id and cs.teacher_membership_id=v_membership) then raise exception 'You are not authorised to request this correction'; end if;
 if exists(select 1 from public.primary_attendance_correction_requests r where r.attendance_record_id=p_record_id and r.request_status='pending') then raise exception 'A correction request is already pending'; end if;
 insert into public.primary_attendance_correction_requests(school_id,attendance_record_id,requested_status,requested_note,reason,requested_by) values(p_school_id,p_record_id,p_status,nullif(trim(p_note),''),trim(p_reason),auth.uid()) returning id into v_id;
 return v_id;
end $$;
create or replace function public.review_primary_attendance_correction(p_school_id uuid,p_request_id uuid,p_decision text,p_notes text default null)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_request public.primary_attendance_correction_requests%rowtype;
begin
 if auth.uid() is null or not private.has_school_role(p_school_id,array['owner','proprietor','school_admin','headteacher','deputy_headteacher']::text[]) then raise exception 'Only school leadership can review attendance corrections'; end if;
 if p_decision not in ('approved','rejected') then raise exception 'Invalid correction decision'; end if;
 select * into v_request from public.primary_attendance_correction_requests where id=p_request_id and school_id=p_school_id for update;
 if not found or v_request.request_status<>'pending' then raise exception 'Correction request is no longer pending'; end if;
 if p_decision='approved' then update public.attendance_records ar set status=v_request.requested_status,note=v_request.requested_note,recorded_at=now() from public.attendance_sessions s where ar.id=v_request.attendance_record_id and ar.session_id=s.id and ar.school_id=p_school_id and s.school_id=p_school_id and s.status<>'locked'; if not found then raise exception 'Attendance register is locked or unavailable'; end if; end if;
 update public.primary_attendance_correction_requests set request_status=p_decision,reviewed_by=auth.uid(),reviewed_at=now(),review_notes=nullif(trim(p_notes),''),updated_at=now() where id=p_request_id;
 return p_request_id;
end $$;
revoke all on function public.manage_primary_attendance_followup(uuid,uuid,text,text,text,uuid) from public,anon;
revoke all on function public.request_primary_attendance_correction(uuid,uuid,text,text,text) from public,anon;
revoke all on function public.review_primary_attendance_correction(uuid,uuid,text,text) from public,anon;
grant execute on function public.manage_primary_attendance_followup(uuid,uuid,text,text,text,uuid) to authenticated;
grant execute on function public.request_primary_attendance_correction(uuid,uuid,text,text,text) to authenticated;
grant execute on function public.review_primary_attendance_correction(uuid,uuid,text,text) to authenticated;
create index if not exists primary_attendance_followups_assigned_to_idx on public.primary_attendance_followups(assigned_to);
create index if not exists primary_attendance_followups_recorded_by_idx on public.primary_attendance_followups(recorded_by);
create index if not exists primary_attendance_followups_updated_by_idx on public.primary_attendance_followups(updated_by);
create index if not exists primary_attendance_corrections_requested_by_idx on public.primary_attendance_correction_requests(requested_by);
create index if not exists primary_attendance_corrections_reviewed_by_idx on public.primary_attendance_correction_requests(reviewed_by);
create or replace function public.manage_primary_attendance_followup(p_school_id uuid,p_record_id uuid,p_reason text,p_status text,p_notes text default null,p_assigned_to uuid default null)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_id uuid;
begin
 if auth.uid() is null or not private.has_school_role(p_school_id,array['owner','proprietor','school_admin','headteacher','deputy_headteacher','academic_officer']::text[]) then raise exception 'You do not have permission to manage attendance follow-up'; end if;
 if coalesce(length(trim(p_reason)),0)<2 or length(p_reason)>1000 then raise exception 'Provide an absence reason'; end if;
 if p_status not in ('pending','contacted','resolved','unreachable') then raise exception 'Invalid follow-up status'; end if;
 if not exists(select 1 from public.attendance_records ar join public.attendance_sessions s on s.id=ar.session_id and s.school_id=ar.school_id where ar.id=p_record_id and ar.school_id=p_school_id and ar.status in ('absent','late')) then raise exception 'Attendance record not found or is not absent/late'; end if;
 if p_assigned_to is not null and not exists(select 1 from public.school_memberships m where m.id=p_assigned_to and m.school_id=p_school_id and m.is_active and m.role in ('owner','proprietor','school_admin','headteacher','deputy_headteacher','academic_officer','teacher','class_teacher')) then raise exception 'Select an active school staff member'; end if;
 insert into public.primary_attendance_followups(school_id,attendance_record_id,absence_reason,follow_up_status,follow_up_notes,assigned_to,recorded_by,updated_by) values(p_school_id,p_record_id,trim(p_reason),p_status,nullif(trim(p_notes),''),p_assigned_to,auth.uid(),auth.uid())
 on conflict(attendance_record_id) do update set absence_reason=excluded.absence_reason,follow_up_status=excluded.follow_up_status,guardian_contacted_at=case when excluded.follow_up_status='contacted' then coalesce(primary_attendance_followups.guardian_contacted_at,now()) else primary_attendance_followups.guardian_contacted_at end,follow_up_notes=excluded.follow_up_notes,assigned_to=excluded.assigned_to,updated_by=auth.uid(),updated_at=now() returning id into v_id;
 return v_id;
end $$;