drop policy if exists school_exam_read on public.school_exams;
create policy school_exam_read on public.school_exams for select to authenticated using (
 private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer']::text[])
 or exists (
  select 1 from public.school_exam_subjects es
  join public.school_memberships m on m.school_id=es.school_id and m.user_id=auth.uid() and m.is_active and m.role in ('teacher','class_teacher')
  where es.school_id=school_exams.school_id and es.exam_id=school_exams.id and (
   exists(select 1 from public.class_subjects cs where cs.school_id=es.school_id and cs.class_id=es.class_id and cs.subject_id=es.subject_id and cs.teacher_membership_id=m.id)
   or exists(select 1 from public.classes c where c.school_id=es.school_id and c.id=es.class_id and c.class_teacher_membership_id=m.id)
  )
 )
);
drop policy if exists school_exam_subject_read on public.school_exam_subjects;
create policy school_exam_subject_read on public.school_exam_subjects for select to authenticated using (
 private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer']::text[])
 or exists (
  select 1 from public.school_memberships m
  where m.school_id=school_exam_subjects.school_id and m.user_id=auth.uid() and m.is_active and m.role in ('teacher','class_teacher')
  and (
   exists(select 1 from public.class_subjects cs where cs.school_id=school_exam_subjects.school_id and cs.class_id=school_exam_subjects.class_id and cs.subject_id=school_exam_subjects.subject_id and cs.teacher_membership_id=m.id)
   or exists(select 1 from public.classes c where c.school_id=school_exam_subjects.school_id and c.id=school_exam_subjects.class_id and c.class_teacher_membership_id=m.id)
  )
 )
);
drop policy if exists school_exam_marks_read on public.school_exam_marks;
create policy school_exam_marks_read on public.school_exam_marks for select to authenticated using (
 private.has_school_role(school_id,array['owner','school_admin','headteacher','deputy_headteacher','academic_officer']::text[])
 or exists (
  select 1 from public.school_exam_subjects es
  join public.school_memberships m on m.school_id=es.school_id and m.user_id=auth.uid() and m.is_active and m.role in ('teacher','class_teacher')
  where es.school_id=school_exam_marks.school_id and es.id=school_exam_marks.exam_subject_id and (
   exists(select 1 from public.class_subjects cs where cs.school_id=es.school_id and cs.class_id=es.class_id and cs.subject_id=es.subject_id and cs.teacher_membership_id=m.id)
   or exists(select 1 from public.classes c where c.school_id=es.school_id and c.id=es.class_id and c.class_teacher_membership_id=m.id)
  )
 )
);