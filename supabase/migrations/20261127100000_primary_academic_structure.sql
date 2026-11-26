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

create or replace function public.enforce_primary_academic_structure()
returns trigger language plpgsql security definer set search_path=public,private,pg_temp as $function$
declare v_school_type text; v_level text; v_enrolled integer;
begin
 select school_type into v_school_type from public.schools where id=new.school_id;
 if tg_table_name='grade_levels' then
  if new.education_level='primary' and new.sort_order not between 1 and 8 then raise exception 'Primary standards must be numbered from 1 to 8'; end if;
  if v_school_type='primary' and new.education_level<>'primary' then raise exception 'This school can only configure primary standards'; end if;
  if v_school_type='secondary' and new.education_level<>'secondary' then raise exception 'This school can only configure secondary forms'; end if;
 elsif tg_table_name='classes' then
  select education_level into v_level from public.grade_levels where id=new.grade_level_id and school_id=new.school_id;
  if v_school_type='primary' and v_level<>'primary' then raise exception 'Primary classes must belong to a primary standard'; end if;
  if v_school_type='secondary' and v_level<>'secondary' then raise exception 'Secondary classes must belong to a secondary form'; end if;
  if new.capacity is not null then select count(*) into v_enrolled from public.student_enrollments where school_id=new.school_id and class_id=new.id and status='enrolled'; if v_enrolled>new.capacity then raise exception 'Class capacity cannot be lower than the current enrolment (%)',v_enrolled; end if; end if;
 elsif tg_table_name='subjects' then
  if v_school_type='primary' and new.education_level not in ('primary','both') then raise exception 'This school can only configure primary learning areas'; end if;
  if v_school_type='secondary' and new.education_level not in ('secondary','both') then raise exception 'This school can only configure secondary subjects'; end if;
 elsif tg_table_name='class_subjects' then
  select g.education_level into v_level from public.classes c join public.grade_levels g on g.id=c.grade_level_id where c.id=new.class_id and c.school_id=new.school_id;
  if v_level='primary' and not exists(select 1 from public.subjects where id=new.subject_id and school_id=new.school_id and education_level in ('primary','both')) then raise exception 'Primary classes can only be assigned primary learning areas'; end if;
  if v_level='secondary' and not exists(select 1 from public.subjects where id=new.subject_id and school_id=new.school_id and education_level in ('secondary','both')) then raise exception 'Secondary classes can only be assigned secondary subjects'; end if;
 end if;
 return new;
end $function$;
revoke all on function public.enforce_primary_academic_structure() from public,anon,authenticated;
drop trigger if exists enforce_primary_grade_level on public.grade_levels;
create trigger enforce_primary_grade_level before insert or update of school_id,education_level,sort_order on public.grade_levels for each row execute function public.enforce_primary_academic_structure();
drop trigger if exists enforce_primary_class on public.classes;
create trigger enforce_primary_class before insert or update of school_id,grade_level_id,capacity on public.classes for each row execute function public.enforce_primary_academic_structure();
drop trigger if exists enforce_primary_subject on public.subjects;
create trigger enforce_primary_subject before insert or update of school_id,education_level on public.subjects for each row execute function public.enforce_primary_academic_structure();
drop trigger if exists enforce_primary_class_subject on public.class_subjects;
create trigger enforce_primary_class_subject before insert or update of school_id,class_id,subject_id on public.class_subjects for each row execute function public.enforce_primary_academic_structure();
create unique index if not exists grade_levels_primary_standard_order_uidx on public.grade_levels(school_id,sort_order) where education_level='primary';