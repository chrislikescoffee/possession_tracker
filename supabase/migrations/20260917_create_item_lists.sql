-- ==============================================================================
-- Migration: Create item_lists table for Lists feature synchronization
-- Execute this script in your Supabase project's SQL Editor:
-- Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

create table if not exists public.item_lists (
  id text primary key,
  library_id text not null references public.libraries(id) on delete cascade,
  name text not null,
  description text,
  destination_type text not null default 'notRelocating',
  target_location_id text references public.storage_locations(id) on delete set null,
  free_text_note text,
  borrower_name text,
  borrower_contact text,
  due_date timestamptz,
  items jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enable Row Level Security (RLS)
alter table public.item_lists enable row level security;

-- Policy to allow full access (matching the library RLS scheme)
create policy "Allow all access to item_lists"
  on public.item_lists
  for all
  using (true)
  with check (true);

-- Enable real-time replication for cross-device live sync
alter publication supabase_realtime add table public.item_lists;
