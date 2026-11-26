-- Endurecer el trigger de alta y declarar exposición de Data API explícitamente.
drop trigger if exists on_auth_user_created_cerca on auth.users;
drop function if exists public.handle_new_user();

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name',''));
  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created_cerca
after insert on auth.users
for each row execute function private.handle_new_user();

grant usage on schema public to anon, authenticated;
