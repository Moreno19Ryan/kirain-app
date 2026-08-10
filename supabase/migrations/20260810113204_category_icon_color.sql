-- Optional icon/color override for user-created custom categories (CLAUDE.md
-- "Kustomisasi Icon & Warna Kategori"). Null means the category falls back to
-- the existing name/kind-based categoryIcon()/categoryIconColor() mapping in
-- the app — the 14 default categories are never expected to set these.
--
-- Values are keys into curated lists maintained in
-- lib/features/categories/data/category_style_options.dart, not free-form:
-- icon is a curated icon key (~20-30 options), color is a hex from a curated
-- preset palette (~6-8 swatches) harmonious with the mint/coral brand. That
-- curation happens at the UI layer (picker only offers curated values), so no
-- DB-level check constraint duplicates it here.
alter table public.categories
  add column icon text,
  add column color text;
