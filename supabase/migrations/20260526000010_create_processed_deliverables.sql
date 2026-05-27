-- Processed deliverables — what the enterprise sees in their dashboard
-- Post-MCGA, post-Gate-2, ready for enterprise consumption

create type deliverable_status as enum (
  'processing',        -- MCGA running, not ready yet
  'ready',             -- available in dashboard
  'exported',          -- enterprise downloaded CSV/JSON
  'pushed',            -- V2: pushed to integration endpoint
  'archived'
);

create table public.processed_deliverables (
  id uuid primary key default gen_random_uuid(),
  task_id uuid references public.tasks(id) on delete cascade not null unique,
  enterprise_id uuid references public.enterprise_profiles(id) on delete cascade not null,

  -- Core data
  approved_submission_ids jsonb not null default '[]',   -- array of task_submission ids included
  total_submissions integer not null default 0,
  approved_submissions integer not null default 0,

  -- Intelligence dashboard fields
  -- MVP: IAA + demographics real calculations
  -- MVP: MIA flags + summary populated manually via admin, activate automated in V2
  iaa_score numeric(5,2),                    -- inter-annotator agreement 0-100
  iaa_breakdown jsonb,                       -- per-task-type IAA detail
  demographic_distribution jsonb,            -- {age_ranges, geographies, languages, experience_levels}
  output_size_bytes bigint,

  -- MIA intelligence layer (manual for MVP, automated in V2)
  mia_flags jsonb,                           -- [{flag_type, description, severity, affected_submission_count}]
  mia_summary text,                          -- generated summary of what the dataset contains
  mia_recommendations jsonb,                 -- what enterprise should consider before training

  -- Delivery
  deliverable_status deliverable_status not null default 'processing',
  export_url text,                           -- signed Supabase storage URL for CSV/JSON download
  integration_push_url text,                 -- V2: where data was pushed
  integration_pushed_at timestamptz,

  -- Timestamps
  ready_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger processed_deliverables_updated_at
  before update on public.processed_deliverables
  for each row execute function public.handle_updated_at();

create index processed_deliverables_task_id_idx on public.processed_deliverables(task_id);
create index processed_deliverables_enterprise_id_idx on public.processed_deliverables(enterprise_id);
create index processed_deliverables_status_idx on public.processed_deliverables(deliverable_status);
