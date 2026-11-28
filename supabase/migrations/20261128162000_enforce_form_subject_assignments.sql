create or replace function private.validate_subject_against_form() returns trigger language plpgsql security definer set search_path=public,private as $$
declare v_grade uuid; v_mapped integer;
begin
 select c.grade_level_id into v_grade from public.classes c where c.id=new.class_id and c.school_id=new.school_id;
 if v_grade is null then raise exception 'Class must belong to this school'; end if;
 if not exists(select 1 from public.subjects s where s.id=new.subject_id and s.school_id=new.school_id and s.education_level in ('secondary','both')) then raise exception 'Subject must belong to this school'; end if;
 select count(*) into v_mapped from public.grade_subjects gs where gs.school_id=new.school_id and gs.grade_level_id=v_grade;
 if v_mapped>0 and not exists(select 1 from public.grade_subjects gs where gs.school_id=new.school_id and gs.grade_level_id=v_grade and gs.subject_id=new.subject_id) then raise exception 'Subject is not assigned to this form. Configure Subjects by form first.'; end if;
 return new;
end $$;
drop trigger if exists class_subject_form_subject_check on public.class_subjects;
create trigger class_subject_form_subject_check before insert or update of class_id,subject_id,school_id on public.class_subjects for each row execute function private.validate_subject_against_form();
drop trigger if exists exam_subject_form_subject_check on public.school_exam_subjects;
create trigger exam_subject_form_subject_check before insert or update of class_id,subject_id,school_id on public.school_exam_subjects for each row execute function private.validate_subject_against_form();
