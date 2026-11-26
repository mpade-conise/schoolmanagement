alter table public.students add column if not exists email text;
alter table public.students add column if not exists user_id uuid references auth.users(id) on delete set null;
create unique index if not exists students_user_id_unique on public.students(user_id) where user_id is not null;
create index if not exists students_school_email_lower_idx on public.students(school_id,lower(email)) where email is not null;

create or replace function public.attach_student_portal_user(p_school_id uuid,p_student_id uuid,p_user_id uuid,p_email text)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 if auth.uid() is null or not exists(select 1 from public.school_memberships m where m.school_id=p_school_id and m.user_id=auth.uid() and m.role='school_admin' and m.is_active) then raise exception 'Only the school administrator can link a student portal account'; end if;
 if not exists(select 1 from public.school_memberships m where m.school_id=p_school_id and m.user_id=p_user_id and m.role='student' and m.is_active) then raise exception 'Student membership was not created'; end if;
 update public.students set user_id=p_user_id,email=lower(trim(p_email)) where id=p_student_id and school_id=p_school_id and lower(email)=lower(trim(p_email)) and user_id is null;
 if not found then raise exception 'Student record does not match the invited email or is already linked'; end if;
end $$;
revoke all on function public.attach_student_portal_user(uuid,uuid,uuid,text) from public,anon;
grant execute on function public.attach_student_portal_user(uuid,uuid,uuid,text) to authenticated;

create or replace function public.get_student_portal_data(p_school_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare actor uuid:=auth.uid(); s public.students%rowtype; cls uuid; payload jsonb;
begin
 if actor is null then raise exception 'Authentication required'; end if;
 if not exists(select 1 from public.school_memberships m where m.school_id=p_school_id and m.user_id=actor and m.role='student' and m.is_active) then raise exception 'An active student membership is required'; end if;
 select st.* into s from public.students st where st.school_id=p_school_id and st.user_id=actor and st.status='active' limit 1;
 if s.id is null then return jsonb_build_object('linked',false,'student',null,'attendance','[]'::jsonb,'results','[]'::jsonb,'timetable','[]'::jsonb,'resources','[]'::jsonb,'announcements','[]'::jsonb); end if;
 select se.class_id into cls from public.student_enrollments se where se.school_id=p_school_id and se.student_id=s.id and se.status='enrolled' order by se.enrollment_date desc limit 1;
 select jsonb_build_object(
  'linked',true,
  'student',jsonb_build_object('id',s.id,'admission_number',s.admission_number,'first_name',s.first_name,'middle_name',s.middle_name,'last_name',s.last_name,'photo_url',s.photo_url,'status',s.status,'class_id',cls,'class_name',(select c.name from public.classes c where c.id=cls and c.school_id=p_school_id)),
  'attendance',coalesce((select jsonb_agg(jsonb_build_object('date',ats.attendance_date,'status',ar.status,'note',ar.note) order by ats.attendance_date desc) from (select ar2.* from public.attendance_records ar2 join public.attendance_sessions as2 on as2.id=ar2.session_id and as2.school_id=ar2.school_id where ar2.school_id=p_school_id and ar2.student_id=s.id and as2.status in ('submitted','locked') order by as2.attendance_date desc limit 60) ar join public.attendance_sessions ats on ats.id=ar.session_id and ats.school_id=ar.school_id),'[]'::jsonb),
  'results',coalesce((select jsonb_agg(jsonb_build_object('exam',e.name,'exam_type',e.exam_type,'start_date',e.start_date,'subject',sub.name,'mark',em.mark,'maximum_mark',es.maximum_mark,'grade',em.grade,'comment',em.comment) order by e.start_date desc,sub.name) from public.school_exam_marks em join public.school_exam_subjects es on es.id=em.exam_subject_id and es.school_id=em.school_id join public.school_exams e on e.id=es.exam_id and e.school_id=es.school_id join public.subjects sub on sub.id=es.subject_id and sub.school_id=es.school_id where em.school_id=p_school_id and em.student_id=s.id and e.status='published' and es.status='published'),'[]'::jsonb),
  'timetable',coalesce((select jsonb_agg(jsonb_build_object('weekday',te.weekday,'start_time',te.start_time,'end_time',te.end_time,'room',te.room,'subject',sub.name,'teacher',(select coalesce(pr.full_name,'Teacher') from public.profiles pr join public.school_memberships tm on tm.user_id=pr.id where tm.id=te.teacher_membership_id)) order by te.weekday,te.start_time) from public.school_timetable_entries te join public.subjects sub on sub.id=te.subject_id and sub.school_id=te.school_id where te.school_id=p_school_id and te.class_id=cls),'[]'::jsonb),
  'resources',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'title',r.title,'description',r.description,'category',r.category,'subject',(select sub.name from public.subjects sub where sub.id=r.subject_id and sub.school_id=p_school_id),'file_path',r.file_path,'external_url',r.external_url,'file_name',r.file_name,'created_at',r.created_at) order by r.created_at desc) from public.teacher_class_resources r where r.school_id=p_school_id and r.class_id=cls),'[]'::jsonb),
  'announcements',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'title',a.title,'body',a.body,'priority',a.priority,'publish_at',a.publish_at,'attachment_path',a.attachment_path) order by a.publish_at desc) from public.school_announcements a where a.school_id=p_school_id and a.status='published' and a.publish_at<=now() and (a.audience_type='school' or (a.audience_type='roles' and 'student'=any(a.audience_roles)) or (a.audience_type='class' and a.class_id=cls))),'[]'::jsonb)
 ) into payload;
 return payload;
end $$;
revoke all on function public.get_student_portal_data(uuid) from public,anon;
grant execute on function public.get_student_portal_data(uuid) to authenticated;
