create table if not exists public.primary_student_progression_history (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete cascade,
 action text not null check (action in ('promotion','repetition','class_transfer')),
 from_class_id uuid references public.classes(id) on delete set null,
 from_academic_year_id uuid references public.academic_years(id) on delete set null,
 to_class_id uuid not null references public.classes(id),
 to_academic_year_id uuid not null references public.academic_years(id),
 effective_date date not null,
 reason text,
 recorded_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create index if not exists primary_progression_school_student_idx on public.primary_student_progression_history(school_id,student_id,effective_date desc);
create index if not exists primary_progression_school_date_idx on public.primary_student_progression_history(school_id,effective_date desc);
create index if not exists primary_progression_student_fk_idx on public.primary_student_progression_history(student_id);
create index if not exists primary_progression_from_class_fk_idx on public.primary_student_progression_history(from_class_id);
create index if not exists primary_progression_from_year_fk_idx on public.primary_student_progression_history(from_academic_year_id);
create index if not exists primary_progression_to_class_fk_idx on public.primary_student_progression_history(to_class_id);
create index if not exists primary_progression_to_year_fk_idx on public.primary_student_progression_history(to_academic_year_id);
create index if not exists primary_progression_recorded_by_fk_idx on public.primary_student_progression_history(recorded_by);
alter table public.primary_student_progression_history enable row level security;
alter table public.primary_student_progression_history force row level security;
revoke all on public.primary_student_progression_history from public,anon,authenticated;
grant select on public.primary_student_progression_history to authenticated;
create policy primary_progression_history_read on public.primary_student_progression_history for select to authenticated using (private.has_school_role(school_id,array['owner','proprietor','school_admin','headteacher','deputy_headteacher','registrar','academic_officer']::text[]));
create or replace function public.progress_primary_school_students(p_school_id uuid,p_student_ids uuid[],p_target_class_id uuid,p_target_academic_year_id uuid,p_action text,p_effective_date date default current_date,p_reason text default null)
returns integer language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_student_id uuid; v_source record; v_count integer:=0;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_school_role(p_school_id,array['owner','proprietor','school_admin','headteacher','registrar']::text[]) then raise exception 'You do not have permission to progress learners in this school'; end if;
 if p_action not in ('promotion','repetition','class_transfer') then raise exception 'Invalid learner progression action'; end if;
 if coalesce(cardinality(p_student_ids),0)<1 or cardinality(p_student_ids)>500 then raise exception 'Select between 1 and 500 learners'; end if;
 if (select count(distinct x) from unnest(p_student_ids) x)<>cardinality(p_student_ids) then raise exception 'Duplicate learner IDs were supplied'; end if;
 if p_effective_date is null then raise exception 'Effective date is required'; end if;
 if length(coalesce(p_reason,''))>1000 then raise exception 'Reason must be 1000 characters or fewer'; end if;
 if not exists(select 1 from public.academic_years y where y.id=p_target_academic_year_id and y.school_id=p_school_id) then raise exception 'The selected academic year does not belong to this school'; end if;
 if not exists(select 1 from public.classes c join public.grade_levels g on g.id=c.grade_level_id where c.id=p_target_class_id and c.school_id=p_school_id and c.academic_year_id=p_target_academic_year_id and c.is_active and g.education_level='primary' and g.is_active) then raise exception 'Select an active primary class in the selected academic year'; end if;
 for v_student_id in select unnest(p_student_ids) loop
  if not exists(select 1 from public.students s where s.id=v_student_id and s.school_id=p_school_id and s.status='active') then raise exception 'One or more selected learners are not active students in this school'; end if;
  select e.id,e.class_id,e.academic_year_id,e.enrollment_date into v_source from public.student_enrollments e where e.school_id=p_school_id and e.student_id=v_student_id and e.status='enrolled' order by e.enrollment_date desc limit 1 for update;
  if v_source.id is null then raise exception 'Every selected learner must have an active class enrolment'; end if;
  if p_effective_date<v_source.enrollment_date then raise exception 'Effective date cannot be earlier than a learner''s current enrolment date'; end if;
  if v_source.class_id=p_target_class_id and v_source.academic_year_id=p_target_academic_year_id then raise exception 'Target class is already the learner''s current class'; end if;
  if exists(select 1 from public.student_enrollments e where e.school_id=p_school_id and e.student_id=v_student_id and e.academic_year_id=p_target_academic_year_id and e.status='enrolled') then raise exception 'A selected learner is already enrolled in the target academic year'; end if;
  update public.student_enrollments set status='completed',exit_date=p_effective_date where id=v_source.id;
  insert into public.student_enrollments(school_id,student_id,class_id,academic_year_id,enrollment_date,status) values(p_school_id,v_student_id,p_target_class_id,p_target_academic_year_id,p_effective_date,'enrolled');
  insert into public.primary_student_progression_history(school_id,student_id,action,from_class_id,from_academic_year_id,to_class_id,to_academic_year_id,effective_date,reason,recorded_by) values(p_school_id,v_student_id,p_action,v_source.class_id,v_source.academic_year_id,p_target_class_id,p_target_academic_year_id,p_effective_date,nullif(trim(coalesce(p_reason,'')),''),auth.uid());
  v_count:=v_count+1;
 end loop;
 return v_count;
end; $$;
revoke all on function public.progress_primary_school_students(uuid,uuid[],uuid,uuid,text,date,text) from public,anon;
grant execute on function public.progress_primary_school_students(uuid,uuid[],uuid,uuid,text,date,text) to authenticated;