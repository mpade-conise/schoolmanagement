create index if not exists guardians_school_user_idx on public.guardians(school_id,user_id) where user_id is not null;
create index if not exists guardians_school_email_lower_idx on public.guardians(school_id,lower(email)) where email is not null;
create index if not exists student_guardians_school_guardian_student_idx on public.student_guardians(school_id,guardian_id,student_id) include (is_primary,receives_notifications);
create index if not exists attendance_records_school_student_session_idx on public.attendance_records(school_id,student_id,session_id);
create index if not exists school_exam_marks_school_student_subject_idx on public.school_exam_marks(school_id,student_id,exam_subject_id);
create index if not exists student_enrollments_school_student_status_idx on public.student_enrollments(school_id,student_id,status,enrollment_date desc);