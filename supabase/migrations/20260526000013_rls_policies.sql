-- Row Level Security policies for all tables
-- Security model:
--   Enterprise: sees only own data
--   Contributor: sees only own data (contributor portal, not B2B)
--   Admin: sees everything
--   Service role: bypasses RLS (Edge Functions only)

-- Helper function: get current user's role
create or replace function public.current_user_role()
returns user_role as $$
  select role from public.users where id = auth.uid();
$$ language sql security definer stable;

-- Helper function: get current user's enterprise_profile id
create or replace function public.current_enterprise_id()
returns uuid as $$
  select id from public.enterprise_profiles where user_id = auth.uid();
$$ language sql security definer stable;

-- ============================================================
-- users
-- ============================================================
alter table public.users enable row level security;

create policy "users: own record only"
  on public.users for select
  using (id = auth.uid());

create policy "users: admin sees all"
  on public.users for select
  using (public.current_user_role() = 'admin');

create policy "users: no direct insert (trigger only)"
  on public.users for insert
  with check (false);

create policy "users: own record update"
  on public.users for update
  using (id = auth.uid());

-- ============================================================
-- enterprise_profiles
-- ============================================================
alter table public.enterprise_profiles enable row level security;

create policy "enterprise_profiles: own record only"
  on public.enterprise_profiles for select
  using (user_id = auth.uid());

create policy "enterprise_profiles: admin sees all"
  on public.enterprise_profiles for select
  using (public.current_user_role() = 'admin');

create policy "enterprise_profiles: no direct insert (edge function only)"
  on public.enterprise_profiles for insert
  with check (false);

create policy "enterprise_profiles: own record update"
  on public.enterprise_profiles for update
  using (user_id = auth.uid());

-- ============================================================
-- mia_sessions
-- ============================================================
alter table public.mia_sessions enable row level security;

create policy "mia_sessions: own enterprise only"
  on public.mia_sessions for select
  using (enterprise_id = public.current_enterprise_id());

create policy "mia_sessions: admin sees all"
  on public.mia_sessions for select
  using (public.current_user_role() = 'admin');

create policy "mia_sessions: own enterprise insert"
  on public.mia_sessions for insert
  with check (enterprise_id = public.current_enterprise_id());

create policy "mia_sessions: own enterprise update"
  on public.mia_sessions for update
  using (enterprise_id = public.current_enterprise_id());

-- ============================================================
-- tasks
-- ============================================================
alter table public.tasks enable row level security;

create policy "tasks: own enterprise only"
  on public.tasks for select
  using (enterprise_id = public.current_enterprise_id());

create policy "tasks: admin sees all"
  on public.tasks for select
  using (public.current_user_role() = 'admin');

create policy "tasks: own enterprise insert"
  on public.tasks for insert
  with check (enterprise_id = public.current_enterprise_id());

create policy "tasks: own enterprise update"
  on public.tasks for update
  using (enterprise_id = public.current_enterprise_id());

-- ============================================================
-- task_quality_reviews
-- ============================================================
alter table public.task_quality_reviews enable row level security;

create policy "task_quality_reviews: enterprise sees own task reviews"
  on public.task_quality_reviews for select
  using (
    task_id in (
      select id from public.tasks
      where enterprise_id = public.current_enterprise_id()
    )
  );

create policy "task_quality_reviews: admin sees all"
  on public.task_quality_reviews for select
  using (public.current_user_role() = 'admin');

create policy "task_quality_reviews: admin insert only"
  on public.task_quality_reviews for insert
  with check (public.current_user_role() = 'admin');

-- ============================================================
-- task_revisions
-- ============================================================
alter table public.task_revisions enable row level security;

create policy "task_revisions: enterprise sees own"
  on public.task_revisions for select
  using (
    task_id in (
      select id from public.tasks
      where enterprise_id = public.current_enterprise_id()
    )
  );

create policy "task_revisions: admin sees all"
  on public.task_revisions for select
  using (public.current_user_role() = 'admin');

create policy "task_revisions: enterprise insert own"
  on public.task_revisions for insert
  with check (
    task_id in (
      select id from public.tasks
      where enterprise_id = public.current_enterprise_id()
    )
  );

-- ============================================================
-- task_submissions
-- ============================================================
alter table public.task_submissions enable row level security;

-- Enterprise sees submissions on their own tasks (read only — they don't write submissions)
create policy "task_submissions: enterprise sees own task submissions"
  on public.task_submissions for select
  using (
    task_id in (
      select id from public.tasks
      where enterprise_id = public.current_enterprise_id()
    )
  );

-- Contributor sees only their own submissions
create policy "task_submissions: contributor sees own"
  on public.task_submissions for select
  using (contributor_id = auth.uid());

create policy "task_submissions: admin sees all"
  on public.task_submissions for select
  using (public.current_user_role() = 'admin');

create policy "task_submissions: contributor insert own"
  on public.task_submissions for insert
  with check (contributor_id = auth.uid());

create policy "task_submissions: admin update (Gate 2 review)"
  on public.task_submissions for update
  using (public.current_user_role() = 'admin');

-- ============================================================
-- processed_deliverables
-- ============================================================
alter table public.processed_deliverables enable row level security;

create policy "processed_deliverables: own enterprise only"
  on public.processed_deliverables for select
  using (enterprise_id = public.current_enterprise_id());

create policy "processed_deliverables: admin sees all"
  on public.processed_deliverables for select
  using (public.current_user_role() = 'admin');

create policy "processed_deliverables: admin insert"
  on public.processed_deliverables for insert
  with check (public.current_user_role() = 'admin');

create policy "processed_deliverables: admin update"
  on public.processed_deliverables for update
  using (public.current_user_role() = 'admin');

-- ============================================================
-- delivery_logs
-- ============================================================
alter table public.delivery_logs enable row level security;

create policy "delivery_logs: own enterprise only"
  on public.delivery_logs for select
  using (enterprise_id = public.current_enterprise_id());

create policy "delivery_logs: admin sees all"
  on public.delivery_logs for select
  using (public.current_user_role() = 'admin');

-- ============================================================
-- transactions
-- ============================================================
alter table public.transactions enable row level security;

create policy "transactions: enterprise sees own"
  on public.transactions for select
  using (enterprise_id = public.current_enterprise_id());

create policy "transactions: contributor sees own"
  on public.transactions for select
  using (contributor_id = auth.uid());

create policy "transactions: admin sees all"
  on public.transactions for select
  using (public.current_user_role() = 'admin');

create policy "transactions: no direct insert (edge function only)"
  on public.transactions for insert
  with check (false);
