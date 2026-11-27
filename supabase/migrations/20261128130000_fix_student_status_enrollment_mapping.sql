create or replace function public.set_school_student_status(p_school_id uuid,p_student_id uuid,p_status text,p_effective_date date default current_date) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid:=auth.uid(); v_student public.students%rowtype; v_enrollment_status text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not exists(select 1 from public.school_memberships m where m.school_id=p_school_id and m.user_id=v_user and m.is_active and m.role in ('owner','school_admin','headteacher')) then raise exception 'School leadership permission required'; end if;
 if p_status not in ('active','awaiting_admission','transferred','graduated','withdrawn','inactive','suspended','dismissed','archived') then raise exception 'Invalid student status'; end if;
 if p_effective_date is null or p_effective_date>current_date+30 then raise exception 'Invalid effective date'; end if;
 select * into v_student from public.students where id=p_student_id and school_id=p_school_id for update;
 if not found then raise exception 'Student not found in this school'; end if;
 update public.students set status=p_status,updated_at=now() where id=p_student_id and school_id=p_school_id;
 if p_status in ('awaiting_admission','transferred','graduated','withdrawn','inactive','dismissed','archived') then
  v_enrollment_status:=case when p_status='transferred' then 'transferred' when p_status='graduated' then 'completed' else 'withdrawn' end;
  update public.student_enrollments set status=v_enrollment_status,exit_date=greatest(p_effective_date,enrollment_date) where school_id=p_school_id and student_id=p_student_id and status='enrolled';
 end if;
end $$;
revoke all on function public.set_school_student_status(uuid,uuid,text,date) from public,anon;
grant execute on function public.set_school_student_status(uuid,uuid,text,date) to authenticated;