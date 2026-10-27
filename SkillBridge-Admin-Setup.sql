-- SkillBridge AI: secure single-admin dashboard
-- Run in Supabase SQL Editor AFTER your existing SkillBridge setup.
-- IMPORTANT: Do not add an admin from the browser. The first admin is added
-- manually by the project owner in the SQL Editor after creating their account.

create table if not exists public.skillbridge_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.skillbridge_admins enable row level security;
revoke all on public.skillbridge_admins from anon, authenticated;
grant select on public.skillbridge_admins to authenticated;

drop policy if exists "Admins can read their own admin row" on public.skillbridge_admins;
create policy "Admins can read their own admin row"
on public.skillbridge_admins for select to authenticated
using (user_id = auth.uid());

-- Admin-only RPC: dashboard totals and recent data. SECURITY DEFINER is safe
-- here because each function checks the caller against skillbridge_admins.
create or replace function public.skillbridge_admin_overview()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare result jsonb;
begin
  if auth.uid() is null or not exists (
    select 1 from public.skillbridge_admins a where a.user_id = auth.uid()
  ) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'students', (select count(*) from public.profiles),
    'requests', (select count(*) from public.skill_requests),
    'accepted_requests', (select count(*) from public.skill_requests where status = 'accepted'),
    'pending_requests', (select count(*) from public.skill_requests where status = 'pending'),
    'messages', (select count(*) from public.skill_messages),
    'reviews', (select count(*) from public.skill_reviews),
    'recent_students', coalesce((
      select jsonb_agg(to_jsonb(x)) from (
        select id, name, level, teach, learn, updated_at
        from public.profiles order by updated_at desc nulls last limit 100
      ) x
    ), '[]'::jsonb),
    'recent_reviews', coalesce((
      select jsonb_agg(to_jsonb(x)) from (
        select id, request_id, reviewer_id, reviewee_id, rating, review_text, created_at
        from public.skill_reviews order by created_at desc limit 100
      ) x
    ), '[]'::jsonb),
    'recent_requests', coalesce((
      select jsonb_agg(to_jsonb(x)) from (
        select id, sender_id, receiver_id, status, created_at
        from public.skill_requests order by created_at desc limit 100
      ) x
    ), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;

create or replace function public.skillbridge_admin_delete_review(p_review_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.skillbridge_admins a where a.user_id = auth.uid()
  ) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  delete from public.skill_reviews where id = p_review_id;
  if not found then
    raise exception 'Review not found';
  end if;
  return jsonb_build_object('success', true);
end;
$$;

revoke all on function public.skillbridge_admin_overview() from public, anon;
revoke all on function public.skillbridge_admin_delete_review(uuid) from public, anon;
grant execute on function public.skillbridge_admin_overview() to authenticated;
grant execute on function public.skillbridge_admin_delete_review(uuid) to authenticated;

-- After running this SQL:
-- 1. Sign up/log in to the normal SkillBridge app with your own account.
-- 2. In Supabase SQL Editor run the following, replacing your email:
--    insert into public.skillbridge_admins(user_id)
--    select id from auth.users where lower(email)=lower('YOUR-LOGIN-EMAIL')
--    on conflict (user_id) do nothing;
-- 3. Verify it inserted exactly one row. Never share a service_role key.
