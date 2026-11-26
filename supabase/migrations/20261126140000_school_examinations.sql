create table if not exists public.school_exams(
 id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id) on delete cascade,academic_year_id uuid not null,term_id uuid not null,name text not null,exam_type text not null default 'end_of_term',start_date date not null,end_date date not null,status text not null default 'draft' check(status in ('draft','open','submitted','approved','published','locked')),created_by uuid references auth.users(id),approved_by uuid references auth.users(id),approved_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(school_id,id),foreign key(school_id,academic_year_id) references public.academic_years(school_id,id),foreign key(school_id,term_id) references public.terms(school_id,id),check(start_date<=end_date)
);
create table if not exists public.school_exam_subjects(
 id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id) on delete cascade,exam_id uuid not null,class_id uuid not null,subject_id uuid not null,maximum_mark numeric(7,2) not null default 100 check(maximum_mark>0),status text not null default 'draft' check(status in ('draft','open','submitted','approved','published','locked')),created_at timestamptz not null default now(),unique(school_id,id),unique(exam_id,class_id,subject_id),foreign key(school_id,exam_id) references public.school_exams(school_id,id) on delete cascade,foreign key(school_id,class_id) references public.classes(school_id,id),foreign key(school_id,subject_id) references public.subjects(school_id,id)
);
create table if not exists public.school_exam_marks(
 id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id) on delete cascade,exam_subject_id uuid not null,student_id uuid not null,mark numeric(7,2) check(mark>=0),grade text,comment text,entered_by uuid references auth.users(id),updated_at timestamptz not null default now(),unique(exam_subject_id,student_id),foreign key(school_id,exam_subject_id) references public.school_exam_subjects(school_id,id) on delete cascade,foreign key(school_id,student_id) references public.students(school_id,id)
);
create table if not exists public.school_grade_bands(
 id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id) on delete cascade,grade text not null,minimum_percent numeric(5,2) not null check(minimum_percent between 0 and 100),description text,sort_order smallint not null default 0,unique(school_id,grade),check(minimum_percent between 0 and 100)
);
create index if not exists school_exams_school_term_idx on public.school_exams(school_id,term_id);
create index if not exists school_exam_subjects_exam_idx on public.school_exam_subjects(school_id,exam_id,class_id);
create index if not exists school_exam_marks_subject_idx on public.school_exam_marks(school_id,exam_subject_id);
alter table public.school_exams enable row level security;
alter table public.school_exam_subjects enable row level security;
alter table public.school_exam_marks enable row level security;
alter table public.school_grade_bands enable row level security;
drop policy if exists school_exam_read on public.school_exams;
create policy school_exam_read on public.school_exams for select to authenticated using(private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer','teacher','class_teacher']::text[]));
drop policy if exists school_exam_subject_read on public.school_exam_subjects;
create policy school_exam_subject_read on public.school_exam_subjects for select to authenticated using(private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer','teacher','class_teacher']::text[]));
drop policy if exists school_exam_marks_read on public.school_exam_marks;
create policy school_exam_marks_read on public.school_exam_marks for select to authenticated using(private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer','teacher','class_teacher']::text[]));
drop policy if exists school_grade_bands_read on public.school_grade_bands;
create policy school_grade_bands_read on public.school_grade_bands for select to authenticated using(private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer','teacher','class_teacher']::text[]));
create or replace function public.manage_school_exam(p_school_id uuid,p_payload jsonb,p_exam_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_id uuid; v_year uuid; v_term uuid; v_start date; v_end date; v_status text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','headteacher']::text[]) then raise exception 'Only school leadership can manage examinations'; end if;
 if nullif(trim(p_payload->>'name'),'') is null or nullif(p_payload->>'academic_year_id','') is null or nullif(p_payload->>'term_id','') is null or nullif(p_payload->>'start_date','') is null or nullif(p_payload->>'end_date','') is null then raise exception 'Exam name, year, term and dates are required'; end if;
 v_year:=(p_payload->>'academic_year_id')::uuid;v_term:=(p_payload->>'term_id')::uuid;v_start:=(p_payload->>'start_date')::date;v_end:=(p_payload->>'end_date')::date;v_status:=coalesce(p_payload->>'status','draft');
 if v_start>v_end then raise exception 'Exam end date must not precede its start date';end if;
 if v_status not in ('draft','open') then raise exception 'New exams can only be draft or open';end if;
 if not exists(select 1 from public.terms t where t.id=v_term and t.school_id=p_school_id and t.academic_year_id=v_year and v_start>=t.start_date and v_end<=t.end_date) then raise exception 'Exam dates and term must belong to the selected academic year';end if;
 if p_exam_id is null then insert into public.school_exams(school_id,academic_year_id,term_id,name,exam_type,start_date,end_date,status,created_by) values(p_school_id,v_year,v_term,trim(p_payload->>'name'),coalesce(nullif(p_payload->>'exam_type',''),'end_of_term'),v_start,v_end,v_status,auth.uid()) returning id into v_id;
 else update public.school_exams set name=trim(p_payload->>'name'),academic_year_id=v_year,term_id=v_term,exam_type=coalesce(nullif(p_payload->>'exam_type',''),'end_of_term'),start_date=v_start,end_date=v_end,status=v_status,updated_at=now() where school_id=p_school_id and id=p_exam_id and status in ('draft','open') returning id into v_id; if v_id is null then raise exception 'Exam not found or already submitted';end if;end if;
 insert into public.school_grade_bands(school_id,grade,minimum_percent,description,sort_order) values(p_school_id,'A',80,'Excellent',1),(p_school_id,'B',70,'Very good',2),(p_school_id,'C',60,'Good',3),(p_school_id,'D',50,'Satisfactory',4),(p_school_id,'E',40,'Needs improvement',5),(p_school_id,'F',0,'Below standard',6) on conflict(school_id,grade) do nothing;
 return v_id;
end $;
create or replace function public.manage_school_exam_subject(p_school_id uuid,p_exam_id uuid,p_class_id uuid,p_subject_id uuid,p_maximum_mark numeric,p_record_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','headteacher']::text[]) then raise exception 'Only school leadership can configure exam subjects';end if;
 if p_maximum_mark is null or p_maximum_mark<=0 or p_maximum_mark>100000 then raise exception 'Maximum mark must be greater than zero';end if;
 if not exists(select 1 from public.school_exams e join public.classes c on c.school_id=e.school_id and c.academic_year_id=e.academic_year_id where e.id=p_exam_id and e.school_id=p_school_id and e.status in ('draft','open') and c.id=p_class_id and c.is_active) then raise exception 'Exam and active class must belong to this school and academic year';end if;
 if not exists(select 1 from public.class_subjects cs where cs.school_id=p_school_id and cs.class_id=p_class_id and cs.subject_id=p_subject_id) then raise exception 'Subject is not assigned to this class';end if;
 if p_record_id is null then insert into public.school_exam_subjects(school_id,exam_id,class_id,subject_id,maximum_mark,status) values(p_school_id,p_exam_id,p_class_id,p_subject_id,p_maximum_mark,'open') on conflict(exam_id,class_id,subject_id) do update set maximum_mark=excluded.maximum_mark returning id into v_id;
 else update public.school_exam_subjects es set maximum_mark=p_maximum_mark where es.school_id=p_school_id and es.id=p_record_id and es.exam_id=p_exam_id and exists(select 1 from public.school_exams e where e.id=p_exam_id and e.status in ('draft','open')) returning id into v_id;end if;
 if v_id is null then raise exception 'Exam subject not found or closed';end if;return v_id;
end $$;
create or replace function public.save_school_exam_marks(p_school_id uuid,p_exam_subject_id uuid,p_marks jsonb,p_submit boolean default false)
returns integer language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_exam uuid;v_class uuid;v_subject uuid;v_max numeric;v_year uuid;v_uid uuid;v_membership uuid;v_count integer;v_input integer;v_grade text;v_mark numeric;v_student uuid;v_item jsonb;v_band record;v_role_allowed boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if jsonb_typeof(coalesce(p_marks,'[]'::jsonb))<>'array' then raise exception 'Marks must be an array';end if;
 select es.exam_id,es.class_id,es.subject_id,es.maximum_mark,e.academic_year_id into v_exam,v_class,v_subject,v_max,v_year from public.school_exam_subjects es join public.school_exams e on e.id=es.exam_id and e.school_id=es.school_id where es.id=p_exam_subject_id and es.school_id=p_school_id and es.status in ('draft','open') and e.status in ('draft','open');
 if not found then raise exception 'Exam subject is closed or unavailable';end if;
 select id into v_membership from public.school_memberships where school_id=p_school_id and user_id=auth.uid() and is_active limit 1;
 v_role_allowed:=private.has_school_role(p_school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer']::text[]);
 if not v_role_allowed and not exists(select 1 from public.classes c where c.id=v_class and c.school_id=p_school_id and c.class_teacher_membership_id=v_membership) and not exists(select 1 from public.class_subjects cs where cs.school_id=p_school_id and cs.class_id=v_class and cs.subject_id=v_subject and cs.teacher_membership_id=v_membership) then raise exception 'You are not assigned to this class and subject';end if;
 if exists(select 1 from jsonb_array_elements(p_marks) m where nullif(m->>'mark','') is null or (m->>'mark')::numeric<0 or (m->>'mark')::numeric>v_max) then raise exception 'Every mark must be between zero and the maximum mark';end if;
 if exists(select 1 from jsonb_array_elements(p_marks) m where not exists(select 1 from public.student_enrollments en join public.students st on st.id=en.student_id and st.school_id=en.school_id where en.school_id=p_school_id and en.student_id=(m->>'student_id')::uuid and en.class_id=v_class and en.academic_year_id=v_year and en.status='enrolled' and st.status='active')) then raise exception 'Marks include a student not actively enrolled in this class';end if;
 select count(*) into v_count from public.student_enrollments en join public.students st on st.id=en.student_id and st.school_id=en.school_id where en.school_id=p_school_id and en.class_id=v_class and en.academic_year_id=v_year and en.status='enrolled' and st.status='active';
 select count(*) into v_input from jsonb_array_elements(p_marks);
 if v_input<>v_count or v_input<>(select count(distinct (m->>'student_id')::uuid) from jsonb_array_elements(p_marks) m) then raise exception 'Enter one mark for every active student exactly once';end if;
 for v_item in select value from jsonb_array_elements(p_marks) loop
  v_student:=(v_item->>'student_id')::uuid;v_mark:=(v_item->>'mark')::numeric;v_grade:=null;
  select grade into v_grade from public.school_grade_bands where school_id=p_school_id and minimum_percent<=v_mark*100/v_max order by minimum_percent desc limit 1;
  insert into public.school_exam_marks(school_id,exam_subject_id,student_id,mark,grade,comment,entered_by) values(p_school_id,p_exam_subject_id,v_student,v_mark,v_grade,nullif(trim(v_item->>'comment'),''),auth.uid()) on conflict(exam_subject_id,student_id) do update set mark=excluded.mark,grade=excluded.grade,comment=excluded.comment,entered_by=excluded.entered_by,updated_at=now();
 end loop;
 if p_submit then update public.school_exam_subjects set status='submitted' where id=p_exam_subject_id and school_id=p_school_id;end if;
 return v_input;
end $$;
create or replace function public.review_school_exam(p_school_id uuid,p_exam_id uuid,p_action text)
returns void language plpgsql security definer set search_path=public,private,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','headteacher']::text[]) then raise exception 'Only school leadership can review results';end if;
 if p_action='submit' then
  if not exists(select 1 from public.school_exam_subjects es where es.school_id=p_school_id and es.exam_id=p_exam_id) then raise exception 'Add at least one class subject before submitting';end if;
  if exists(select 1 from public.school_exam_subjects es join public.school_exams e on e.id=es.exam_id and e.school_id=es.school_id where es.school_id=p_school_id and es.exam_id=p_exam_id and (select count(*) from public.school_exam_marks m where m.school_id=p_school_id and m.exam_subject_id=es.id)<>(select count(*) from public.student_enrollments en join public.students st on st.id=en.student_id and st.school_id=en.school_id where en.school_id=p_school_id and en.class_id=es.class_id and en.academic_year_id=e.academic_year_id and en.status='enrolled' and st.status='active')) then raise exception 'Every exam subject must have a mark for every active enrolled student';end if;
  update public.school_exam_subjects set status='submitted' where school_id=p_school_id and exam_id=p_exam_id and status='open';
  update public.school_exams set status='submitted',updated_at=now() where id=p_exam_id and school_id=p_school_id and status in ('draft','open');
 elsif p_action='approve' then update public.school_exams set status='approved',approved_by=auth.uid(),approved_at=now(),updated_at=now() where id=p_exam_id and school_id=p_school_id and status='submitted';
 elsif p_action='publish' then update public.school_exams set status='published',updated_at=now() where id=p_exam_id and school_id=p_school_id and status='approved';
 else raise exception 'Invalid review action';end if;
 if not found then raise exception 'Exam cannot be moved to this status';end if;
end $$;
revoke all on function public.manage_school_exam(uuid,jsonb,uuid) from public,anon;
revoke all on function public.manage_school_exam_subject(uuid,uuid,uuid,uuid,numeric,uuid) from public,anon;
revoke all on function public.save_school_exam_marks(uuid,uuid,jsonb,boolean) from public,anon;
revoke all on function public.review_school_exam(uuid,uuid,text) from public,anon;
grant execute on function public.manage_school_exam(uuid,jsonb,uuid) to authenticated;
grant execute on function public.manage_school_exam_subject(uuid,uuid,uuid,uuid,numeric,uuid) to authenticated;
grant execute on function public.save_school_exam_marks(uuid,uuid,jsonb,boolean) to authenticated;
grant execute on function public.review_school_exam(uuid,uuid,text) to authenticated;
