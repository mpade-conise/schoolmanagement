drop policy if exists school_grade_bands_admin_write on public.school_grade_bands;
create policy school_grade_bands_admin_write on public.school_grade_bands for all using (private.has_school_role(school_id,array['owner','school_admin','headteacher']::text[])) with check (private.has_school_role(school_id,array['owner','school_admin','headteacher']::text[]));
create or replace function private.validate_academic_structure_scope() returns trigger language plpgsql security definer set search_path=public,private as $$
declare v_count integer;
begin
 if tg_table_name='subjects' and new.department_id is not null then
  if not exists(select 1 from public.school_departments d where d.id=new.department_id and d.school_id=new.school_id) then raise exception 'Department must belong to the same school'; end if;
 elsif tg_table_name='school_departments' and new.head_membership_id is not null then
  if not exists(select 1 from public.school_memberships m where m.id=new.head_membership_id and m.school_id=new.school_id and m.is_active) then raise exception 'Department head must be an active member of this school'; end if;
 elsif tg_table_name='grade_subjects' then
  if not exists(select 1 from public.grade_levels g where g.id=new.grade_level_id and g.school_id=new.school_id and g.education_level='secondary') or not exists(select 1 from public.subjects s where s.id=new.subject_id and s.school_id=new.school_id and s.education_level in ('secondary','both')) then raise exception 'Form and subject must belong to this secondary school'; end if;
 elsif tg_table_name='subject_combinations' then
  if not exists(select 1 from public.grade_levels g where g.id=new.grade_level_id and g.school_id=new.school_id and g.education_level='secondary') then raise exception 'Form must belong to this secondary school'; end if;
  select count(*) into v_count from public.subjects s where s.school_id=new.school_id and s.id=any(new.subject_ids) and s.education_level in ('secondary','both');
  if v_count<>cardinality(new.subject_ids) then raise exception 'All combination subjects must belong to this secondary school'; end if;
  if new.selection_count>cardinality(new.subject_ids) then raise exception 'Selection count cannot exceed the combination subject count'; end if;
 elsif tg_table_name='school_academic_policies' then
  if new.grade_level_id is not null and not exists(select 1 from public.grade_levels g where g.id=new.grade_level_id and g.school_id=new.school_id and g.education_level='secondary') then raise exception 'Policy form must belong to this secondary school'; end if;
  select count(*) into v_count from public.subjects s where s.school_id=new.school_id and s.id=any(new.core_subject_ids) and s.education_level in ('secondary','both');
  if v_count<>cardinality(new.core_subject_ids) then raise exception 'Core subjects must belong to this secondary school'; end if;
 end if;
 return new;
end $$;
drop trigger if exists academic_subject_department_scope on public.subjects;
create trigger academic_subject_department_scope before insert or update of department_id,school_id on public.subjects for each row execute function private.validate_academic_structure_scope();
drop trigger if exists academic_department_head_scope on public.school_departments;
create trigger academic_department_head_scope before insert or update of head_membership_id,school_id on public.school_departments for each row execute function private.validate_academic_structure_scope();
drop trigger if exists academic_grade_subject_scope on public.grade_subjects;
create trigger academic_grade_subject_scope before insert or update on public.grade_subjects for each row execute function private.validate_academic_structure_scope();
drop trigger if exists academic_subject_combination_scope on public.subject_combinations;
create trigger academic_subject_combination_scope before insert or update on public.subject_combinations for each row execute function private.validate_academic_structure_scope();
drop trigger if exists academic_policy_scope on public.school_academic_policies;
create trigger academic_policy_scope before insert or update on public.school_academic_policies for each row execute function private.validate_academic_structure_scope();
