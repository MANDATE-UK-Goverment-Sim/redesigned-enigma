-- NEW H Election Night — Supabase realtime setup
-- Run this once in Supabase > SQL Editor.
--
-- IMPORTANT: This is a simple demo/public-broadcast policy so a static GitHub
-- Pages control room can write without a login. Anyone who has your public URL
-- could potentially edit the state. Add Supabase Auth + stricter RLS before
-- using it for a public production control room.

create table if not exists public.live_state (
  id text primary key,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.live_state enable row level security;

grant select, insert, update on public.live_state to anon, authenticated;

drop policy if exists "newh public read" on public.live_state;
create policy "newh public read"
on public.live_state
for select
to anon, authenticated
using (id = 'newh-live');

drop policy if exists "newh public insert" on public.live_state;
create policy "newh public insert"
on public.live_state
for insert
to anon, authenticated
with check (id = 'newh-live');

drop policy if exists "newh public update" on public.live_state;
create policy "newh public update"
on public.live_state
for update
to anon, authenticated
using (id = 'newh-live')
with check (id = 'newh-live');

insert into public.live_state (id, state)
values ('newh-live', '{}'::jsonb)
on conflict (id) do nothing;

do $$
begin
  alter publication supabase_realtime add table public.live_state;
exception
  when duplicate_object then null;
end $$;
