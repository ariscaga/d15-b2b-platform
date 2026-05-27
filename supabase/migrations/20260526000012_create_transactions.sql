-- Transactions — all financial records across both sides of the platform

create type transaction_type as enum (
  'subscription_payment',    -- enterprise subscription charge
  'task_payout',             -- contributor payout
  'platform_fee',            -- D15 platform fee on task
  'dollar_match',            -- contributor Dollar Match deposit
  'refund'
);

create type transaction_status as enum (
  'pending',
  'completed',
  'failed',
  'refunded'
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),

  -- Flexible: either enterprise or contributor side
  enterprise_id uuid references public.enterprise_profiles(id) on delete set null,
  contributor_id uuid references public.users(id) on delete set null,
  task_id uuid references public.tasks(id) on delete set null,
  submission_id uuid references public.task_submissions(id) on delete set null,

  -- Transaction details
  transaction_type transaction_type not null,
  transaction_status transaction_status not null default 'pending',
  amount numeric(10,2) not null,
  currency text not null default 'usd',

  -- Stripe references
  stripe_payment_intent_id text,
  stripe_transfer_id text,
  stripe_invoice_id text,

  -- Metadata
  description text,
  metadata jsonb,

  -- Timestamps
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger transactions_updated_at
  before update on public.transactions
  for each row execute function public.handle_updated_at();

create index transactions_enterprise_id_idx on public.transactions(enterprise_id);
create index transactions_contributor_id_idx on public.transactions(contributor_id);
create index transactions_task_id_idx on public.transactions(task_id);
create index transactions_stripe_payment_intent_idx on public.transactions(stripe_payment_intent_id);
create index transactions_type_idx on public.transactions(transaction_type);
