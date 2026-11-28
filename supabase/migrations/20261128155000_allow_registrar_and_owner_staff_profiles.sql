create or replace function public.manage_school_staff_profile(p_school_id uuid,p_membership_id uuid,p_staff_number text,p_employment_title text,p_employment_type text,p_hire_date date,p_is_active boolean,p_staff_profile_id uuid default null)
returns uuid language plpgsql set search_path to 'public','private' as $function$
declare v_id uuid; v_role text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_school_role(p_school_id,array['owner','proprietor','school_admin','headteacher','deputy_headteacher']::text[]) then raise exception 'You do not have permission to manage staff'; end if;
 if nullif(trim(p_staff_number),'') is null then raise exception 'Staff number is required'; end if;
 if p_employment_type is not null and p_employment_type not in ('permanent','contract','temporary','volunteer') then raise exception 'Invalid employment type'; end if;
 select role into v_role from public.school_memberships where id=p_membership_id and school_id=p_school_id and is_active;
 if v_role is null then raise exception 'Select an active member of this school'; end if;
 if v_role not in ('teacher','class_teacher','academic_officer','registrar','bursar','school_admin','headteacher','deputy_headteacher','owner','proprietor') then raise exception 'This membership role cannot be registered as school staff'; end if;
 if p_staff_profile_id is null then insert into public.staff_profiles(school_id,membership_id,staff_number,employment_title,employment_type,hire_date,is_active) values(p_school_id,p_membership_id,trim(p_staff_number),nullif(trim(p_employment_title),''),p_employment_type,p_hire_date,coalesce(p_is_active,true)) returning id into v_id;
 else update public.staff_profiles set membership_id=p_membership_id,staff_number=trim(p_staff_number),employment_title=nullif(trim(p_employment_title),''),employment_type=p_employment_type,hire_date=p_hire_date,is_active=p_is_active where id=p_staff_profile_id and school_id=p_school_id returning id into v_id; if v_id is null then raise exception 'Staff profile not found for this school'; end if; end if;
 return v_id;
end $function$;