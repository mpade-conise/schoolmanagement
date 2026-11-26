create table if not exists public.school_timetable_entries(
 id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id) on delete cascade,class_id uuid not null,academic_year_id uuid not null,subject_id uuid not null,teacher_membership_id uuid,start_time time not null,end_time time not null,weekday smallint not null check(weekday between 1 and 5),room text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),foreign key(school_id,class_id) references public.classes(school_id,id) on delete cascade,foreign key(school_id,academic_year_id) references public.academic_years(school_id,id),foreign key(school_id,subject_id) references public.subjects(school_id,id),foreign key(school_id,teacher_membership_id) references public.school_memberships(school_id,id),check(start_time<end_time)
);
create index if not exists school_timetable_week_idx on public.school_timetable_entries(school_id,academic_year_id,weekday,start_time);
alter table public.school_timetable_entries enable row level security;
drop policy if exists timetable_read on public.school_timetable_entries;
create policy timetable_read on public.school_timetable_entries for select to authenticated using(private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer','teacher','class_teacher']::text[]));
create or replace function public.manage_school_timetable_entry(p_school_id uuid,p_payload jsonb,p_entry_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_id uuid;v_class uuid;v_year uuid;v_subject uuid;v_teacher uuid;v_day smallint;v_start time;v_end time;v_room text;v_role text;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','headteacher']::text[]) then raise exception 'Only school leadership can manage the timetable';end if;
 v_class:=(p_payload->>'class_id')::uuid;v_year:=(p_payload->>'academic_year_id')::uuid;v_subject:=(p_payload->>'subject_id')::uuid;v_teacher:=nullif(p_payload->>'teacher_membership_id','')::uuid;v_day:=(p_payload->>'weekday')::smallint;v_start:=(p_payload->>'start_time')::time;v_end:=(p_payload->>'end_time')::time;v_room:=nullif(trim(p_payload->>'room'),'');
 if v_day not between 1 and 5 or v_start>=v_end then raise exception 'Choose a weekday and a valid lesson time';end if;
 if not exists(select 1 from public.classes c where c.school_id=p_school_id and c.id=v_class and c.academic_year_id=v_year and c.is_active) then raise exception 'Class does not belong to the selected academic year';end if;
 if not exists(select 1 from public.class_subjects cs where cs.school_id=p_school_id and cs.class_id=v_class and cs.subject_id=v_subject and (v_teacher is null or cs.teacher_membership_id=v_teacher)) then raise exception 'Subject or teacher is not assigned to this class';end if;
 if v_teacher is not null and not exists(select 1 from public.school_memberships sm where sm.school_id=p_school_id and sm.id=v_teacher and sm.is_active and sm.role in ('teacher','class_teacher')) then raise exception 'Teacher membership is inactive or invalid';end if;
 if exists(select 1 from public.school_timetable_entries t where t.school_id=p_school_id and t.weekday=v_day and t.academic_year_id=v_year and (t.class_id=v_class or (v_teacher is not null and t.teacher_membership_id=v_teacher)) and t.id is distinct from p_entry_id and t.start_time<v_end and t.end_time>v_start) then raise exception 'Timetable conflict: class or teacher already has a lesson during this time';end if;
 if p_entry_id is null then insert into public.school_timetable_entries(school_id,class_id,academic_year_id,subject_id,teacher_membership_id,weekday,start_time,end_time,room) values(p_school_id,v_class,v_year,v_subject,v_teacher,v_day,v_start,v_end,v_room) returning id into v_id;
 else update public.school_timetable_entries set class_id=v_class,academic_year_id=v_year,subject_id=v_subject,teacher_membership_id=v_teacher,weekday=v_day,start_time=v_start,end_time=v_end,room=v_room,updated_at=now() where school_id=p_school_id and id=p_entry_id returning id into v_id;if v_id is null then raise exception 'Timetable lesson not found';end if;end if;return v_id;
end $$;
create or replace function public.delete_school_timetable_entry(p_school_id uuid,p_entry_id uuid)
returns void language plpgsql security definer set search_path=public,private,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','headteacher']::text[]) then raise exception 'Only school leadership can manage the timetable';end if;
 delete from public.school_timetable_entries where school_id=p_school_id and id=p_entry_id;
 if not found then raise exception 'Timetable lesson not found';end if;
end $$;
revoke all on function public.manage_school_timetable_entry(uuid,jsonb,uuid) from public,anon;
revoke all on function public.delete_school_timetable_entry(uuid,uuid) from public,anon;
grant execute on function public.manage_school_timetable_entry(uuid,jsonb,uuid) to authenticated;
grant execute on function public.delete_school_timetable_entry(uuid,uuid) to authenticated;