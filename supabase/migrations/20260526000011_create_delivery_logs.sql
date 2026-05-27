-- Delivery logs — audit trail for every deliverable action

create type delivery_action as enum (
  'deliverable_created',
  'dashboard_viewed',
  'csv_exported',
  'json_exported',
  'integration_pushed',
  'archived'
);

create table public.delivery_logs (
  id uuid primary key default gen_random_uuid(),
  deliverable_id uuid references public.processed_deliverables(id) on delete cascade not null,
  enterprise_id uuid references public.enterprise_profiles(id) on delete cascade not null,
  performed_by uuid references public.users(id) on delete set null,

  action delivery_action not null,
  metadata jsonb,                            -- {export_format, file_size, push_destination, etc.}

  created_at timestamptz not null default now()
);

create index delivery_logs_deliverable_id_idx on public.delivery_logs(deliverable_id);
create index delivery_logs_enterprise_id_idx on public.delivery_logs(enterprise_id);
