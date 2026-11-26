create unique index if not exists school_memberships_one_active_school_admin_idx
on public.school_memberships (school_id)
where is_active and role = 'school_admin';

create or replace function private.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  supplied_name text := nullif(btrim(new.raw_user_meta_data ->> 'full_name'), '');
begin
  if new.invited_at is null then
    raise exception using
      errcode = '42501',
      message = 'ConEdu accounts are invitation-only. Contact your school administrator.';
  end if;

  insert into public.profiles (id, full_name)
  values (
    new.id,
    case when supplied_name is not null and char_length(supplied_name) between 2 and 160
      then supplied_name else 'New user' end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function private.handle_new_user_profile() from public, anon, authenticated;