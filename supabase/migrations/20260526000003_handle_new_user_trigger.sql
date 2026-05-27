-- Auto-create public.users record on auth signup
-- Role MUST be passed in raw_user_meta_data by the server — never trusted from client
create or replace function public.handle_new_user()
returns trigger as $$
declare
  user_role_value user_role;
begin
  -- Extract role from metadata, default to enterprise if not set
  -- Role is always set server-side by Edge Functions, never by client
  user_role_value := coalesce(
    (new.raw_user_meta_data->>'role')::user_role,
    'enterprise'::user_role
  );

  insert into public.users (id, email, role)
  values (
    new.id,
    new.email,
    user_role_value
  );

  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
