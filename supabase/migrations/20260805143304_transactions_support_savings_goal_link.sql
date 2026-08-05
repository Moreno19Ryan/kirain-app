-- A transaction can now represent a savings contribution (tied to a goal)
-- instead of a category/expense_type. Exactly one of category_id / goal_id
-- must be set. Savings transactions have expense_type = null and don't
-- count toward the wajib/keinginan budget math.
alter table public.transactions
  alter column category_id drop not null,
  add column goal_id uuid references public.savings_goals(id) on delete restrict,
  add constraint transactions_category_or_goal check (
    (category_id is not null and goal_id is null) or
    (category_id is null and goal_id is not null)
  );

create index transactions_goal_id_idx on public.transactions(goal_id);
