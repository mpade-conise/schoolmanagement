create or replace function public.apply_school_fee_structure_to_class(p_school_id uuid,p_structure_id uuid,p_class_id uuid)
returns jsonb language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_s public.school_fee_structures%rowtype; v_inserted integer;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','bursar']::text[]) then raise exception 'Only authorised finance staff can apply fee structures'; end if;
 select * into v_s from public.school_fee_structures where id=p_structure_id and school_id=p_school_id and is_active for update;
 if not found then raise exception 'Active fee structure not found'; end if;
 if v_s.is_optional then raise exception 'Optional fee structures must be assigned to selected students individually, not applied to an entire class'; end if;
 if not exists(select 1 from public.classes c where c.id=p_class_id and c.school_id=p_school_id and c.academic_year_id=v_s.academic_year_id and c.is_active and (v_s.class_id is null or v_s.class_id=c.id) and (v_s.grade_level_id is null or v_s.grade_level_id=c.grade_level_id)) then raise exception 'Class does not match this fee structure'; end if;
 insert into public.school_fee_accounts(school_id,student_id,academic_year_id,term_id,fee_name,amount,discount_amount,due_date,created_by)
 select p_school_id,e.student_id,v_s.academic_year_id,v_s.term_id,v_s.fee_name,v_s.amount,0,v_s.due_date,auth.uid()
 from public.student_enrollments e join public.students s on s.id=e.student_id and s.school_id=p_school_id
 where e.school_id=p_school_id and e.class_id=p_class_id and e.academic_year_id=v_s.academic_year_id and e.status='active' and s.status='active'
 and not exists(select 1 from public.school_fee_accounts a where a.school_id=p_school_id and a.student_id=e.student_id and a.academic_year_id=v_s.academic_year_id and a.term_id is not distinct from v_s.term_id and a.fee_name=v_s.fee_name);
 get diagnostics v_inserted=row_count;
 return jsonb_build_object('created_accounts',v_inserted,'fee_name',v_s.fee_name,'class_id',p_class_id);
end $$;
revoke all on function public.apply_school_fee_structure_to_class(uuid,uuid,uuid) from public,anon;
grant execute on function public.apply_school_fee_structure_to_class(uuid,uuid,uuid) to authenticated;