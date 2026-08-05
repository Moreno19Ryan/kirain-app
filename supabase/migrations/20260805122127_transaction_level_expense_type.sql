-- Wajib/Keinginan is set per transaction (overridable), not locked to the
-- category. The app pre-fills this from the chosen category's expense_type
-- as a sane default, but the value actually saved is always explicit.
alter table public.transactions
  add column expense_type expense_type;
