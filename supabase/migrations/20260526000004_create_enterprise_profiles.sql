-- Enterprise profiles
-- Created by Stripe webhook on checkout.session.completed
-- Most fields nullable at creation — populated progressively via MIA intake

create type subscription_tier as enum ('validate_basic', 'validate_pro', 'iterate_basic', 'iterate_pro', 'operate', 'co_develop');
create type subscription_status as enum ('active', 'past_due', 'canceled', 'trialing', 'incomplete');

create table public.enterprise_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade not null unique,

  -- From Stripe checkout — populated at account creation
  name text not null,
  email text not null,
  tier subscription_tier not null,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  subscription_status subscription_status not null default 'incomplete',

  -- Populated during MIA intake
  company_name text,
  industry text,
  model_description text,                    -- what their model does
  model_goals jsonb,                         -- array of model goals from MIA session
  model_performance_gaps jsonb,              -- identified gaps from MIA session
  integration_preferences jsonb,            -- V2: preferred pipeline destinations

  -- App state flags
  has_acknowledged_disclaimer boolean not null default false,
  has_completed_intake boolean not null default false,
  is_demo_account boolean not null default false,

  -- Timestamps
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger enterprise_profiles_updated_at
  before update on public.enterprise_profiles
  for each row execute function public.handle_updated_at();

-- Index for Stripe lookups
create index enterprise_profiles_stripe_customer_id_idx on public.enterprise_profiles(stripe_customer_id);
create index enterprise_profiles_stripe_subscription_id_idx on public.enterprise_profiles(stripe_subscription_id);
create index enterprise_profiles_is_demo_idx on public.enterprise_profiles(is_demo_account);
