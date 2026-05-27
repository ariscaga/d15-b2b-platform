-- Users table — anchors all auth, role assigned server-side only
create type user_role as enum ('enterprise', 'contributor', 'admin');

create table public.users (
  id uuid references auth.users(id) on delete cascade primary key,
  email text not null unique,
  role user_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Auto-update updated_at
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger users_updated_at
  before update on public.users
  for each row execute function public.handle_updated_at();
