create or replace function private.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  supplied_name text := nullif(btrim(new.raw_user_meta_data ->> 'full_name'), '');
  supplied_school text := nullif(btrim(new.raw_user_meta_data ->> 'school_name'), '');
  supplied_role text := lower(coalesce(new.raw_user_meta_data ->> 'signup_role', ''));
  new_school_id uuid;
begin
  if new.invited_at is not null then
    insert into public.profiles (id, full_name)
    values (new.id, case when supplied_name is not null and char_length(supplied_name) between 2 and 160 then supplied_name else 'New user' end)
    on conflict (id) do nothing;
    return new;
  end if;

  if supplied_name is null or char_length(supplied_name) not between 2 and 160
    or supplied_school is null or char_length(supplied_school) not between 2 and 200
    or supplied_role not in ('owner', 'school_admin', 'headteacher', 'bursar', 'teacher', 'registrar', 'parent', 'student') then
    raise exception using errcode = '22023', message = 'Testing signup requires a valid name, secondary school, and role.';
  end if;

  insert into public.profiles (id, full_name)
  values (new.id, supplied_name)
  on conflict (id) do nothing;

  insert into public.schools (name, school_code, school_type, owner_user_id)
  values (supplied_school, 'TEST-' || substr(upper(replace(new.id::text, '-', '')), 1, 10), 'secondary', new.id)
  returning id into new_school_id;

  insert into public.school_memberships (school_id, user_id, role, is_active)
  values (new_school_id, new.id, supplied_role, true);

  return new;
end;
$$;

revoke all on function private.handle_new_user_profile() from public, anon, authenticated;
