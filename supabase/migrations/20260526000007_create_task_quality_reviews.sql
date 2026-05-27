-- Gate 1 review records
-- Automated checks first, human admin review if flagged

create type review_decision as enum ('approved', 'revision_needed', 'rejected');
create type review_type as enum ('automated', 'manual');

create table public.task_quality_reviews (
  id uuid primary key default gen_random_uuid(),
  task_id uuid references public.tasks(id) on delete cascade not null,
  reviewed_by uuid references public.users(id) on delete set null,  -- null for automated

  review_type review_type not null,
  decision review_decision not null,

  -- Automated check results
  auto_checks jsonb,               -- {instruction_length: pass, compensation_minimum: pass, demographic_fields: pass}

  -- Human review notes
  notes text,
  revision_instructions text,      -- what enterprise needs to fix

  created_at timestamptz not null default now()
);

create index task_quality_reviews_task_id_idx on public.task_quality_reviews(task_id);
