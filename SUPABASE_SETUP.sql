-- ══════════════════════════════════════════════════════════
--  MESSAGES APP — Supabase SQL Setup
--  Run this in: Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════

-- 1. PROFILES TABLE (links to auth.users)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  display_name text,
  updated_at timestamptz default now()
);
alter table public.profiles enable row level security;
create policy "Anyone authenticated can view profiles"
  on public.profiles for select using (auth.role() = 'authenticated');
create policy "Users can insert own profile"
  on public.profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

-- Auto-create profile on new user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data->>'display_name')
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- 2. MESSAGES TABLE
create table if not exists public.messages (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references auth.users on delete cascade not null,
  receiver_id uuid references auth.users on delete cascade not null,
  content text not null check (char_length(content) > 0 and char_length(content) <= 4000),
  created_at timestamptz default now(),
  read_at timestamptz
);
alter table public.messages enable row level security;

-- Users can only see messages they sent or received
create policy "Users can view their own messages"
  on public.messages for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Users can only send messages as themselves
create policy "Users can send messages"
  on public.messages for insert
  with check (auth.uid() = sender_id);

-- Receivers can mark messages as read
create policy "Receivers can mark messages read"
  on public.messages for update
  using (auth.uid() = receiver_id);

-- Index for fast conversation queries
create index if not exists messages_sender_receiver_idx
  on public.messages (sender_id, receiver_id, created_at desc);
create index if not exists messages_receiver_unread_idx
  on public.messages (receiver_id, read_at) where read_at is null;


-- 3. ENABLE REALTIME for messages table
-- Go to: Supabase Dashboard → Database → Replication
-- And enable replication for the "messages" table
-- OR run:
alter publication supabase_realtime add table public.messages;
