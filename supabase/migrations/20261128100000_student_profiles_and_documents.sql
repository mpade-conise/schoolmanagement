create table if not exists public.student_profile_details (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete cascade,
 address text,
 nationality text,
 previous_school text,
 emergency_contact_name text,
 emergency_contact_phone text,
 medical_info text,
 updated_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(student_id)
);
create index if not exists student_profile_details_school_student_idx on public.student_profile_details(school_id,student_id);
alter table public.student_profile_details enable row level security;
alter table public.student_profile_details force row level security;
grant select,insert,update on public.student_profile_details to authenticated;
create policy "Student profile details restricted read" on public.student_profile_details for select to authenticated using (
 exists(select 1 from public.school_memberships m where m.school_id=student_profile_details.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
);
create policy "Student profile details leadership insert" on public.student_profile_details for insert to authenticated with check (
 updated_by=(select auth.uid()) and exists(select 1 from public.school_memberships m where m.school_id=student_profile_details.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer')) and exists(select 1 from public.students s where s.id=student_profile_details.student_id and s.school_id=student_profile_details.school_id)
);
create policy "Student profile details leadership update" on public.student_profile_details for update to authenticated using (
 exists(select 1 from public.school_memberships m where m.school_id=student_profile_details.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
) with check (
 updated_by=(select auth.uid()) and exists(select 1 from public.school_memberships m where m.school_id=student_profile_details.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer')) and exists(select 1 from public.students s where s.id=student_profile_details.student_id and s.school_id=student_profile_details.school_id)
);
create table if not exists public.student_documents (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete cascade,
 document_type text not null,
 document_name text not null,
 storage_path text not null unique,
 uploaded_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create index if not exists student_documents_school_student_idx on public.student_documents(school_id,student_id,created_at desc);
alter table public.student_documents enable row level security;
alter table public.student_documents force row level security;
grant select,insert,delete on public.student_documents to authenticated;
create policy "Student documents leadership read" on public.student_documents for select to authenticated using (
 exists(select 1 from public.school_memberships m where m.school_id=student_documents.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
);
create policy "Student documents leadership insert" on public.student_documents for insert to authenticated with check (
 uploaded_by=(select auth.uid()) and exists(select 1 from public.school_memberships m where m.school_id=student_documents.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer')) and exists(select 1 from public.students s where s.id=student_documents.student_id and s.school_id=student_documents.school_id)
);
create policy "Student documents leadership delete" on public.student_documents for delete to authenticated using (
 exists(select 1 from public.school_memberships m where m.school_id=student_documents.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher'))
);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('conedu-student-photos','conedu-student-photos',false,5242880,array['image/jpeg','image/png','image/webp']),
 ('conedu-student-documents','conedu-student-documents',false,15728640,array['application/pdf','image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy "School leadership read student photo files" on storage.objects for select to authenticated using (
 bucket_id='conedu-student-photos' and exists(select 1 from public.school_memberships m where m.school_id=((storage.foldername(name))[1])::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
);
create policy "School leadership upload student photo files" on storage.objects for insert to authenticated with check (
 bucket_id='conedu-student-photos' and exists(select 1 from public.school_memberships m where m.school_id=((storage.foldername(name))[1])::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
);
create policy "School leadership update student photo files" on storage.objects for update to authenticated using (
 bucket_id='conedu-student-photos' and exists(select 1 from public.school_memberships m where m.school_id=((storage.foldername(name))[1])::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
) with check (
 bucket_id='conedu-student-photos' and exists(select 1 from public.school_memberships m where m.school_id=((storage.foldername(name))[1])::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
);
create policy "School leadership delete student photo files" on storage.objects for delete to authenticated using (
 bucket_id='conedu-student-photos' and exists(select 1 from public.school_memberships m where m.school_id=((storage.foldername(name))[1])::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher'))
);
create policy "School leadership read student document files" on storage.objects for select to authenticated using (
 bucket_id='conedu-student-documents' and exists(select 1 from public.school_memberships m where m.school_id=((storage.foldername(name))[1])::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
);
create policy "School leadership upload student document files" on storage.objects for insert to authenticated with check (
 bucket_id='conedu-student-documents' and exists(select 1 from public.school_memberships m where m.school_id=((storage.foldername(name))[1])::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
);
create policy "School leadership update student document files" on storage.objects for update to authenticated using (
 bucket_id='conedu-student-documents' and exists(select 1 from public.school_memberships m where m.school_id=((storage.foldername(name))[1])::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
) with check (
 bucket_id='conedu-student-documents' and exists(select 1 from public.school_memberships m where m.school_id=((storage.foldername(name))[1])::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))
);
create policy "School leadership delete student document files" on storage.objects for delete to authenticated using (
 bucket_id='conedu-student-documents' and exists(select 1 from public.school_memberships m where m.school_id=((storage.foldername(name))[1])::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher'))
);