drop policy if exists conedu_class_resources_read on storage.objects;
create policy conedu_class_resources_read on storage.objects for select to authenticated using (
 bucket_id='conedu-class-resources' and (
  exists(select 1 from public.school_memberships m where m.user_id=(select auth.uid()) and m.school_id=(split_part(objects.name,'/',1))::uuid and m.is_active and (m.role in ('owner','proprietor','school_admin','headteacher','deputy_headteacher','academic_officer') or exists(select 1 from public.classes c where c.school_id=m.school_id and c.id=(split_part(objects.name,'/',2))::uuid and c.class_teacher_membership_id=m.id) or exists(select 1 from public.class_subjects cs where cs.school_id=m.school_id and cs.class_id=(split_part(objects.name,'/',2))::uuid and cs.teacher_membership_id=m.id)))
  or exists(select 1 from public.school_memberships m join public.students s on s.school_id=m.school_id and s.user_id=m.user_id join public.student_enrollments se on se.school_id=s.school_id and se.student_id=s.id and se.status='enrolled' where m.user_id=(select auth.uid()) and m.school_id=(split_part(objects.name,'/',1))::uuid and m.role='student' and m.is_active and se.class_id=(split_part(objects.name,'/',2))::uuid and s.status='active')
 )
);
drop policy if exists announcement_files_read on storage.objects;
create policy announcement_files_read on storage.objects for select to authenticated using (
 bucket_id='conedu-announcement-files' and (
  exists(select 1 from public.school_announcements a where a.attachment_path=objects.name and private.can_view_school_announcement(a.id))
  or exists(select 1 from public.school_memberships m join public.students s on s.school_id=m.school_id and s.user_id=m.user_id join public.student_enrollments se on se.school_id=s.school_id and se.student_id=s.id and se.status='enrolled' join public.school_announcements a on a.school_id=m.school_id and a.attachment_path=objects.name where m.user_id=(select auth.uid()) and m.role='student' and m.is_active and s.status='active' and a.status='published' and a.publish_at<=now() and (a.audience_type='school' or (a.audience_type='roles' and 'student'=any(a.audience_roles)) or (a.audience_type='class' and a.class_id=se.class_id)))
  or exists(select 1 from public.school_memberships m where m.id=(split_part(objects.name,'/',1))::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
 )
);