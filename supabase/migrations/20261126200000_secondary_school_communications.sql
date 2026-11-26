create table public.school_announcements (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 title text not null check(length(trim(title)) between 3 and 180),
 body text not null check(length(trim(body)) between 1 and 12000),
 priority text not null default 'normal' check(priority in ('normal','important','urgent')),
 audience_type text not null default 'school' check(audience_type in ('school','roles','class')),
 audience_roles text[] not null default '{}',
 class_id uuid references public.classes(id) on delete set null,
 status text not null default 'draft' check(status in ('draft','published','archived')),
 publish_at timestamptz not null default now(),
 attachment_path text,
 created_by uuid not null references public.school_memberships(id),
 published_by uuid references public.school_memberships(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint school_announcements_audience_valid check((audience_type='school' and cardinality(audience_roles)=0 and class_id is null) or (audience_type='roles' and cardinality(audience_roles)>0 and class_id is null) or (audience_type='class' and class_id is not null and cardinality(audience_roles)=0)),
 constraint school_announcements_roles_allowed check(audience_roles <@ array['teacher','class_teacher','parent','student','school_admin','headteacher','deputy_headteacher','academic_officer','bursar']::text[])
);
create index school_announcements_school_status_date on public.school_announcements(school_id,status,publish_at desc);
create index school_announcements_class on public.school_announcements(class_id) where class_id is not null;
create index school_announcements_created_by_idx on public.school_announcements(created_by);
create index school_announcements_published_by_idx on public.school_announcements(published_by);
alter table public.school_announcements enable row level security;
alter table public.school_announcements force row level security;
revoke all on public.school_announcements from public,anon;
grant select,insert,update,delete on public.school_announcements to authenticated;
create schema if not exists private;
revoke all on schema private from public,anon;
grant usage on schema private to authenticated;
create or replace function private.can_view_school_announcement(p_announcement_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.school_announcements a join public.school_memberships m on m.school_id=a.school_id and m.user_id=(select auth.uid()) and m.is_active where a.id=p_announcement_id and a.status='published' and a.publish_at<=now() and (a.audience_type='school' or (a.audience_type='roles' and m.role=any(a.audience_roles)) or (a.audience_type='class' and (exists(select 1 from public.class_subjects cs where cs.school_id=a.school_id and cs.class_id=a.class_id and cs.teacher_membership_id=m.id) or exists(select 1 from public.classes c where c.school_id=a.school_id and c.id=a.class_id and c.class_teacher_membership_id=m.id) or exists(select 1 from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where sg.school_id=a.school_id and g.user_id=(select auth.uid()) and sg.receives_notifications and exists(select 1 from public.student_enrollments se where se.school_id=a.school_id and se.class_id=a.class_id and se.student_id=sg.student_id and se.status='enrolled')))))
$$;
revoke all on function private.can_view_school_announcement(uuid) from public,anon;
grant execute on function private.can_view_school_announcement(uuid) to authenticated;
create policy school_announcements_read on public.school_announcements for select to authenticated using(private.can_view_school_announcement(id) or exists(select 1 from public.school_memberships m where m.school_id=school_announcements.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer')));
create policy school_announcements_insert on public.school_announcements for insert to authenticated with check(exists(select 1 from public.school_memberships m where m.id=created_by and m.school_id=school_announcements.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer')) and (class_id is null or exists(select 1 from public.classes c where c.id=class_id and c.school_id=school_announcements.school_id)) and (published_by is null or exists(select 1 from public.school_memberships m where m.id=published_by and m.school_id=school_announcements.school_id)));
create policy school_announcements_update on public.school_announcements for update to authenticated using(exists(select 1 from public.school_memberships m where m.school_id=school_announcements.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))) with check(exists(select 1 from public.school_memberships m where m.school_id=school_announcements.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer')) and (class_id is null or exists(select 1 from public.classes c where c.id=class_id and c.school_id=school_announcements.school_id)) and (published_by is null or exists(select 1 from public.school_memberships m where m.id=published_by and m.school_id=school_announcements.school_id)));
create policy school_announcements_delete on public.school_announcements for delete to authenticated using(exists(select 1 from public.school_memberships m where m.school_id=school_announcements.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher')));
create table public.school_announcement_audit(id uuid primary key default gen_random_uuid(),announcement_id uuid not null,school_id uuid not null references public.schools(id) on delete cascade,actor_membership_id uuid not null references public.school_memberships(id),action text not null check(action in ('created','published','updated','archived','deleted')),changed_at timestamptz not null default now(),details jsonb not null default '{}'::jsonb);
alter table public.school_announcement_audit enable row level security;
alter table public.school_announcement_audit force row level security;
revoke all on public.school_announcement_audit from public,anon;
grant select on public.school_announcement_audit to authenticated;
create index school_announcement_audit_school_idx on public.school_announcement_audit(school_id,changed_at desc);
create index school_announcement_audit_actor_idx on public.school_announcement_audit(actor_membership_id);
create index school_announcement_audit_announcement_idx on public.school_announcement_audit(announcement_id);
create policy school_announcement_audit_read on public.school_announcement_audit for select to authenticated using(exists(select 1 from public.school_memberships m where m.school_id=school_announcement_audit.school_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher')));
create or replace function public.log_school_announcement_change() returns trigger language plpgsql security definer set search_path=public as $$
declare actor_id uuid; action_name text; school_value uuid; announcement_value uuid; title_value text; status_value text;
begin
 school_value:=coalesce(new.school_id,old.school_id); announcement_value:=coalesce(new.id,old.id); title_value:=coalesce(new.title,old.title); status_value:=coalesce(new.status,old.status);
 select m.id into actor_id from public.school_memberships m where m.school_id=school_value and m.user_id=(select auth.uid()) and m.is_active limit 1;
 actor_id:=coalesce(actor_id,new.published_by,new.created_by,old.published_by,old.created_by);
 if tg_op='INSERT' then action_name:=case when new.status='published' then 'published' else 'created' end; elsif tg_op='DELETE' then action_name:='deleted'; elsif old.status<>'published' and new.status='published' then action_name:='published'; elsif old.status<>'archived' and new.status='archived' then action_name:='archived'; else action_name:='updated'; end if;
 insert into public.school_announcement_audit(announcement_id,school_id,actor_membership_id,action,details) values(announcement_value,school_value,actor_id,action_name,jsonb_build_object('title',title_value,'status',status_value));
 if tg_op='DELETE' then return old; end if; new.updated_at:=now(); return new;
end $$;
revoke all on function public.log_school_announcement_change() from public,anon,authenticated;
create trigger school_announcement_audit_trigger after insert or update or delete on public.school_announcements for each row execute function public.log_school_announcement_change();
create or replace function public.set_school_announcement_updated_at() returns trigger language plpgsql set search_path=public as $$ begin new.updated_at=now(); return new; end $$;
create trigger school_announcement_updated_at before update on public.school_announcements for each row execute function public.set_school_announcement_updated_at();
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('conedu-announcement-files','conedu-announcement-files',false,20971520,array['application/pdf','image/jpeg','image/png','image/webp','text/plain','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.presentationml.presentation']) on conflict(id) do update set public=false,file_size_limit=20971520,allowed_mime_types=excluded.allowed_mime_types;
create policy announcement_files_upload on storage.objects for insert to authenticated with check(bucket_id='conedu-announcement-files' and exists(select 1 from public.school_memberships m where m.id=split_part(name,'/',1)::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer')));
create policy announcement_files_read on storage.objects for select to authenticated using((bucket_id='conedu-announcement-files' and exists(select 1 from public.school_announcements a where a.attachment_path=name and public.can_view_school_announcement(a.id))) or (bucket_id='conedu-announcement-files' and exists(select 1 from public.school_memberships m where m.id=split_part(name,'/',1)::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher','deputy_headteacher','academic_officer'))));
create policy announcement_files_delete on storage.objects for delete to authenticated using(bucket_id='conedu-announcement-files' and exists(select 1 from public.school_memberships m where m.id=split_part(name,'/',1)::uuid and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','school_admin','headteacher')));
