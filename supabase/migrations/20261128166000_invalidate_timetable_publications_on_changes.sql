create or replace function private.invalidate_timetable_publication() returns trigger language plpgsql security definer set search_path=public,private as $$
begin
 if tg_op in ('UPDATE','DELETE') then update public.school_timetable_publications set is_published=false,updated_at=now() where school_id=old.school_id and academic_year_id=old.academic_year_id and class_id=old.class_id and is_published;end if;
 if tg_op in ('INSERT','UPDATE') then update public.school_timetable_publications set is_published=false,updated_at=now() where school_id=new.school_id and academic_year_id=new.academic_year_id and class_id=new.class_id and is_published;end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
create trigger invalidate_timetable_publication after insert or update or delete on public.school_timetable_entries for each row execute function private.invalidate_timetable_publication();
create or replace function private.invalidate_timetable_publications_for_period() returns trigger language plpgsql security definer set search_path=public,private as $$
begin
 if tg_op in ('UPDATE','DELETE') then update public.school_timetable_publications set is_published=false,updated_at=now() where school_id=old.school_id and academic_year_id=old.academic_year_id and is_published;end if;
 if tg_op in ('INSERT','UPDATE') then update public.school_timetable_publications set is_published=false,updated_at=now() where school_id=new.school_id and academic_year_id=new.academic_year_id and is_published;end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
create trigger invalidate_timetable_publications_for_period after insert or update or delete on public.school_timetable_periods for each row execute function private.invalidate_timetable_publications_for_period();
