create or replace function public.save_school_attendance(p_school_id uuid,p_class_id uuid,p_term_id uuid,p_attendance_date date,p_records jsonb,p_submit boolean default false)
returns uuid
language plpgsql
security definer
set search_path=public,private,pg_temp
as $$
declare v_session uuid; v_year uuid; v_term_start date; v_term_end date; v_uid uuid; v_membership uuid; v_can_manage boolean; v_enrolled_count integer; v_record_count integer; v_input_count integer;
begin
 v_uid:=auth.uid();
 if v_uid is null then raise exception 'Authentication required'; end if;
 if jsonb_typeof(coalesce(p_records,'[]'::jsonb))<>'array' then raise exception 'Attendance records must be an array'; end if;
 if p_attendance_date is null then raise exception 'Attendance date is required'; end if;
 select c.academic_year_id into v_year from public.classes c where c.id=p_class_id and c.school_id=p_school_id and c.is_active;
 if not found then raise exception 'Select an active class belonging to this school'; end if;
 select t.start_date,t.end_date into v_term_start,v_term_end from public.terms t where t.id=p_term_id and t.school_id=p_school_id and t.academic_year_id=v_year;
 if not found then raise exception 'Select a term belonging to the class academic year'; end if;
 if p_attendance_date<v_term_start or p_attendance_date>v_term_end then raise exception 'Attendance date must fall within the selected term'; end if;
 select sm.id into v_membership from public.school_memberships sm where sm.school_id=p_school_id and sm.user_id=v_uid and sm.is_active limit 1;
 v_can_manage:=private.has_school_role(p_school_id,array['owner','school_admin','headteacher']::text[]);
 if not v_can_manage and not exists(select 1 from public.classes c where c.id=p_class_id and c.school_id=p_school_id and c.class_teacher_membership_id=v_membership)
 and not exists(select 1 from public.class_subjects cs where cs.school_id=p_school_id and cs.class_id=p_class_id and cs.teacher_membership_id=v_membership) then
  raise exception 'You are not assigned to this class';
 end if;
 if exists(select 1 from jsonb_array_elements(p_records) r where coalesce(r->>'status','') not in ('present','absent','late','excused')) then raise exception 'Invalid attendance status'; end if;
 if exists(select 1 from jsonb_array_elements(p_records) r where not exists(select 1 from public.student_enrollments e join public.students s on s.school_id=e.school_id and s.id=e.student_id where e.school_id=p_school_id and e.student_id=(r->>'student_id')::uuid and e.class_id=p_class_id and e.academic_year_id=v_year and e.status='enrolled' and s.status='active')) then raise exception 'Attendance includes a student not actively enrolled in this class'; end if;
 select count(*) into v_enrolled_count from public.student_enrollments e join public.students s on s.school_id=e.school_id and s.id=e.student_id where e.school_id=p_school_id and e.class_id=p_class_id and e.academic_year_id=v_year and e.status='enrolled' and s.status='active';
 select count(*) into v_input_count from jsonb_array_elements(p_records);
 select count(distinct (r->>'student_id')::uuid) into v_record_count from jsonb_array_elements(p_records) r;
 if v_input_count<>v_record_count or v_record_count<>v_enrolled_count then raise exception 'Attendance must include every active enrolled student exactly once'; end if;
 insert into public.attendance_sessions(school_id,class_id,term_id,attendance_date,taken_by_membership_id,status,submitted_at)
 values(p_school_id,p_class_id,p_term_id,p_attendance_date,v_membership,case when p_submit then 'submitted' else 'open' end,case when p_submit then now() else null end)
 on conflict(class_id,attendance_date) do update set term_id=excluded.term_id,taken_by_membership_id=excluded.taken_by_membership_id,status=excluded.status,submitted_at=excluded.submitted_at
 where attendance_sessions.school_id=p_school_id and attendance_sessions.status<>'locked'
 returning id into v_session;
 if v_session is null then raise exception 'Attendance session is locked or unavailable'; end if;
 insert into public.attendance_records(school_id,session_id,student_id,status,note)
 select p_school_id,v_session,(r->>'student_id')::uuid,r->>'status',nullif(trim(r->>'note'),'')
 from jsonb_array_elements(p_records) r
 on conflict(session_id,student_id) do update set status=excluded.status,note=excluded.note,recorded_at=now();
 return v_session;
end $$;
revoke all on function public.save_school_attendance(uuid,uuid,uuid,date,jsonb,boolean) from public,anon;
grant execute on function public.save_school_attendance(uuid,uuid,uuid,date,jsonb,boolean) to authenticated;