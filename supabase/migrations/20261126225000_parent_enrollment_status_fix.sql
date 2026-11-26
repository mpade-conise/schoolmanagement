create or replace function public.get_parent_portal_data(p_school_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  actor uuid := auth.uid();
  actor_email text;
  guardian_row public.guardians%rowtype;
  payload jsonb;
begin
  if actor is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.school_memberships m where m.school_id=p_school_id and m.user_id=actor and m.is_active and m.role='parent') then
    raise exception 'An active parent membership is required for this school';
  end if;

  select lower(u.email) into actor_email from auth.users u where u.id=actor and u.email_confirmed_at is not null;
  if actor_email is null then raise exception 'Verify your email address before accessing the parent portal'; end if;

  update public.guardians set user_id=actor
  where school_id=p_school_id and user_id is null and lower(coalesce(email,''))=actor_email;

  select g.* into guardian_row from public.guardians g
  where g.school_id=p_school_id and g.user_id=actor
  order by g.created_at limit 1;

  if guardian_row.id is null then
    return jsonb_build_object('linked',false,'guardian',null,'students','[]'::jsonb,'announcements','[]'::jsonb);
  end if;

  select jsonb_build_object(
    'linked',true,
    'guardian',jsonb_build_object('id',guardian_row.id,'full_name',guardian_row.full_name,'email',guardian_row.email,'phone',guardian_row.phone,'relationship',guardian_row.relationship),
    'students',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',s.id,'admission_number',s.admission_number,'first_name',s.first_name,'middle_name',s.middle_name,'last_name',s.last_name,'sex',s.sex,'photo_url',s.photo_url,'status',s.status,
        'is_primary',sg.is_primary,
        'class_name',(select c.name from public.student_enrollments se join public.classes c on c.id=se.class_id and c.school_id=se.school_id where se.school_id=p_school_id and se.student_id=s.id and se.status='enrolled' order by se.enrollment_date desc limit 1),
        'attendance',jsonb_build_object(
          'present',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions ats on ats.id=ar.session_id and ats.school_id=ar.school_id where ar.school_id=p_school_id and ar.student_id=s.id and ats.status in ('submitted','locked') and ar.status='present'),0),
          'absent',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions ats on ats.id=ar.session_id and ats.school_id=ar.school_id where ar.school_id=p_school_id and ar.student_id=s.id and ats.status in ('submitted','locked') and ar.status='absent'),0),
          'late',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions ats on ats.id=ar.session_id and ats.school_id=ar.school_id where ar.school_id=p_school_id and ar.student_id=s.id and ats.status in ('submitted','locked') and ar.status='late'),0)
        ),
        'attendance_history',coalesce((
          select jsonb_agg(jsonb_build_object('date',ats.attendance_date,'status',ar.status,'note',ar.note) order by ats.attendance_date desc)
          from (select ar2.* from public.attendance_records ar2 join public.attendance_sessions as2 on as2.id=ar2.session_id and as2.school_id=ar2.school_id where ar2.school_id=p_school_id and ar2.student_id=s.id and as2.status in ('submitted','locked') order by as2.attendance_date desc limit 30) ar
          join public.attendance_sessions ats on ats.id=ar.session_id and ats.school_id=ar.school_id
        ),'[]'::jsonb),
        'results',coalesce((
          select jsonb_agg(jsonb_build_object('exam',e.name,'exam_type',e.exam_type,'start_date',e.start_date,'subject',sub.name,'mark',em.mark,'maximum_mark',es.maximum_mark,'grade',em.grade,'comment',em.comment) order by e.start_date desc,sub.name)
          from public.school_exam_marks em
          join public.school_exam_subjects es on es.id=em.exam_subject_id and es.school_id=em.school_id
          join public.school_exams e on e.id=es.exam_id and e.school_id=es.school_id
          join public.subjects sub on sub.id=es.subject_id and sub.school_id=es.school_id
          where em.school_id=p_school_id and em.student_id=s.id and e.status='published' and es.status='published'
        ),'[]'::jsonb),
        'fees',coalesce((
          select jsonb_agg(jsonb_build_object('id',fa.id,'fee_name',fa.fee_name,'amount',fa.amount,'discount_amount',fa.discount_amount,'due_date',fa.due_date,'paid',coalesce(pay.paid,0),'balance',greatest(fa.amount-fa.discount_amount-coalesce(pay.paid,0),0)) order by fa.due_date nulls last)
          from public.school_fee_accounts fa
          left join lateral (select sum(fp.amount) paid from public.school_fee_payments fp where fp.school_id=fa.school_id and fp.account_id=fa.id) pay on true
          where fa.school_id=p_school_id and fa.student_id=s.id
        ),'[]'::jsonb)
      ) order by sg.is_primary desc,s.last_name,s.first_name)
      from public.student_guardians sg
      join public.students s on s.id=sg.student_id and s.school_id=sg.school_id
      where sg.school_id=p_school_id and sg.guardian_id in (select g.id from public.guardians g where g.school_id=p_school_id and g.user_id=actor)
    ),'[]'::jsonb),
    'announcements',coalesce((
      select jsonb_agg(jsonb_build_object('id',a.id,'title',a.title,'body',a.body,'priority',a.priority,'publish_at',a.publish_at,'attachment_path',a.attachment_path,'class_name',c.name) order by a.publish_at desc)
      from public.school_announcements a
      left join public.classes c on c.id=a.class_id and c.school_id=a.school_id
      where a.school_id=p_school_id and a.status='published' and a.publish_at<=now()
        and (a.audience_type='school'
          or (a.audience_type='roles' and 'parent'=any(a.audience_roles))
          or (a.audience_type='class' and exists(select 1 from public.student_guardians sg join public.student_enrollments se on se.student_id=sg.student_id and se.school_id=sg.school_id and se.class_id=a.class_id and se.status='active' where sg.school_id=p_school_id and sg.guardian_id=guardian_row.id)))
    ),'[]'::jsonb)
  ) into payload;

  return payload;
end;
$$;

revoke all on function public.get_parent_portal_data(uuid) from public, anon;
grant execute on function public.get_parent_portal_data(uuid) to authenticated;
