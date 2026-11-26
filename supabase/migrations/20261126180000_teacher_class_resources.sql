create table if not exists public.teacher_class_resources (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 class_id uuid not null references public.classes(id) on delete cascade,
 subject_id uuid references public.subjects(id) on delete set null,
 term_id uuid references public.terms(id) on delete set null,
 teacher_membership_id uuid not null references public.school_memberships(id) on delete cascade,
 title text not null check (char_length(trim(title)) between 2 and 180),
 description text not null default '' check (char_length(description) <= 2000),
 category text not null default 'worksheet' check (category in ('worksheet','notes','presentation','reading','video','link','other')),
 file_path text,
 external_url text,
 file_name text,
 file_size bigint,
 mime_type text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint teacher_class_resources_source check ((file_path is not null and external_url is null) or (file_path is null and external_url is not null)),
 constraint teacher_class_resources_size check (file_size is null or file_size between 1 and 20971520)
);
create index if not exists teacher_class_resources_class_idx on public.teacher_class_resources(school_id,class_id,created_at desc);
alter table public.teacher_class_resources enable row level security;
grant select,insert,update,delete on public.teacher_class_resources to authenticated;
drop policy if exists teacher_class_resources_read on public.teacher_class_resources;
create policy teacher_class_resources_read on public.teacher_class_resources for select to authenticated using (
 exists (select 1 from public.school_memberships m where m.id=teacher_membership_id and m.user_id=(select auth.uid()) and m.school_id=school_id and m.is_active)
 or exists (select 1 from public.school_memberships m where m.user_id=(select auth.uid()) and m.school_id=school_id and m.is_active and m.role=any(array['owner','proprietor','school_admin','headteacher','deputy_headteacher','academic_officer']))
 or exists (select 1 from public.school_memberships m join public.classes c on c.class_teacher_membership_id=m.id where m.user_id=(select auth.uid()) and m.school_id=school_id and m.is_active and c.id=class_id)
 or exists (select 1 from public.school_memberships m join public.class_subjects cs on cs.teacher_membership_id=m.id where m.user_id=(select auth.uid()) and m.school_id=school_id and m.is_active and cs.class_id=class_id and (subject_id is null or cs.subject_id=subject_id))
);
drop policy if exists teacher_class_resources_insert on public.teacher_class_resources;
create policy teacher_class_resources_insert on public.teacher_class_resources for insert to authenticated with check (
 exists (select 1 from public.school_memberships m where m.id=teacher_membership_id and m.user_id=(select auth.uid()) and m.school_id=school_id and m.is_active and m.role=any(array['teacher','class_teacher']))
 and exists (select 1 from public.classes c where c.id=class_id and c.school_id=school_id)
 and (exists (select 1 from public.class_subjects cs where cs.school_id=school_id and cs.class_id=class_id and cs.teacher_membership_id=teacher_membership_id and (subject_id is null or cs.subject_id=subject_id))
 or exists (select 1 from public.classes c where c.id=class_id and c.class_teacher_membership_id=teacher_membership_id))
);
drop policy if exists teacher_class_resources_update on public.teacher_class_resources;
create policy teacher_class_resources_update on public.teacher_class_resources for update to authenticated using (
 exists (select 1 from public.school_memberships m where m.id=teacher_membership_id and m.user_id=(select auth.uid()) and m.school_id=school_id and m.is_active)
) with check (
 exists (select 1 from public.school_memberships m where m.id=teacher_membership_id and m.user_id=(select auth.uid()) and m.school_id=school_id and m.is_active)
 and (exists (select 1 from public.class_subjects cs where cs.school_id=school_id and cs.class_id=class_id and cs.teacher_membership_id=teacher_membership_id and (subject_id is null or cs.subject_id=subject_id))
 or exists (select 1 from public.classes c where c.id=class_id and c.class_teacher_membership_id=teacher_membership_id))
);
drop policy if exists teacher_class_resources_delete on public.teacher_class_resources;
create policy teacher_class_resources_delete on public.teacher_class_resources for delete to authenticated using (
 exists (select 1 from public.school_memberships m where m.id=teacher_membership_id and m.user_id=(select auth.uid()) and m.school_id=school_id and m.is_active)
);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values ('conedu-class-resources','conedu-class-resources',false,20971520,array['application/pdf','image/jpeg','image/png','image/webp','text/plain','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','video/mp4']) on conflict(id) do update set public=false,file_size_limit=20971520,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists conedu_class_resources_upload on storage.objects;
create policy conedu_class_resources_upload on storage.objects for insert to authenticated with check (
 bucket_id='conedu-class-resources' and exists (
  select 1 from public.school_memberships m
  where m.user_id=(select auth.uid()) and m.school_id=(split_part(name,'/',1))::uuid and m.is_active and m.role=any(array['teacher','class_teacher'])
  and (exists (select 1 from public.class_subjects cs where cs.school_id=m.school_id and cs.class_id=(split_part(name,'/',2))::uuid and cs.teacher_membership_id=m.id)
   or exists (select 1 from public.classes c where c.school_id=m.school_id and c.id=(split_part(name,'/',2))::uuid and c.class_teacher_membership_id=m.id))
 )
);
drop policy if exists conedu_class_resources_read on storage.objects;
create policy conedu_class_resources_read on storage.objects for select to authenticated using (
 bucket_id='conedu-class-resources' and exists (
  select 1 from public.school_memberships m
  where m.user_id=(select auth.uid()) and m.school_id=(split_part(name,'/',1))::uuid and m.is_active
  and (m.role=any(array['owner','proprietor','school_admin','headteacher','deputy_headteacher','academic_officer'])
   or exists (select 1 from public.classes c where c.school_id=m.school_id and c.id=(split_part(name,'/',2))::uuid and c.class_teacher_membership_id=m.id)
   or exists (select 1 from public.class_subjects cs where cs.school_id=m.school_id and cs.class_id=(split_part(name,'/',2))::uuid and cs.teacher_membership_id=m.id))
 )
);
drop policy if exists conedu_class_resources_update on storage.objects;
create policy conedu_class_resources_update on storage.objects for update to authenticated using (
 bucket_id='conedu-class-resources' and owner_id=(select auth.uid())::text
) with check (bucket_id='conedu-class-resources' and owner_id=(select auth.uid())::text);
drop policy if exists conedu_class_resources_delete on storage.objects;
create policy conedu_class_resources_delete on storage.objects for delete to authenticated using (
 bucket_id='conedu-class-resources' and owner_id=(select auth.uid())::text
);