create table if not exists public.school_timetable_periods(
 id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id) on delete cascade,academic_year_id uuid not null references public.academic_years(id) on delete cascade,period_number smallint not null check(period_number between 1 and 30),name text not null check(length(trim(name)) between 1 and 60),start_time time not null,end_time time not null,period_type text not null default 'lesson' check(period_type in ('lesson','break')),is_double_allowed boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(school_id,academic_year_id,period_number),check(start_time<end_time)
);
alter table public.school_timetable_entries add column if not exists period_id uuid references public.school_timetable_periods(id) on delete set null;
alter table public.school_timetable_entries add column if not exists is_double_period boolean not null default false;
create table if not exists public.school_timetable_publications(id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id) on delete cascade,academic_year_id uuid not null references public.academic_years(id) on delete cascade,class_id uuid not null references public.classes(id) on delete cascade,version integer not null default 1 check(version>0),published_at timestamptz not null default now(),published_by uuid not null references auth.users(id),is_published boolean not null default true,updated_at timestamptz not null default now(),unique(school_id,academic_year_id,class_id));
create table if not exists public.school_timetable_publication_notifications(id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id) on delete cascade,academic_year_id uuid not null references public.academic_years(id) on delete cascade,class_id uuid not null references public.classes(id) on delete cascade,publication_id uuid not null references public.school_timetable_publications(id) on delete cascade,version integer not null,message text not null,created_at timestamptz not null default now(),processed_at timestamptz,delivery_status text not null default 'queued' check(delivery_status in ('queued','processed','failed')));
alter table public.school_events drop constraint if exists school_events_event_type_check;
alter table public.school_events add constraint school_events_event_type_check check(event_type=any(array['school','academic','sports','meeting','holiday','other','public_holiday','examination','staff_meeting','parent_meeting','sports_day','academic_deadline','school_opening','school_closing']::text[]));
alter table public.school_timetable_periods enable row level security;alter table public.school_timetable_publications enable row level security;alter table public.school_timetable_publication_notifications enable row level security;
create policy timetable_periods_read on public.school_timetable_periods for select using(private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer','teacher','class_teacher','parent','student']::text[]));
create policy timetable_periods_manage on public.school_timetable_periods for all using(private.has_school_role(school_id,array['owner','school_admin','headteacher']::text[])) with check(private.has_school_role(school_id,array['owner','school_admin','headteacher']::text[]));
create policy timetable_publications_read on public.school_timetable_publications for select using(private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer','teacher','class_teacher','parent','student']::text[]));
create policy timetable_publications_manage on public.school_timetable_publications for all using(private.has_school_role(school_id,array['owner','school_admin','headteacher']::text[])) with check(private.has_school_role(school_id,array['owner','school_admin','headteacher']::text[]));
create policy timetable_publication_notifications_read on public.school_timetable_publication_notifications for select using(private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer','teacher','class_teacher','parent','student']::text[]));
create policy timetable_publication_notifications_manage on public.school_timetable_publication_notifications for all using(private.has_school_role(school_id,array['owner','school_admin','headteacher']::text[])) with check(private.has_school_role(school_id,array['owner','school_admin','headteacher']::text[]));
drop policy if exists timetable_read on public.school_timetable_entries;
create policy timetable_read on public.school_timetable_entries for select using(private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer','teacher','class_teacher']::text[]) or (private.has_school_role(school_id,array['parent','student']::text[]) and exists(select 1 from public.school_timetable_publications p where p.school_id=school_timetable_entries.school_id and p.academic_year_id=school_timetable_entries.academic_year_id and p.class_id=school_timetable_entries.class_id and p.is_published)));
create or replace function private.validate_school_timetable_period() returns trigger language plpgsql security definer set search_path=public,private as $$
begin
 if not exists(select 1 from public.academic_years y where y.id=new.academic_year_id and y.school_id=new.school_id) then raise exception 'Academic year must belong to this school';end if;
 if exists(select 1 from public.school_timetable_periods p where p.school_id=new.school_id and p.academic_year_id=new.academic_year_id and p.id is distinct from new.id and p.start_time<new.end_time and p.end_time>new.start_time) then raise exception 'Period time overlaps another configured period or break';end if;return new;
end $$;
create trigger validate_school_timetable_period before insert or update on public.school_timetable_periods for each row execute function private.validate_school_timetable_period();
create or replace function public.manage_school_timetable_entry(p_school_id uuid,p_payload jsonb,p_entry_id uuid default null) returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_id uuid;v_class uuid;v_year uuid;v_subject uuid;v_teacher uuid;v_day smallint;v_start time;v_end time;v_room text;v_period uuid;v_double boolean;v_period_number smallint;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','headteacher']::text[]) then raise exception 'Only school leadership can manage the timetable';end if;
 v_class:=(p_payload->>'class_id')::uuid;v_year:=(p_payload->>'academic_year_id')::uuid;v_subject:=(p_payload->>'subject_id')::uuid;v_teacher:=nullif(p_payload->>'teacher_membership_id','')::uuid;v_day:=(p_payload->>'weekday')::smallint;v_room:=nullif(trim(p_payload->>'room'),'');v_period:=nullif(p_payload->>'period_id','')::uuid;v_double:=coalesce((p_payload->>'is_double_period')::boolean,false);
 if v_period is not null then
  select p.period_number,p.start_time,p.end_time into v_period_number,v_start,v_end from public.school_timetable_periods p where p.id=v_period and p.school_id=p_school_id and p.academic_year_id=v_year and p.period_type='lesson';
  if not found then raise exception 'Choose a configured lesson period for this academic year';end if;
  if v_double then
   if not exists(select 1 from public.school_timetable_periods p where p.school_id=p_school_id and p.academic_year_id=v_year and p.period_number=v_period_number+1 and p.period_type='lesson' and p.is_double_allowed) then raise exception 'A double period must use two consecutive lesson periods without a break';end if;
   select p.end_time into v_end from public.school_timetable_periods p where p.school_id=p_school_id and p.academic_year_id=v_year and p.period_number=v_period_number+1 and p.period_type='lesson';
  end if;
 else v_start:=(p_payload->>'start_time')::time;v_end:=(p_payload->>'end_time')::time;v_double:=false;end if;
 if v_day not between 1 and 5 or v_start>=v_end then raise exception 'Choose a weekday and a valid lesson time';end if;
 if not exists(select 1 from public.classes c where c.school_id=p_school_id and c.id=v_class and c.academic_year_id=v_year and c.is_active) then raise exception 'Class does not belong to the selected academic year';end if;
 if not exists(select 1 from public.class_subjects cs where cs.school_id=p_school_id and cs.class_id=v_class and cs.subject_id=v_subject and (v_teacher is null or cs.teacher_membership_id=v_teacher)) then raise exception 'Subject or teacher is not assigned to this class';end if;
 if v_teacher is not null and not exists(select 1 from public.school_memberships sm where sm.school_id=p_school_id and sm.id=v_teacher and sm.is_active and sm.role in ('teacher','class_teacher')) then raise exception 'Teacher membership is inactive or invalid';end if;
 if exists(select 1 from public.school_timetable_entries t where t.school_id=p_school_id and t.weekday=v_day and t.academic_year_id=v_year and t.id is distinct from p_entry_id and t.start_time<v_end and t.end_time>v_start and (t.class_id=v_class or (v_teacher is not null and t.teacher_membership_id=v_teacher) or (v_room is not null and lower(trim(coalesce(t.room,'')))=lower(trim(v_room))))) then raise exception 'Timetable conflict: class, teacher or room is already booked during this time';end if;
 if p_entry_id is null then insert into public.school_timetable_entries(school_id,class_id,academic_year_id,subject_id,teacher_membership_id,weekday,start_time,end_time,room,period_id,is_double_period) values(p_school_id,v_class,v_year,v_subject,v_teacher,v_day,v_start,v_end,v_room,v_period,v_double) returning id into v_id;
 else update public.school_timetable_entries set class_id=v_class,academic_year_id=v_year,subject_id=v_subject,teacher_membership_id=v_teacher,weekday=v_day,start_time=v_start,end_time=v_end,room=v_room,period_id=v_period,is_double_period=v_double,updated_at=now() where school_id=p_school_id and id=p_entry_id returning id into v_id;if v_id is null then raise exception 'Timetable lesson not found';end if;end if;
 update public.school_timetable_publications set is_published=false,updated_at=now() where school_id=p_school_id and academic_year_id=v_year and class_id=v_class and is_published;return v_id;
end $$;
create or replace function public.delete_school_timetable_entry(p_school_id uuid,p_entry_id uuid) returns void language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_year uuid;v_class uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','headteacher']::text[]) then raise exception 'Only school leadership can manage the timetable';end if;
 select academic_year_id,class_id into v_year,v_class from public.school_timetable_entries where school_id=p_school_id and id=p_entry_id;if not found then raise exception 'Timetable lesson not found';end if;
 delete from public.school_timetable_entries where school_id=p_school_id and id=p_entry_id;
 update public.school_timetable_publications set is_published=false,updated_at=now() where school_id=p_school_id and academic_year_id=v_year and class_id=v_class and is_published;
end $$;
create or replace function public.publish_school_timetable(p_school_id uuid,p_academic_year_id uuid,p_class_id uuid,p_publish boolean default true) returns integer language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_id uuid;v_version integer;v_count integer;v_user uuid;
begin
 v_user:=auth.uid();if v_user is null then raise exception 'Authentication required';end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','headteacher']::text[]) then raise exception 'Only school leadership can publish timetables';end if;
 if not exists(select 1 from public.classes c where c.id=p_class_id and c.school_id=p_school_id and c.academic_year_id=p_academic_year_id) then raise exception 'Class does not belong to this academic year';end if;
 select count(*) into v_count from public.school_timetable_entries e where e.school_id=p_school_id and e.academic_year_id=p_academic_year_id and e.class_id=p_class_id;
 if p_publish and v_count=0 then raise exception 'Add at least one lesson before publishing';end if;
 insert into public.school_timetable_publications(school_id,academic_year_id,class_id,version,published_by,is_published,published_at,updated_at) values(p_school_id,p_academic_year_id,p_class_id,1,v_user,p_publish,now(),now())
 on conflict(school_id,academic_year_id,class_id) do update set version=school_timetable_publications.version+1,published_by=excluded.published_by,is_published=excluded.is_published,published_at=now(),updated_at=now() returning id,version into v_id,v_version;
 if p_publish then insert into public.school_timetable_publication_notifications(school_id,academic_year_id,class_id,publication_id,version,message) values(p_school_id,p_academic_year_id,p_class_id,v_id,v_version,'A new or updated class timetable has been published.');end if;return v_version;
end $$;
revoke all on function public.publish_school_timetable(uuid,uuid,uuid,boolean) from public;grant execute on function public.publish_school_timetable(uuid,uuid,uuid,boolean) to authenticated;
