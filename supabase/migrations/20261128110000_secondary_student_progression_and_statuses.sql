alter table public.students drop constraint if exists students_status_check;
alter table public.students add constraint students_status_check check(status in ('active','awaiting_admission','transferred','graduated','withdrawn','inactive','suspended','dismissed','archived'));
create table if not exists public.student_progression_history (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, student_id uuid not null references public.students(id) on delete cascade, action text not null check(action in ('class_transfer','promotion','repetition')), effective_date date not null, reason text, from_class_id uuid references public.classes(id), to_class_id uuid not null references public.classes(id), from_academic_year_id uuid references public.academic_years(id), to_academic_year_id uuid not null references public.academic_years(id), created_by uuid not null references auth.users(id), created_at timestamptz not null default now()
);
create index if not exists student_progression_history_school_student_idx on public.student_progression_history(school_id,student_id,effective_date desc);
alter table public.student_progression_history enable row level security; alter table public.student_progression_history force row level security; grant select on public.student_progression_history to authenticated;
create policy "School leadership reads student progression" on public.student_progression_history for select to authenticated using(exists(select 1 from public.school_memberships m where m.school_id=student_progression_history.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer')));
create or replace function public.progress_secondary_student(p_school_id uuid,p_student_id uuid,p_target_class_id uuid,p_target_academic_year_id uuid,p_action text,p_effective_date date,p_reason text default null) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid:=auth.uid(); v_student public.students%rowtype; v_current public.student_enrollments%rowtype; v_target public.classes%rowtype; v_history uuid;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not exists(select 1 from public.school_memberships m where m.school_id=p_school_id and m.user_id=v_user and m.is_active and m.role in ('owner','school_admin','headteacher')) then raise exception 'School leadership permission required'; end if;
 if p_action not in ('class_transfer','promotion','repetition') then raise exception 'Invalid student progression action'; end if;
 if p_effective_date is null or p_effective_date>current_date+30 then raise exception 'Invalid effective date'; end if;
 select * into v_student from public.students where id=p_student_id and school_id=p_school_id for update;
 if not found then raise exception 'Student not found in this school'; end if;
 if v_student.status not in ('active','suspended') then raise exception 'Only active or suspended students can be progressed'; end if;
 select * into v_target from public.classes where id=p_target_class_id and school_id=p_school_id and academic_year_id=p_target_academic_year_id and is_active for update;
 if not found then raise exception 'Target class and academic year are invalid'; end if;
 select * into v_current from public.student_enrollments where school_id=p_school_id and student_id=p_student_id and status='enrolled' order by enrollment_date desc limit 1 for update;
 if found then
  if p_action in ('promotion','repetition') and v_current.academic_year_id=p_target_academic_year_id then raise exception 'Promotion or repetition must target a different academic year'; end if;
  if p_action='class_transfer' and v_current.academic_year_id<>p_target_academic_year_id then raise exception 'Class transfer must remain in the same academic year'; end if;
  update public.student_enrollments set status='transferred',exit_date=p_effective_date where id=v_current.id;
 end if;
 if exists(select 1 from public.student_enrollments where school_id=p_school_id and student_id=p_student_id and academic_year_id=p_target_academic_year_id and status='enrolled') then raise exception 'Student already has an active enrollment in that academic year'; end if;
 insert into public.student_enrollments(school_id,student_id,class_id,academic_year_id,enrollment_date,status) values(p_school_id,p_student_id,p_target_class_id,p_target_academic_year_id,p_effective_date,'enrolled');
 insert into public.student_progression_history(school_id,student_id,action,effective_date,reason,from_class_id,to_class_id,from_academic_year_id,to_academic_year_id,created_by) values(p_school_id,p_student_id,p_action,p_effective_date,nullif(trim(p_reason),''),v_current.class_id,p_target_class_id,v_current.academic_year_id,p_target_academic_year_id,v_user) returning id into v_history;
 return v_history;
end $$;
revoke all on function public.progress_secondary_student(uuid,uuid,uuid,uuid,text,date,text) from public,anon;
grant execute on function public.progress_secondary_student(uuid,uuid,uuid,uuid,text,date,text) to authenticated;