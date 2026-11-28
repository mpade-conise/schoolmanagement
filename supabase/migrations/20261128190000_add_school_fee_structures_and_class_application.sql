create table if not exists public.school_fee_structures (
 id uuid primary key default gen_random_uuid(),
 school_id uuid not null references public.schools(id) on delete cascade,
 academic_year_id uuid not null references public.academic_years(id) on delete restrict,
 term_id uuid references public.terms(id) on delete restrict,
 grade_level_id uuid references public.grade_levels(id) on delete restrict,
 class_id uuid references public.classes(id) on delete restrict,
 fee_category text not null default 'other' check (fee_category in ('tuition','boarding','examination','development','transport','other')),
 fee_name text not null check (length(trim(fee_name)) between 2 and 120),
 amount numeric(12,2) not null check (amount > 0),
 is_optional boolean not null default false,
 due_date date,
 is_active boolean not null default true,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint school_fee_structures_scope_check check (class_id is null or grade_level_id is null)
);
create index if not exists school_fee_structures_school_year_idx on public.school_fee_structures(school_id,academic_year_id,is_active);
alter table public.school_fee_structures enable row level security;
drop policy if exists "Finance staff read fee structures" on public.school_fee_structures;
create policy "Finance staff read fee structures" on public.school_fee_structures for select to authenticated using (private.has_school_role(school_id,array['owner','school_admin','bursar']::text[]));
grant select on public.school_fee_structures to authenticated;
revoke insert,update,delete on public.school_fee_structures from authenticated;
create or replace function public.manage_school_fee_structure(p_school_id uuid,p_payload jsonb,p_structure_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_id uuid; v_year uuid; v_term uuid; v_grade uuid; v_class uuid; v_category text; v_name text; v_amount numeric; v_due date; v_optional boolean; v_active boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','bursar']::text[]) then raise exception 'Only authorised finance staff can manage fee structures'; end if;
 v_year:=nullif(p_payload->>'academic_year_id','')::uuid; v_term:=nullif(p_payload->>'term_id','')::uuid; v_grade:=nullif(p_payload->>'grade_level_id','')::uuid; v_class:=nullif(p_payload->>'class_id','')::uuid;
 v_category:=coalesce(nullif(p_payload->>'fee_category',''),'other'); v_name:=trim(coalesce(p_payload->>'fee_name','')); v_amount:=nullif(p_payload->>'amount','')::numeric; v_due:=nullif(p_payload->>'due_date','')::date;
 v_optional:=coalesce((p_payload->>'is_optional')::boolean,false); v_active:=coalesce((p_payload->>'is_active')::boolean,true);
 if v_year is null or length(v_name) not between 2 and 120 or v_amount is null or v_amount<=0 or v_category not in ('tuition','boarding','examination','development','transport','other') then raise exception 'Enter valid fee structure details'; end if;
 if not exists(select 1 from public.academic_years where id=v_year and school_id=p_school_id) then raise exception 'Academic year does not belong to this school'; end if;
 if v_term is not null and not exists(select 1 from public.terms where id=v_term and school_id=p_school_id and academic_year_id=v_year) then raise exception 'Term must belong to selected academic year'; end if;
 if v_grade is not null and not exists(select 1 from public.grade_levels where id=v_grade and school_id=p_school_id and is_active) then raise exception 'Form does not belong to this school'; end if;
 if v_class is not null and not exists(select 1 from public.classes where id=v_class and school_id=p_school_id and academic_year_id=v_year and is_active) then raise exception 'Class does not belong to selected academic year'; end if;
 if v_class is not null and v_grade is not null then raise exception 'Choose either a form or a class'; end if;
 if p_structure_id is null then
  insert into public.school_fee_structures(school_id,academic_year_id,term_id,grade_level_id,class_id,fee_category,fee_name,amount,is_optional,due_date,is_active,created_by)
  values(p_school_id,v_year,v_term,v_grade,v_class,v_category,v_name,v_amount,v_optional,v_due,v_active,auth.uid()) returning id into v_id;
 else
  update public.school_fee_structures set academic_year_id=v_year,term_id=v_term,grade_level_id=v_grade,class_id=v_class,fee_category=v_category,fee_name=v_name,amount=v_amount,is_optional=v_optional,due_date=v_due,is_active=v_active,updated_at=now()
  where id=p_structure_id and school_id=p_school_id returning id into v_id;
  if v_id is null then raise exception 'Fee structure not found'; end if;
 end if;
 return v_id;
end $$;
create or replace function public.apply_school_fee_structure_to_class(p_school_id uuid,p_structure_id uuid,p_class_id uuid)
returns jsonb language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_s public.school_fee_structures%rowtype; v_inserted integer;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','bursar']::text[]) then raise exception 'Only authorised finance staff can apply fee structures'; end if;
 select * into v_s from public.school_fee_structures where id=p_structure_id and school_id=p_school_id and is_active for update;
 if not found then raise exception 'Active fee structure not found'; end if;
 if not exists(select 1 from public.classes c where c.id=p_class_id and c.school_id=p_school_id and c.academic_year_id=v_s.academic_year_id and c.is_active and (v_s.class_id is null or v_s.class_id=c.id) and (v_s.grade_level_id is null or v_s.grade_level_id=c.grade_level_id)) then raise exception 'Class does not match this fee structure'; end if;
 insert into public.school_fee_accounts(school_id,student_id,academic_year_id,term_id,fee_name,amount,discount_amount,due_date,created_by)
 select p_school_id,e.student_id,v_s.academic_year_id,v_s.term_id,v_s.fee_name,v_s.amount,0,v_s.due_date,auth.uid()
 from public.student_enrollments e join public.students s on s.id=e.student_id and s.school_id=p_school_id
 where e.school_id=p_school_id and e.class_id=p_class_id and e.academic_year_id=v_s.academic_year_id and e.status='active' and s.status='active'
 and not exists(select 1 from public.school_fee_accounts a where a.school_id=p_school_id and a.student_id=e.student_id and a.academic_year_id=v_s.academic_year_id and a.term_id is not distinct from v_s.term_id and a.fee_name=v_s.fee_name);
 get diagnostics v_inserted=row_count;
 return jsonb_build_object('created_accounts',v_inserted,'fee_name',v_s.fee_name,'class_id',p_class_id);
end $$;
revoke all on function public.manage_school_fee_structure(uuid,jsonb,uuid) from public,anon;
grant execute on function public.manage_school_fee_structure(uuid,jsonb,uuid) to authenticated;
revoke all on function public.apply_school_fee_structure_to_class(uuid,uuid,uuid) from public,anon;
grant execute on function public.apply_school_fee_structure_to_class(uuid,uuid,uuid) to authenticated;
