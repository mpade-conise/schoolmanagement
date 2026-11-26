create or replace function public.manage_school_calendar(p_school_id uuid,p_entity text,p_payload jsonb,p_record_id uuid default null)
returns uuid
language plpgsql
security invoker
set search_path=public,private
as $$
declare v_id uuid; v_year uuid; v_start date; v_end date; v_current boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','headteacher']::text[]) then raise exception 'You do not have permission to manage the academic calendar'; end if;
 if p_entity not in ('academic_year','term') then raise exception 'Invalid academic calendar entity'; end if;
 v_current:=coalesce((p_payload->>'is_current')::boolean,false);
 if p_entity='academic_year' then
  if nullif(trim(p_payload->>'name'),'') is null or nullif(p_payload->>'start_date','') is null or nullif(p_payload->>'end_date','') is null then raise exception 'Year name and date range are required'; end if;
  v_start:=(p_payload->>'start_date')::date; v_end:=(p_payload->>'end_date')::date;
  if v_start>=v_end then raise exception 'Academic year end date must be after start date'; end if;
  if exists(select 1 from public.academic_years y where y.school_id=p_school_id and y.id<>coalesce(p_record_id,'00000000-0000-0000-0000-000000000000'::uuid) and daterange(y.start_date,y.end_date,'[]') && daterange(v_start,v_end,'[]')) then raise exception 'Academic year dates overlap another year'; end if;
  if v_current then update public.academic_years set is_current=false where school_id=p_school_id and id is distinct from p_record_id; update public.terms set is_current=false where school_id=p_school_id and academic_year_id<>coalesce(p_record_id,'00000000-0000-0000-0000-000000000000'::uuid); end if;
  if p_record_id is null then insert into public.academic_years(school_id,name,start_date,end_date,is_current) values(p_school_id,trim(p_payload->>'name'),v_start,v_end,v_current) returning id into v_id;
  else update public.academic_years set name=trim(p_payload->>'name'),start_date=v_start,end_date=v_end,is_current=v_current where school_id=p_school_id and id=p_record_id returning id into v_id; end if;
  if v_id is null then raise exception 'Academic year not found in this school'; end if;
  if v_current then update public.terms set is_current=false where school_id=p_school_id and academic_year_id<>v_id; end if;
 else
  if nullif(p_payload->>'academic_year_id','') is null or nullif(trim(p_payload->>'name'),'') is null or nullif(p_payload->>'term_number','') is null or nullif(p_payload->>'start_date','') is null or nullif(p_payload->>'end_date','') is null then raise exception 'Academic year, term name, number and dates are required'; end if;
  v_year:=(p_payload->>'academic_year_id')::uuid; v_start:=(p_payload->>'start_date')::date; v_end:=(p_payload->>'end_date')::date;
  if v_start>=v_end then raise exception 'Term end date must be after start date'; end if;
  select start_date,end_date into v_start,v_end from public.academic_years where id=v_year and school_id=p_school_id;
  if not found then raise exception 'Select an academic year belonging to this school'; end if;
  if (p_payload->>'start_date')::date < v_start or (p_payload->>'end_date')::date > v_end then raise exception 'Term dates must be within the selected academic year'; end if;
  if v_current then update public.academic_years set is_current=true where id=v_year and school_id=p_school_id; update public.academic_years set is_current=false where school_id=p_school_id and id<>v_year; update public.terms set is_current=false where school_id=p_school_id and id is distinct from p_record_id; end if;
  if p_record_id is null then insert into public.terms(school_id,academic_year_id,name,term_number,start_date,end_date,is_current) values(p_school_id,v_year,trim(p_payload->>'name'),(p_payload->>'term_number')::smallint,(p_payload->>'start_date')::date,(p_payload->>'end_date')::date,v_current) returning id into v_id;
  else update public.terms set academic_year_id=v_year,name=trim(p_payload->>'name'),term_number=(p_payload->>'term_number')::smallint,start_date=(p_payload->>'start_date')::date,end_date=(p_payload->>'end_date')::date,is_current=v_current where school_id=p_school_id and id=p_record_id returning id into v_id; end if;
  if v_id is null then raise exception 'Term not found in this school'; end if;
 end if;
 return v_id;
end $$;
revoke all on function public.manage_school_calendar(uuid,text,jsonb,uuid) from public,anon;
grant execute on function public.manage_school_calendar(uuid,text,jsonb,uuid) to authenticated;
create unique index if not exists academic_years_one_current_per_school on public.academic_years(school_id) where is_current;
create unique index if not exists terms_one_current_per_school on public.terms(school_id) where is_current;
