-- Task revision history
-- Created when enterprise resubmits after Gate 1 revision_needed decision

create table public.task_revisions (
  id uuid primary key default gen_random_uuid(),
  task_id uuid references public.tasks(id) on delete cascade not null,
  revision_number integer not null default 1,

  -- What changed
  previous_instructions text,
  revised_instructions text,
  previous_compensation numeric(10,2),
  revised_compensation numeric(10,2),
  revision_notes text,             -- enterprise's note on what they changed and why

  -- Re-review result
  review_id uuid references public.task_quality_reviews(id) on delete set null,

  created_at timestamptz not null default now()
);

create index task_revisions_task_id_idx on public.task_revisions(task_id);
