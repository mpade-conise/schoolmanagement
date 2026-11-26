create table if not exists public.school_fee_accounts(
 id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id) on delete cascade,student_id uuid not null,academic_year_id uuid not null,term_id uuid,fee_name text not null check(length(trim(fee_name)) between 2 and 120),amount numeric(12,2) not null check(amount>0),discount_amount numeric(12,2) not null default 0 check(discount_amount>=0 and discount_amount<=amount),due_date date,created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(school_id,id),foreign key(school_id,student_id) references public.students(school_id,id) on delete cascade,foreign key(school_id,academic_year_id) references public.academic_years(school_id,id),foreign key(school_id,term_id) references public.terms(school_id,id)
);
create index if not exists school_fee_accounts_student_idx on public.school_fee_accounts(school_id,student_id,academic_year_id);
create table if not exists public.school_fee_payments(
 id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id) on delete cascade,account_id uuid not null,amount numeric(12,2) not null check(amount>0),payment_method text not null check(payment_method in ('cash','mobile_money','bank_transfer','cheque','other')),reference text,receipt_number text not null,received_by uuid not null references auth.users(id),received_at timestamptz not null default now(),foreign key(school_id,account_id) references public.school_fee_accounts(school_id,id) on delete cascade,unique(school_id,receipt_number)
);
create index if not exists school_fee_payments_account_idx on public.school_fee_payments(school_id,account_id,received_at desc);
alter table public.school_fee_accounts enable row level security;
alter table public.school_fee_payments enable row level security;
drop policy if exists school_fee_accounts_read on public.school_fee_accounts;
create policy school_fee_accounts_read on public.school_fee_accounts for select to authenticated using(private.has_school_role(school_id,array['owner','school_admin','bursar','headteacher']::text[]));
drop policy if exists school_fee_payments_read on public.school_fee_payments;
create policy school_fee_payments_read on public.school_fee_payments for select to authenticated using(private.has_school_role(school_id,array['owner','school_admin','bursar','headteacher']::text[]));
revoke insert,update,delete on public.school_fee_accounts from authenticated;
revoke insert,update,delete on public.school_fee_payments from authenticated;
grant select on public.school_fee_accounts,public.school_fee_payments to authenticated;
create or replace function public.manage_school_fee_account(p_school_id uuid,p_payload jsonb,p_account_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_id uuid;v_student uuid;v_year uuid;v_term uuid;v_name text;v_amount numeric;v_discount numeric;v_due date;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','bursar']::text[]) then raise exception 'Only authorised finance staff can manage fee accounts';end if;
 v_student:=(p_payload->>'student_id')::uuid;v_year:=(p_payload->>'academic_year_id')::uuid;v_term:=nullif(p_payload->>'term_id','')::uuid;v_name:=trim(p_payload->>'fee_name');v_amount:=(p_payload->>'amount')::numeric;v_discount:=coalesce(nullif(p_payload->>'discount_amount','')::numeric,0);v_due:=nullif(p_payload->>'due_date','');
 if coalesce(length(v_name),0) not between 2 and 120 or v_amount is null or v_amount<=0 or v_discount<0 or v_discount>v_amount then raise exception 'Enter a valid fee description, amount and discount';end if;
 if not exists(select 1 from public.students s where s.school_id=p_school_id and s.id=v_student and s.status='active') then raise exception 'Student is not active in this school';end if;
 if not exists(select 1 from public.academic_years y where y.school_id=p_school_id and y.id=v_year) then raise exception 'Academic year does not belong to this school';end if;
 if v_term is not null and not exists(select 1 from public.terms t where t.school_id=p_school_id and t.id=v_term and t.academic_year_id=v_year) then raise exception 'Term does not belong to the selected academic year';end if;
 if p_account_id is null then insert into public.school_fee_accounts(school_id,student_id,academic_year_id,term_id,fee_name,amount,discount_amount,due_date,created_by) values(p_school_id,v_student,v_year,v_term,v_name,v_amount,v_discount,v_due,auth.uid()) returning id into v_id;
 else update public.school_fee_accounts set fee_name=v_name,amount=v_amount,discount_amount=v_discount,due_date=v_due,updated_at=now() where school_id=p_school_id and id=p_account_id and not exists(select 1 from public.school_fee_payments p where p.school_id=p_school_id and p.account_id=p_account_id) returning id into v_id;if v_id is null then raise exception 'Fee account cannot be edited after payments have been recorded';end if;end if;
 return v_id;
end $$;
create or replace function public.record_school_fee_payment(p_school_id uuid,p_account_id uuid,p_amount numeric,p_method text,p_reference text default null)
returns jsonb language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_account public.school_fee_accounts%rowtype;v_paid numeric;v_balance numeric;v_receipt text;v_payment uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if not private.has_school_role(p_school_id,array['owner','school_admin','bursar']::text[]) then raise exception 'Only authorised finance staff can record payments';end if;
 if p_amount is null or p_amount<=0 or p_method is null or p_method not in ('cash','mobile_money','bank_transfer','cheque','other') then raise exception 'Enter a valid payment amount and method';end if;
 select * into v_account from public.school_fee_accounts where school_id=p_school_id and id=p_account_id for update;
 if not found then raise exception 'Fee account not found';end if;
 select coalesce(sum(amount),0) into v_paid from public.school_fee_payments where school_id=p_school_id and account_id=p_account_id;
 v_balance:=v_account.amount-v_account.discount_amount-v_paid;
 if p_amount>v_balance then raise exception 'Payment exceeds outstanding balance of %',v_balance;end if;
 v_receipt:='CE-'||to_char(now(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
 insert into public.school_fee_payments(school_id,account_id,amount,payment_method,reference,receipt_number,received_by) values(p_school_id,p_account_id,p_amount,p_method,nullif(trim(p_reference),''),v_receipt,auth.uid()) returning id into v_payment;
 return jsonb_build_object('payment_id',v_payment,'receipt_number',v_receipt,'amount',p_amount,'balance',v_balance-p_amount);
end $$;
revoke all on function public.manage_school_fee_account(uuid,jsonb,uuid) from public,anon;
revoke all on function public.record_school_fee_payment(uuid,uuid,numeric,text,text) from public,anon;
grant execute on function public.manage_school_fee_account(uuid,jsonb,uuid) to authenticated;
grant execute on function public.record_school_fee_payment(uuid,uuid,numeric,text,text) to authenticated;