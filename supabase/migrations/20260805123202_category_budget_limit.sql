-- Per-category spending limit for the current budget cycle. Null means the
-- user hasn't set one yet; the dashboard treats that category as unbudgeted.
alter table public.categories
  add column budget_limit numeric(14,2) check (budget_limit is null or budget_limit >= 0);
