create or replace function public.manage_primary_school_structure(p_school_id uuid,p_entity text,p_payload jsonb,p_record_id uuid default null)
returns uuid language plpgsql set search_path=public,private as $function$
declare v_grade uuid; v_class uuid; v_subject uuid; v_year uuid; v_capacity integer; v_enrolled integer; v_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_school_role(p_school_id,array['owner','proprietor','school_admin','headteacher']::text[]) then raise exception 'You do not have permission to manage primary academic structure'; end if;
 if p_entity='grade_level' then
  if coalesce(p_payload->>'education_level','primary')<>'primary' then raise exception 'Primary standards must use the primary education level'; end if;
  if coalesce((p_payload->>'sort_order')::integer,1) not between 1 and 8 then raise exception 'Primary standards must be numbered from 1 to 8'; end if;
 elsif p_entity='class' then
  v_grade:=nullif(p_payload->>'grade_level_id','')::uuid; v_year:=nullif(p_payload->>'academic_year_id','')::uuid; v_capacity:=nullif(p_payload->>'capacity','')::integer;
  if v_capacity is not null and v_capacity<1 then raise exception 'Class capacity must be at least one'; end if;
  if not exists(select 1 from public.grade_levels where id=v_grade and school_id=p_school_id and education_level='primary' and is_active) then raise exception 'Select an active primary standard'; end if;
  if not exists(select 1 from public.academic_years where id=v_year and school_id=p_school_id) then raise exception 'Select an academic year belonging to this school'; end if;
  if p_record_id is not null then select count(*) into v_enrolled from public.student_enrollments where school_id=p_school_id and class_id=p_record_id and status='enrolled'; if v_capacity is not null and v_capacity<v_enrolled then raise exception 'Capacity cannot be lower than the current enrolled learner count (%)',v_enrolled; end if; end if;
 elsif p_entity='subject' then
  if coalesce(p_payload->>'education_level','primary') not in ('primary','both') then raise exception 'Only primary learning areas can be added here'; end if;
 elsif p_entity='class_subject' then
  v_class:=nullif(p_payload->>'class_id','')::uuid; v_subject:=nullif(p_payload->>'subject_id','')::uuid;
  if not exists(select 1 from public.classes c join public.grade_levels g on g.id=c.grade_level_id where c.id=v_class and c.school_id=p_school_id and c.is_active and g.education_level='primary') then raise exception 'Select an active primary class'; end if;
  if not exists(select 1 from public.subjects s where s.id=v_subject and s.school_id=p_school_id and s.is_active and s.education_level in ('primary','both')) then raise exception 'Select an active primary learning area'; end if;
 else raise exception 'Invalid primary academic structure entity'; end if;
 v_id:=public.manage_school_structure(p_school_id,p_entity,p_payload,p_record_id);
 return v_id;
end $function$;
revoke all on function public.manage_primary_school_structure(uuid,text,jsonb,uuid) from public,anon;
grant execute on function public.manage_primary_school_structure(uuid,text,jsonb,uuid) to authenticated;
