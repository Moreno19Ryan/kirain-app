create type recurrence_frequency as enum ('weekly', 'monthly');

create table public.recurring_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  amount numeric(14,2) not null check (amount > 0),
  note text,
  expense_type expense_type not null,
  frequency recurrence_frequency not null,
  next_due_date date not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index recurring_transactions_user_id_idx on public.recurring_transactions(user_id);
create index recurring_transactions_category_id_idx on public.recurring_transactions(category_id);

alter table public.recurring_transactions enable row level security;

create policy "own recurring transactions" on public.recurring_transactions for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
