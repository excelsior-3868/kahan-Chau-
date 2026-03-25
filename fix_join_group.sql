-- ============================================================
-- RUN THIS IN SUPABASE SQL EDITOR
-- Adds a server-side function for joining groups by invite code
-- This bypasses RLS so users can look up groups they're not in yet
-- ============================================================

create or replace function public.join_group_by_code(code text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  found_group_id uuid;
  found_group_name text;
  already_member boolean;
begin
  -- Find the group by invite code
  select id, name into found_group_id, found_group_name
  from public.groups
  where invite_code = lower(code);

  if found_group_id is null then
    return json_build_object('status', 'error', 'message', 'Invalid invite code');
  end if;

  -- Check if already a member
  select exists(
    select 1 from public.group_members
    where group_id = found_group_id and user_id = auth.uid()
  ) into already_member;

  if already_member then
    return json_build_object('status', 'ok', 'message', 'Already a member');
  end if;

  -- Join the group
  insert into public.group_members (group_id, user_id, role)
  values (found_group_id, auth.uid(), 'member');

  return json_build_object(
    'status', 'ok',
    'message', 'Joined successfully',
    'group_id', found_group_id,
    'group_name', found_group_name
  );
end;
$$;
