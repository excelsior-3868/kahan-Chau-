-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. Users Table (extends Supabase auth.users)
create table public.users (
  id uuid references auth.users on delete cascade not null primary key,
  display_name text,
  email text,
  is_sharing boolean default false,
  last_location jsonb,
  updated_at timestamptz default now()
);

-- 2. Groups Table
create table public.groups (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  owner_id uuid references public.users on delete cascade not null,
  invite_code text unique default substr(md5(random()::text), 1, 6),
  created_at timestamptz default now()
);

-- 3. Group Members Table
create table public.group_members (
  group_id uuid references public.groups on delete cascade not null,
  user_id uuid references public.users on delete cascade not null,
  role text default 'member' check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz default now(),
  primary key (group_id, user_id)
);

-- 4. Locations Table (For Realtime tracking)
create table public.locations (
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
create policy "Users can view members of their groups" on public.users
  for select using (
    id = auth.uid() or
    id in (select user_id from public.group_members where group_id in (select public.get_my_group_ids()))
  );

create policy "Users can update their own data" on public.users
  for update using (id = auth.uid());

create policy "Users can insert their own profile" on public.users
  for insert with check (id = auth.uid());

-- GROUPS
create policy "Users can view their own or member groups" on public.groups
  for select using (
    owner_id = auth.uid() or
    id in (select public.get_my_group_ids())
  );

create policy "Users can create groups" on public.groups
  for insert with check (owner_id = auth.uid());

-- GROUP MEMBERS
create policy "Members can view group members" on public.group_members
  for select using (
    user_id = auth.uid() or
    group_id in (select public.get_my_group_ids())
  );

create policy "Users can join groups" on public.group_members
  for insert with check (user_id = auth.uid());

-- LOCATIONS
create policy "Members can view locations in their groups" on public.locations
  for select using (
    group_id in (select public.get_my_group_ids())
  );

create policy "Users can insert/update their own locations" on public.locations
  for all using (user_id = auth.uid());

-- Enable Realtime for locations and users
alter publication supabase_realtime add table public.locations;
alter publication supabase_realtime add table public.users;

-- Trigger to automatically create a user profile when a new user signs up
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
