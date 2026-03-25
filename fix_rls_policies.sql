-- ============================================================
-- RUN THIS IN SUPABASE SQL EDITOR TO FIX RLS POLICIES
-- Fixes infinite recursion in group_members policy
-- ============================================================

-- Step 1: Create a helper function that bypasses RLS
-- This safely returns the group IDs the current user belongs to
create or replace function public.get_my_group_ids()
returns setof uuid
language sql
security definer
set search_path = public
stable
as $$
  select group_id from public.group_members where user_id = auth.uid();
$$;

-- Step 2: Drop ALL old policies
drop policy if exists "Users can view members of their groups" on public.users;
drop policy if exists "Users can update their own data" on public.users;
drop policy if exists "Users can insert their own profile" on public.users;
drop policy if exists "Members can view their groups" on public.groups;
drop policy if exists "Users can view their own or member groups" on public.groups;
drop policy if exists "Users can create groups" on public.groups;
drop policy if exists "Members can view group members" on public.group_members;
drop policy if exists "Users can join groups" on public.group_members;
drop policy if exists "Members can view locations in their groups" on public.locations;
drop policy if exists "Users can insert/update their own locations" on public.locations;

-- ============================================================
-- Step 3: Recreate all policies using the helper function
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

-- GROUP MEMBERS (no more self-reference!)
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
