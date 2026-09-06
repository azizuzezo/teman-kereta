-- Once a user sets their username, it cannot be changed again via the
-- normal authenticated app path (only display_name stays editable).
-- Bypassed only for service-role/direct-SQL fixes (auth.uid() is null
-- outside a PostgREST-authenticated request).

create or replace function public.prevent_username_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if old.username is not null
     and new.username is distinct from old.username
     and auth.uid() is not null then
    raise exception 'Username tidak dapat diubah setelah ditetapkan.';
  end if;
  return new;
end;
$$;

create trigger users_prevent_username_change
  before update on public.users
  for each row execute function public.prevent_username_change();
