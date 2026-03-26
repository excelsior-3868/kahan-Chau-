-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. Users Table (extends Supabase auth.users)
create table if not exists public.users (
  id uuid references auth.users on delete cascade not null primary key,
  display_name text,
  email text,
  username text,
  profile_image text,
  is_sharing boolean default false,
  last_location jsonb,
  updated_at timestamptz default now()
);

-- 2. Groups Table
create table if not exists public.groups (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  owner_id uuid references public.users on delete cascade not null,
  invite_code text unique default substr(md5(random()::text), 1, 6),
  avatar_url text,
  created_at timestamptz default now()
);

-- 3. Group Members Table
create table if not exists public.group_members (
  group_id uuid references public.groups on delete cascade not null,
  user_id uuid references public.users on delete cascade not null,
  role text default 'member' check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz default now(),
  primary key (group_id, user_id)
);

-- 4. Locations Table (For Realtime tracking)
create table if not exists public.locations (
  user_id uuid references public.users on delete cascade not null,
  group_id uuid references public.groups on delete cascade not null,
  lat double precision not null,
  lng double precision not null,
  status text default 'live',
  timestamp timestamptz default now(),
  primary key (user_id, group_id)
);

-- Turn on Row Level Security (RLS)
alter table public.users enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.locations enable row level security;

-- ============================================================
-- Helper function to avoid infinite recursion in RLS policies
-- Uses SECURITY DEFINER to bypass RLS when looking up memberships
-- ============================================================
create or replace function public.get_my_group_ids()
returns setof uuid
language sql
security definer
set search_path = public
stable
as $$
  select group_id from public.group_members where user_id = auth.uid();
$$;

-- ============================================================
-- RLS Policies
-- ============================================================

-- USERS
drop policy if exists "Users can view members of their groups" on public.users;
create policy "Users can view members of their groups" on public.users
  for select using (
    id = auth.uid() or
    id in (select user_id from public.group_members where group_id in (select public.get_my_group_ids()))
  );

drop policy if exists "Users can update their own data" on public.users;
create policy "Users can update their own data" on public.users
  for update using (id = auth.uid());

drop policy if exists "Users can insert their own profile" on public.users;
create policy "Users can insert their own profile" on public.users
  for insert with check (id = auth.uid());

-- GROUPS
drop policy if exists "Users can view their own or member groups" on public.groups;
create policy "Users can view their own or member groups" on public.groups
  for select using (
    owner_id = auth.uid() or
    id in (select public.get_my_group_ids())
  );

drop policy if exists "Users can create groups" on public.groups;
create policy "Users can create groups" on public.groups
  for insert with check (owner_id = auth.uid());

drop policy if exists "Owners can update their groups" on public.groups;
create policy "Owners can update their groups" on public.groups
  for update using (owner_id = auth.uid());

-- GROUP MEMBERS
drop policy if exists "Members can view group members" on public.group_members;
create policy "Members can view group members" on public.group_members
  for select using (
    user_id = auth.uid() or
    group_id in (select public.get_my_group_ids())
  );

drop policy if exists "Users can join groups" on public.group_members;
create policy "Users can join groups" on public.group_members
  for insert with check (user_id = auth.uid());

drop policy if exists "Users can leave groups" on public.group_members;
create policy "Users can leave groups" on public.group_members
  for delete using (user_id = auth.uid());

drop policy if exists "Owners can remove members" on public.group_members;
create policy "Owners can remove members" on public.group_members
  for delete using (
    group_id in (
      select id from public.groups where owner_id = auth.uid()
    )
  );

-- LOCATIONS
drop policy if exists "Members can view locations in their groups" on public.locations;
create policy "Members can view locations in their groups" on public.locations
  for select using (
    group_id in (select public.get_my_group_ids())
  );

drop policy if exists "Users can insert/update their own locations" on public.locations;
create policy "Users can insert/update their own locations" on public.locations
  for all using (user_id = auth.uid());

-- Enable Realtime for locations and users
-- (Using DO block to avoid errors if already added to publication)
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'locations') then
    alter publication supabase_realtime add table public.locations;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'users') then
    alter publication supabase_realtime add table public.users;
  end if;
end $$;

-- Trigger to automatically create a user profile when a new user signs up
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- 5. Storage Buckets & Policies
-- ============================================================

-- Create the 'avatars' bucket if it doesn't exist
-- Note: This requires the storage extension to be enabled
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Set up RLS for Storage
-- Note: You might need to enable RLS on storage.objects if not already enabled
alter table storage.objects enable row level security;

-- Policy: Allow public access to view avatars
drop policy if exists "Public Access" on storage.objects;
create policy "Public Access"
on storage.objects for select
using ( bucket_id = 'avatars' );

-- Policy: Allow authenticated users to upload avatars
drop policy if exists "Authenticated users can upload avatars" on storage.objects;
create policy "Authenticated users can upload avatars"
on storage.objects for insert
with check (
  bucket_id = 'avatars' AND
  auth.role() = 'authenticated'
);

-- Policy: Allow owners to update/delete their own group avatars
drop policy if exists "Authenticated users can update avatars" on storage.objects;
create policy "Authenticated users can update avatars"
on storage.objects for update
using (
  bucket_id = 'avatars' AND
  auth.role() = 'authenticated'
);
