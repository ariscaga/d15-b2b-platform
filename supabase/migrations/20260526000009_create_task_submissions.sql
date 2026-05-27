-- Task submissions — contributor outputs
-- Exists on B2B side even before contributor portal is built
-- MVP: populated via mock_submission_generator Edge Function for demo purposes

create type submission_status as enum (
  'submitted',         -- contributor submitted, awaiting Gate 2
  'mcga_reviewing',    -- MCGA cross-check in progress
  'approved',          -- passed Gate 2, included in deliverable
  'rejected',          -- failed Gate 2, returned to contributor
  'mock'               -- seeded demo data, not real submission
);

create table public.task_submissions (
  id uuid primary key default gen_random_uuid(),
  task_id uuid references public.tasks(id) on delete cascade not null,
  contributor_id uuid references public.users(id) on delete set null,

  -- Submission content
  content jsonb not null,                    -- flexible: {text, rating, audio_url, annotations}
  completion_time_seconds integer,           -- how long contributor took

  -- Quality signals for MCGA
  submission_status submission_status not null default 'submitted',
  mcga_score numeric(5,2),                   -- 0-100, MCGA quality score
  mcga_flags jsonb,                          -- [{flag_type, description, severity}]
  mcga_notes text,                           -- MCGA cross-check notes

  -- Admin Gate 2 manual review
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  review_notes text,

  -- Payout tracking
  payout_amount numeric(10,2),
  payout_triggered boolean not null default false,
  payout_triggered_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger task_submissions_updated_at
  before update on public.task_submissions
  for each row execute function public.handle_updated_at();

create index task_submissions_task_id_idx on public.task_submissions(task_id);
create index task_submissions_contributor_id_idx on public.task_submissions(contributor_id);
create index task_submissions_status_idx on public.task_submissions(submission_status);
