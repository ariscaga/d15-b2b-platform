-- MIA intake sessions
-- One session per task request — stores the full conversation and generated task design
-- This is the CCF artifact for the enterprise customer

create type mia_session_status as enum ('in_progress', 'completed', 'abandoned');

create table public.mia_sessions (
  id uuid primary key default gen_random_uuid(),
  enterprise_id uuid references public.enterprise_profiles(id) on delete cascade not null,

  -- Conversation storage
  messages jsonb not null default '[]',       -- full message history [{role, content, timestamp}]
  session_status mia_session_status not null default 'in_progress',

  -- CCF output — what MIA extracted from the conversation
  ccf_context jsonb,                          -- context conditioning frame built from session
  model_goals_extracted jsonb,               -- goals MIA identified from conversation
  performance_gaps_extracted jsonb,          -- gaps MIA identified
  suggested_task_design jsonb,               -- MIA-generated task structure

  -- Linking — set when enterprise approves the MIA-generated task design
  resulting_task_id uuid,                    -- FK added after tasks table exists

  -- Metadata
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger mia_sessions_updated_at
  before update on public.mia_sessions
  for each row execute function public.handle_updated_at();

create index mia_sessions_enterprise_id_idx on public.mia_sessions(enterprise_id);
create index mia_sessions_status_idx on public.mia_sessions(session_status);
