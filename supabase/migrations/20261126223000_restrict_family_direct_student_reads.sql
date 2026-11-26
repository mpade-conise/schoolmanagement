drop policy if exists students_member_read on public.students;
create policy students_member_read on public.students for select to authenticated using (
  exists(select 1 from public.school_memberships m where m.school_id=students.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role not in ('parent','student'))
);
drop policy if exists guardians_member_read on public.guardians;
create policy guardians_member_read on public.guardians for select to authenticated using (
  exists(select 1 from public.school_memberships m where m.school_id=guardians.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role not in ('parent','student'))
);
drop policy if exists student_guardians_member_read on public.student_guardians;
create policy student_guardians_member_read on public.student_guardians for select to authenticated using (
  exists(select 1 from public.school_memberships m where m.school_id=student_guardians.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role not in ('parent','student'))
);
drop policy if exists enrollments_member_read on public.student_enrollments;
create policy enrollments_member_read on public.student_enrollments for select to authenticated using (
  exists(select 1 from public.school_memberships m where m.school_id=student_enrollments.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role not in ('parent','student'))
);
drop policy if exists attendance_member_read on public.attendance_sessions;
create policy attendance_member_read on public.attendance_sessions for select to authenticated using (
  exists(select 1 from public.school_memberships m where m.school_id=attendance_sessions.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role not in ('parent','student'))
);
drop policy if exists attendance_records_member_read on public.attendance_records;
create policy attendance_records_member_read on public.attendance_records for select to authenticated using (
  exists(select 1 from public.school_memberships m where m.school_id=attendance_records.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role not in ('parent','student'))
);