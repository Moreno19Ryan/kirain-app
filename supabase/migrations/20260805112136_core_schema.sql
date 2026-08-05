create extension if not exists pgcrypto;

create type category_kind as enum ('expense', 'income');
create type expense_type as enum ('wajib', 'keinginan');

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  kind category_kind not null,
  expense_type expense_type,
  alert_threshold_pct int not null default 80,
  created_at timestamptz not null default now(),
  constraint expense_type_required check (
    (kind = 'expense' and expense_type is not null) or
    (kind = 'income' and expense_type is null)
  )
);

create table public.budget_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  cycle_start_day int not null default 1 check (cycle_start_day between 1 and 31),
  rollover_enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  amount numeric(14,2) not null check (amount > 0),
  note text,
  transaction_date date not null default current_date,
  created_at timestamptz not null default now()
);

create index categories_user_id_idx on public.categories(user_id);
create index transactions_category_id_idx on public.transactions(category_id);
create index transactions_user_id_idx on public.transactions(user_id);

alter table public.categories enable row level security;
alter table public.budget_settings enable row level security;
alter table public.transactions enable row level security;

create policy "own categories" on public.categories for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own budget settings" on public.budget_settings for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own transactions" on public.transactions for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Seeds default categories + a budget_settings row whenever a new user signs up.
-- SECURITY DEFINER is required so it can insert on the new user's behalf from
-- the auth.users trigger context; EXECUTE is revoked from anon/authenticated
-- below so it can't be called directly through the exposed REST API.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.budget_settings (user_id) values (new.id);

  insert into public.categories (user_id, name, kind, expense_type) values
    (new.id, 'Makan & Minum', 'expense', 'wajib'),
    (new.id, 'Transportasi', 'expense', 'wajib'),
    (new.id, 'Tempat Tinggal', 'expense', 'wajib'),
    (new.id, 'Tagihan', 'expense', 'wajib'),
    (new.id, 'Infak/Zakat', 'expense', 'wajib'),
    (new.id, 'Kesehatan', 'expense', 'wajib'),
    (new.id, 'Jajan & Nongkrong', 'expense', 'keinginan'),
    (new.id, 'Hiburan', 'expense', 'keinginan'),
    (new.id, 'Belanja', 'expense', 'keinginan'),
    (new.id, 'Hobi', 'expense', 'keinginan'),
    (new.id, 'Gaji', 'income', null),
    (new.id, 'Freelance/Sampingan', 'income', null),
    (new.id, 'THR/Bonus', 'income', null),
    (new.id, 'Lainnya', 'income', null);

  return new;
end;
$$ language plpgsql security definer set search_path = public;

revoke execute on function public.handle_new_user() from public;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
