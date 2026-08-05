create table public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  target_amount numeric(14,2) not null check (target_amount > 0),
  current_amount numeric(14,2) not null default 0 check (current_amount >= 0),
  is_emergency_fund boolean not null default false,
  priority_order int not null default 0,
  target_date date,
  created_at timestamptz not null default now()
);

create index savings_goals_user_id_idx on public.savings_goals(user_id);

alter table public.savings_goals enable row level security;

create policy "own savings goals" on public.savings_goals for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
