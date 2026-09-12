-- NEW H Election Night — full Supabase setup + SECRET SURPRISE ELECTION ENGINE
-- Run this entire file in Supabase > SQL Editor.
--
-- Surprise mode rules:
--   * All 640 real results are generated and locked in private tables.
--   * The browser cannot SELECT the hidden results.
--   * Only CON, LAB or LD can finish as the largest party.
--   * REF, GRN and UIP can win constituencies, but cannot win the election overall.
--   * The 22:00 exit poll is deliberately generated with a DIFFERENT leading party
--     from the hidden final winner, so the actual result remains a surprise.
--   * Results are revealed one constituency at a time through RPC functions.
--
-- This is still a static GitHub Pages control room using the Supabase anon key.
-- Anyone with access to your control-room page can press its controls, so keep the
-- control-room URL private or add Supabase Auth later if you need real security.

create extension if not exists pgcrypto;

-- Public realtime broadcast state used by the existing presentation.
create table if not exists public.live_state (
  id text primary key,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.live_state enable row level security;
grant select, insert, update on public.live_state to anon, authenticated;

drop policy if exists "newh public read" on public.live_state;
create policy "newh public read" on public.live_state
for select to anon, authenticated using (id = 'newh-live');

drop policy if exists "newh public insert" on public.live_state;
create policy "newh public insert" on public.live_state
for insert to anon, authenticated with check (id = 'newh-live');

drop policy if exists "newh public update" on public.live_state;
create policy "newh public update" on public.live_state
for update to anon, authenticated using (id = 'newh-live') with check (id = 'newh-live');

insert into public.live_state (id, state)
values ('newh-live', '{}'::jsonb)
on conflict (id) do nothing;

do $$
begin
  alter publication supabase_realtime add table public.live_state;
exception when duplicate_object then null;
end $$;

-- Catalogue is server-side metadata for the 640 fictional constituencies.
create table if not exists public.newh_seat_catalogue (
  seat_id text primary key,
  seat_name text not null,
  region_id text not null,
  region_name text not null,
  previous_winner text not null,
  predicted_winner text not null
);

insert into public.newh_seat_catalogue
  (seat_id, seat_name, region_id, region_name, previous_winner, predicted_winner)
values
  ('seat-001','Northmarch Alderwick North','northmarch','Northmarch','lab','lab'),
  ('seat-002','Northmarch Alderwick South','northmarch','Northmarch','con','ld'),
  ('seat-003','Northmarch Alderwick East','northmarch','Northmarch','lab','lab'),
  ('seat-004','Northmarch Alderwick West','northmarch','Northmarch','con','ld'),
  ('seat-005','Northmarch Briarfield North','northmarch','Northmarch','lab','ld'),
  ('seat-006','Northmarch Briarfield South','northmarch','Northmarch','ref','lab'),
  ('seat-007','Northmarch Briarfield East','northmarch','Northmarch','con','ld'),
  ('seat-008','Northmarch Briarfield West','northmarch','Northmarch','grn','lab'),
  ('seat-009','Northmarch Cedarham North','northmarch','Northmarch','con','lab'),
  ('seat-010','Northmarch Cedarham South','northmarch','Northmarch','lab','ld'),
  ('seat-011','Northmarch Cedarham East','northmarch','Northmarch','ld','lab'),
  ('seat-012','Northmarch Cedarham West','northmarch','Northmarch','con','ld'),
  ('seat-013','Northmarch Dunmere North','northmarch','Northmarch','uip','ld'),
  ('seat-014','Northmarch Dunmere South','northmarch','Northmarch','lab','lab'),
  ('seat-015','Northmarch Dunmere East','northmarch','Northmarch','con','ld'),
  ('seat-016','Northmarch Dunmere West','northmarch','Northmarch','lab','lab'),
  ('seat-017','Northmarch Elmstead North','northmarch','Northmarch','ld','lab'),
  ('seat-018','Northmarch Elmstead South','northmarch','Northmarch','lab','ld'),
  ('seat-019','Northmarch Elmstead East','northmarch','Northmarch','ref','lab'),
  ('seat-020','Northmarch Elmstead West','northmarch','Northmarch','con','ld'),
  ('seat-021','Northmarch Foxbridge North','northmarch','Northmarch','lab','ld'),
  ('seat-022','Northmarch Foxbridge South','northmarch','Northmarch','con','lab'),
  ('seat-023','Northmarch Foxbridge East','northmarch','Northmarch','lab','ld'),
  ('seat-024','Northmarch Foxbridge West','northmarch','Northmarch','ld','lab'),
  ('seat-025','Northmarch Glenford North','northmarch','Northmarch','lab','lab'),
  ('seat-026','Northmarch Glenford South','northmarch','Northmarch','uip','ld'),
  ('seat-027','Northmarch Glenford East','northmarch','Northmarch','lab','lab'),
  ('seat-028','Northmarch Glenford West','northmarch','Northmarch','con','ld'),
  ('seat-029','Northmarch Hartwick North','northmarch','Northmarch','con','ld'),
  ('seat-030','Northmarch Hartwick South','northmarch','Northmarch','ld','lab'),
  ('seat-031','Northmarch Hartwick East','northmarch','Northmarch','lab','ld'),
  ('seat-032','Northmarch Hartwick West','northmarch','Northmarch','ref','lab'),
  ('seat-033','Northmarch Ivycross North','northmarch','Northmarch','grn','lab'),
  ('seat-034','Northmarch Ivycross South','northmarch','Northmarch','lab','ld'),
  ('seat-035','Northmarch Ivycross East','northmarch','Northmarch','con','lab'),
  ('seat-036','Northmarch Ivycross West','northmarch','Northmarch','lab','ld'),
  ('seat-037','Northmarch Juniper Bay North','northmarch','Northmarch','con','ld'),
  ('seat-038','Northmarch Juniper Bay South','northmarch','Northmarch','lab','lab'),
  ('seat-039','Northmarch Juniper Bay East','northmarch','Northmarch','uip','ld'),
  ('seat-040','Northmarch Juniper Bay West','northmarch','Northmarch','lab','lab'),
  ('seat-041','Southmarch Alderwick North','southmarch','Southmarch','lab','grn'),
  ('seat-042','Southmarch Alderwick South','southmarch','Southmarch','con','lab'),
  ('seat-043','Southmarch Alderwick East','southmarch','Southmarch','lab','lab'),
  ('seat-044','Southmarch Alderwick West','southmarch','Southmarch','ld','lab'),
  ('seat-045','Southmarch Briarfield North','southmarch','Southmarch','lab','lab'),
  ('seat-046','Southmarch Briarfield South','southmarch','Southmarch','uip','grn'),
  ('seat-047','Southmarch Briarfield East','southmarch','Southmarch','lab','lab'),
  ('seat-048','Southmarch Briarfield West','southmarch','Southmarch','con','lab'),
  ('seat-049','Southmarch Cedarham North','southmarch','Southmarch','con','lab'),
  ('seat-050','Southmarch Cedarham South','southmarch','Southmarch','ld','lab'),
  ('seat-051','Southmarch Cedarham East','southmarch','Southmarch','lab','grn'),
  ('seat-052','Southmarch Cedarham West','southmarch','Southmarch','ref','lab'),
  ('seat-053','Southmarch Dunmere North','southmarch','Southmarch','grn','lab'),
  ('seat-054','Southmarch Dunmere South','southmarch','Southmarch','lab','lab'),
  ('seat-055','Southmarch Dunmere East','southmarch','Southmarch','con','lab'),
  ('seat-056','Southmarch Dunmere West','southmarch','Southmarch','lab','grn'),
  ('seat-057','Southmarch Elmstead North','southmarch','Southmarch','con','grn'),
  ('seat-058','Southmarch Elmstead South','southmarch','Southmarch','lab','lab'),
  ('seat-059','Southmarch Elmstead East','southmarch','Southmarch','uip','lab'),
  ('seat-060','Southmarch Elmstead West','southmarch','Southmarch','lab','lab'),
  ('seat-061','Southmarch Foxbridge North','southmarch','Southmarch','lab','lab'),
  ('seat-062','Southmarch Foxbridge South','southmarch','Southmarch','con','grn'),
  ('seat-063','Southmarch Foxbridge East','southmarch','Southmarch','ld','lab'),
  ('seat-064','Southmarch Foxbridge West','southmarch','Southmarch','lab','lab'),
  ('seat-065','Southmarch Glenford North','southmarch','Southmarch','con','lab'),
  ('seat-066','Southmarch Glenford South','southmarch','Southmarch','grn','lab'),
  ('seat-067','Southmarch Glenford East','southmarch','Southmarch','lab','grn'),
  ('seat-068','Southmarch Glenford West','southmarch','Southmarch','con','lab'),
  ('seat-069','Southmarch Hartwick North','southmarch','Southmarch','ld','lab'),
  ('seat-070','Southmarch Hartwick South','southmarch','Southmarch','con','lab'),
  ('seat-071','Southmarch Hartwick East','southmarch','Southmarch','lab','lab'),
  ('seat-072','Southmarch Hartwick West','southmarch','Southmarch','uip','grn'),
  ('seat-073','Southmarch Ivycross North','southmarch','Southmarch','con','grn'),
  ('seat-074','Southmarch Ivycross South','southmarch','Southmarch','lab','lab'),
  ('seat-075','Southmarch Ivycross East','southmarch','Southmarch','con','lab'),
  ('seat-076','Southmarch Ivycross West','southmarch','Southmarch','ld','lab'),
  ('seat-077','Southmarch Juniper Bay North','southmarch','Southmarch','ref','lab'),
  ('seat-078','Southmarch Juniper Bay South','southmarch','Southmarch','con','grn'),
  ('seat-079','Southmarch Juniper Bay East','southmarch','Southmarch','grn','lab'),
  ('seat-080','Southmarch Juniper Bay West','southmarch','Southmarch','lab','lab'),
  ('seat-081','West Vale Alderwick North','westvale','West Vale','lab','con'),
  ('seat-082','West Vale Alderwick South','westvale','West Vale','con','ref'),
  ('seat-083','West Vale Alderwick East','westvale','West Vale','ld','con'),
  ('seat-084','West Vale Alderwick West','westvale','West Vale','lab','con'),
  ('seat-085','West Vale Briarfield North','westvale','West Vale','con','con'),
  ('seat-086','West Vale Briarfield South','westvale','West Vale','grn','con'),
  ('seat-087','West Vale Briarfield East','westvale','West Vale','lab','ref'),
  ('seat-088','West Vale Briarfield West','westvale','West Vale','con','con'),
  ('seat-089','West Vale Cedarham North','westvale','West Vale','ld','con'),
  ('seat-090','West Vale Cedarham South','westvale','West Vale','con','con'),
  ('seat-091','West Vale Cedarham East','westvale','West Vale','lab','con'),
  ('seat-092','West Vale Cedarham West','westvale','West Vale','uip','ref'),
  ('seat-093','West Vale Dunmere North','westvale','West Vale','con','ref'),
  ('seat-094','West Vale Dunmere South','westvale','West Vale','lab','con'),
  ('seat-095','West Vale Dunmere East','westvale','West Vale','con','con'),
  ('seat-096','West Vale Dunmere West','westvale','West Vale','ld','con'),
  ('seat-097','West Vale Elmstead North','westvale','West Vale','ref','con'),
  ('seat-098','West Vale Elmstead South','westvale','West Vale','con','ref'),
  ('seat-099','West Vale Elmstead East','westvale','West Vale','grn','con'),
  ('seat-100','West Vale Elmstead West','westvale','West Vale','lab','con'),
  ('seat-101','West Vale Foxbridge North','westvale','West Vale','lab','con'),
  ('seat-102','West Vale Foxbridge South','westvale','West Vale','ld','con'),
  ('seat-103','West Vale Foxbridge East','westvale','West Vale','con','ref'),
  ('seat-104','West Vale Foxbridge West','westvale','West Vale','lab','con'),
  ('seat-105','West Vale Glenford North','westvale','West Vale','lab','con'),
  ('seat-106','West Vale Glenford South','westvale','West Vale','con','con'),
  ('seat-107','West Vale Glenford East','westvale','West Vale','lab','con'),
  ('seat-108','West Vale Glenford West','westvale','West Vale','con','ref'),
  ('seat-109','West Vale Hartwick North','westvale','West Vale','lab','ref'),
  ('seat-110','West Vale Hartwick South','westvale','West Vale','ref','con'),
  ('seat-111','West Vale Hartwick East','westvale','West Vale','con','con'),
  ('seat-112','West Vale Hartwick West','westvale','West Vale','grn','con'),
  ('seat-113','West Vale Ivycross North','westvale','West Vale','con','con'),
  ('seat-114','West Vale Ivycross South','westvale','West Vale','lab','ref'),
  ('seat-115','West Vale Ivycross East','westvale','West Vale','ld','con'),
  ('seat-116','West Vale Ivycross West','westvale','West Vale','con','con'),
  ('seat-117','West Vale Juniper Bay North','westvale','West Vale','uip','con'),
  ('seat-118','West Vale Juniper Bay South','westvale','West Vale','lab','con'),
  ('seat-119','West Vale Juniper Bay East','westvale','West Vale','con','ref'),
  ('seat-120','West Vale Juniper Bay West','westvale','West Vale','lab','con'),
  ('seat-121','East Vale Alderwick North','eastvale','East Vale','lab','lab'),
  ('seat-122','East Vale Alderwick South','eastvale','East Vale','ld','ref'),
  ('seat-123','East Vale Alderwick East','eastvale','East Vale','con','lab'),
  ('seat-124','East Vale Alderwick West','eastvale','East Vale','lab','con'),
  ('seat-125','East Vale Briarfield North','eastvale','East Vale','lab','con'),
  ('seat-126','East Vale Briarfield South','eastvale','East Vale','con','lab'),
  ('seat-127','East Vale Briarfield East','eastvale','East Vale','lab','ref'),
  ('seat-128','East Vale Briarfield West','eastvale','East Vale','con','lab'),
  ('seat-129','East Vale Cedarham North','eastvale','East Vale','lab','lab'),
  ('seat-130','East Vale Cedarham South','eastvale','East Vale','ref','con'),
  ('seat-131','East Vale Cedarham East','eastvale','East Vale','con','lab'),
  ('seat-132','East Vale Cedarham West','eastvale','East Vale','grn','ref'),
  ('seat-133','East Vale Dunmere North','eastvale','East Vale','con','ref'),
  ('seat-134','East Vale Dunmere South','eastvale','East Vale','lab','lab'),
  ('seat-135','East Vale Dunmere East','eastvale','East Vale','ld','con'),
  ('seat-136','East Vale Dunmere West','eastvale','East Vale','con','lab'),
  ('seat-137','East Vale Elmstead North','eastvale','East Vale','uip','lab'),
  ('seat-138','East Vale Elmstead South','eastvale','East Vale','lab','ref'),
  ('seat-139','East Vale Elmstead East','eastvale','East Vale','con','lab'),
  ('seat-140','East Vale Elmstead West','eastvale','East Vale','lab','con'),
  ('seat-141','East Vale Foxbridge North','eastvale','East Vale','ld','con'),
  ('seat-142','East Vale Foxbridge South','eastvale','East Vale','lab','lab'),
  ('seat-143','East Vale Foxbridge East','eastvale','East Vale','ref','ref'),
  ('seat-144','East Vale Foxbridge West','eastvale','East Vale','con','lab'),
  ('seat-145','East Vale Glenford North','eastvale','East Vale','lab','lab'),
  ('seat-146','East Vale Glenford South','eastvale','East Vale','con','con'),
  ('seat-147','East Vale Glenford East','eastvale','East Vale','lab','lab'),
  ('seat-148','East Vale Glenford West','eastvale','East Vale','ld','ref'),
  ('seat-149','East Vale Hartwick North','eastvale','East Vale','lab','ref'),
  ('seat-150','East Vale Hartwick South','eastvale','East Vale','uip','lab'),
  ('seat-151','East Vale Hartwick East','eastvale','East Vale','lab','con'),
  ('seat-152','East Vale Hartwick West','eastvale','East Vale','con','lab'),
  ('seat-153','East Vale Ivycross North','eastvale','East Vale','con','lab'),
  ('seat-154','East Vale Ivycross South','eastvale','East Vale','ld','ref'),
  ('seat-155','East Vale Ivycross East','eastvale','East Vale','lab','lab'),
  ('seat-156','East Vale Ivycross West','eastvale','East Vale','ref','con'),
  ('seat-157','East Vale Juniper Bay North','eastvale','East Vale','grn','con'),
  ('seat-158','East Vale Juniper Bay South','eastvale','East Vale','lab','lab'),
  ('seat-159','East Vale Juniper Bay East','eastvale','East Vale','con','ref'),
  ('seat-160','East Vale Juniper Bay West','eastvale','East Vale','lab','lab'),
  ('seat-161','Crownshire Alderwick North','crownshire','Crownshire','ld','ld'),
  ('seat-162','Crownshire Alderwick South','crownshire','Crownshire','lab','lab'),
  ('seat-163','Crownshire Alderwick East','crownshire','Crownshire','ref','ld'),
  ('seat-164','Crownshire Alderwick West','crownshire','Crownshire','con','lab'),
  ('seat-165','Crownshire Briarfield North','crownshire','Crownshire','lab','lab'),
  ('seat-166','Crownshire Briarfield South','crownshire','Crownshire','con','ld'),
  ('seat-167','Crownshire Briarfield East','crownshire','Crownshire','lab','lab'),
  ('seat-168','Crownshire Briarfield West','crownshire','Crownshire','ld','ld'),
  ('seat-169','Crownshire Cedarham North','crownshire','Crownshire','lab','ld'),
  ('seat-170','Crownshire Cedarham South','crownshire','Crownshire','uip','lab'),
  ('seat-171','Crownshire Cedarham East','crownshire','Crownshire','lab','ld'),
  ('seat-172','Crownshire Cedarham West','crownshire','Crownshire','con','lab'),
  ('seat-173','Crownshire Dunmere North','crownshire','Crownshire','con','lab'),
  ('seat-174','Crownshire Dunmere South','crownshire','Crownshire','ld','ld'),
  ('seat-175','Crownshire Dunmere East','crownshire','Crownshire','lab','lab'),
  ('seat-176','Crownshire Dunmere West','crownshire','Crownshire','ref','ld'),
  ('seat-177','Crownshire Elmstead North','crownshire','Crownshire','grn','ld'),
  ('seat-178','Crownshire Elmstead South','crownshire','Crownshire','lab','lab'),
  ('seat-179','Crownshire Elmstead East','crownshire','Crownshire','con','ld'),
  ('seat-180','Crownshire Elmstead West','crownshire','Crownshire','lab','lab'),
  ('seat-181','Crownshire Foxbridge North','crownshire','Crownshire','con','lab'),
  ('seat-182','Crownshire Foxbridge South','crownshire','Crownshire','lab','ld'),
  ('seat-183','Crownshire Foxbridge East','crownshire','Crownshire','uip','lab'),
  ('seat-184','Crownshire Foxbridge West','crownshire','Crownshire','lab','ld'),
  ('seat-185','Crownshire Glenford North','crownshire','Crownshire','lab','ld'),
  ('seat-186','Crownshire Glenford South','crownshire','Crownshire','con','lab'),
  ('seat-187','Crownshire Glenford East','crownshire','Crownshire','ld','ld'),
  ('seat-188','Crownshire Glenford West','crownshire','Crownshire','lab','lab'),
  ('seat-189','Crownshire Hartwick North','crownshire','Crownshire','con','lab'),
  ('seat-190','Crownshire Hartwick South','crownshire','Crownshire','grn','ld'),
  ('seat-191','Crownshire Hartwick East','crownshire','Crownshire','lab','lab'),
  ('seat-192','Crownshire Hartwick West','crownshire','Crownshire','con','ld'),
  ('seat-193','Crownshire Ivycross North','crownshire','Crownshire','ld','ld'),
  ('seat-194','Crownshire Ivycross South','crownshire','Crownshire','con','lab'),
  ('seat-195','Crownshire Ivycross East','crownshire','Crownshire','lab','ld'),
  ('seat-196','Crownshire Ivycross West','crownshire','Crownshire','uip','lab'),
  ('seat-197','Crownshire Juniper Bay North','crownshire','Crownshire','con','lab'),
  ('seat-198','Crownshire Juniper Bay South','crownshire','Crownshire','lab','ld'),
  ('seat-199','Crownshire Juniper Bay East','crownshire','Crownshire','con','lab'),
  ('seat-200','Crownshire Juniper Bay West','crownshire','Crownshire','ld','ld'),
  ('seat-201','Redmere Alderwick North','redmere','Redmere','con','lab'),
  ('seat-202','Redmere Alderwick South','redmere','Redmere','lab','lab'),
  ('seat-203','Redmere Alderwick East','redmere','Redmere','uip','lab'),
  ('seat-204','Redmere Alderwick West','redmere','Redmere','lab','grn'),
  ('seat-205','Redmere Briarfield North','redmere','Redmere','lab','grn'),
  ('seat-206','Redmere Briarfield South','redmere','Redmere','con','lab'),
  ('seat-207','Redmere Briarfield East','redmere','Redmere','ld','lab'),
  ('seat-208','Redmere Briarfield West','redmere','Redmere','lab','lab'),
  ('seat-209','Redmere Cedarham North','redmere','Redmere','con','lab'),
  ('seat-210','Redmere Cedarham South','redmere','Redmere','grn','grn'),
  ('seat-211','Redmere Cedarham East','redmere','Redmere','lab','lab'),
  ('seat-212','Redmere Cedarham West','redmere','Redmere','con','lab'),
  ('seat-213','Redmere Dunmere North','redmere','Redmere','ld','lab'),
  ('seat-214','Redmere Dunmere South','redmere','Redmere','con','lab'),
  ('seat-215','Redmere Dunmere East','redmere','Redmere','lab','grn'),
  ('seat-216','Redmere Dunmere West','redmere','Redmere','uip','lab'),
  ('seat-217','Redmere Elmstead North','redmere','Redmere','con','lab'),
  ('seat-218','Redmere Elmstead South','redmere','Redmere','lab','lab'),
  ('seat-219','Redmere Elmstead East','redmere','Redmere','con','lab'),
  ('seat-220','Redmere Elmstead West','redmere','Redmere','ld','grn'),
  ('seat-221','Redmere Foxbridge North','redmere','Redmere','ref','grn'),
  ('seat-222','Redmere Foxbridge South','redmere','Redmere','con','lab'),
  ('seat-223','Redmere Foxbridge East','redmere','Redmere','grn','lab'),
  ('seat-224','Redmere Foxbridge West','redmere','Redmere','lab','lab'),
  ('seat-225','Redmere Glenford North','redmere','Redmere','lab','lab'),
  ('seat-226','Redmere Glenford South','redmere','Redmere','ld','grn'),
  ('seat-227','Redmere Glenford East','redmere','Redmere','con','lab'),
  ('seat-228','Redmere Glenford West','redmere','Redmere','lab','lab'),
  ('seat-229','Redmere Hartwick North','redmere','Redmere','lab','lab'),
  ('seat-230','Redmere Hartwick South','redmere','Redmere','con','lab'),
  ('seat-231','Redmere Hartwick East','redmere','Redmere','lab','grn'),
  ('seat-232','Redmere Hartwick West','redmere','Redmere','con','lab'),
  ('seat-233','Redmere Ivycross North','redmere','Redmere','lab','lab'),
  ('seat-234','Redmere Ivycross South','redmere','Redmere','ref','lab'),
  ('seat-235','Redmere Ivycross East','redmere','Redmere','con','lab'),
  ('seat-236','Redmere Ivycross West','redmere','Redmere','grn','grn'),
  ('seat-237','Redmere Juniper Bay North','redmere','Redmere','con','grn'),
  ('seat-238','Redmere Juniper Bay South','redmere','Redmere','lab','lab'),
  ('seat-239','Redmere Juniper Bay East','redmere','Redmere','ld','lab'),
  ('seat-240','Redmere Juniper Bay West','redmere','Redmere','con','lab'),
  ('seat-241','Larkshire Alderwick North','larkshire','Larkshire','ref','ref'),
  ('seat-242','Larkshire Alderwick South','larkshire','Larkshire','con','con'),
  ('seat-243','Larkshire Alderwick East','larkshire','Larkshire','grn','con'),
  ('seat-244','Larkshire Alderwick West','larkshire','Larkshire','lab','con'),
  ('seat-245','Larkshire Briarfield North','larkshire','Larkshire','lab','con'),
  ('seat-246','Larkshire Briarfield South','larkshire','Larkshire','ld','ref'),
  ('seat-247','Larkshire Briarfield East','larkshire','Larkshire','con','con'),
  ('seat-248','Larkshire Briarfield West','larkshire','Larkshire','lab','con'),
  ('seat-249','Larkshire Cedarham North','larkshire','Larkshire','lab','con'),
  ('seat-250','Larkshire Cedarham South','larkshire','Larkshire','con','con'),
  ('seat-251','Larkshire Cedarham East','larkshire','Larkshire','lab','ref'),
  ('seat-252','Larkshire Cedarham West','larkshire','Larkshire','con','con'),
  ('seat-253','Larkshire Dunmere North','larkshire','Larkshire','lab','con'),
  ('seat-254','Larkshire Dunmere South','larkshire','Larkshire','ref','con'),
  ('seat-255','Larkshire Dunmere East','larkshire','Larkshire','con','con'),
  ('seat-256','Larkshire Dunmere West','larkshire','Larkshire','grn','ref'),
  ('seat-257','Larkshire Elmstead North','larkshire','Larkshire','con','ref'),
  ('seat-258','Larkshire Elmstead South','larkshire','Larkshire','lab','con'),
  ('seat-259','Larkshire Elmstead East','larkshire','Larkshire','ld','con'),
  ('seat-260','Larkshire Elmstead West','larkshire','Larkshire','con','con'),
  ('seat-261','Larkshire Foxbridge North','larkshire','Larkshire','uip','con'),
  ('seat-262','Larkshire Foxbridge South','larkshire','Larkshire','lab','ref'),
  ('seat-263','Larkshire Foxbridge East','larkshire','Larkshire','con','con'),
  ('seat-264','Larkshire Foxbridge West','larkshire','Larkshire','lab','con'),
  ('seat-265','Larkshire Glenford North','larkshire','Larkshire','ld','con'),
  ('seat-266','Larkshire Glenford South','larkshire','Larkshire','lab','con'),
  ('seat-267','Larkshire Glenford East','larkshire','Larkshire','ref','ref'),
  ('seat-268','Larkshire Glenford West','larkshire','Larkshire','con','con'),
  ('seat-269','Larkshire Hartwick North','larkshire','Larkshire','lab','con'),
  ('seat-270','Larkshire Hartwick South','larkshire','Larkshire','con','con'),
  ('seat-271','Larkshire Hartwick East','larkshire','Larkshire','lab','con'),
  ('seat-272','Larkshire Hartwick West','larkshire','Larkshire','ld','ref'),
  ('seat-273','Larkshire Ivycross North','larkshire','Larkshire','lab','ref'),
  ('seat-274','Larkshire Ivycross South','larkshire','Larkshire','uip','con'),
  ('seat-275','Larkshire Ivycross East','larkshire','Larkshire','lab','con'),
  ('seat-276','Larkshire Ivycross West','larkshire','Larkshire','con','con'),
  ('seat-277','Larkshire Juniper Bay North','larkshire','Larkshire','con','con'),
  ('seat-278','Larkshire Juniper Bay South','larkshire','Larkshire','ld','ref'),
  ('seat-279','Larkshire Juniper Bay East','larkshire','Larkshire','lab','con'),
  ('seat-280','Larkshire Juniper Bay West','larkshire','Larkshire','ref','con'),
  ('seat-281','Wexford Coast Alderwick North','wexfordcoast','Wexford Coast','uip','ref'),
  ('seat-282','Wexford Coast Alderwick South','wexfordcoast','Wexford Coast','lab','lab'),
  ('seat-283','Wexford Coast Alderwick East','wexfordcoast','Wexford Coast','con','con'),
  ('seat-284','Wexford Coast Alderwick West','wexfordcoast','Wexford Coast','lab','lab'),
  ('seat-285','Wexford Coast Briarfield North','wexfordcoast','Wexford Coast','ld','lab'),
  ('seat-286','Wexford Coast Briarfield South','wexfordcoast','Wexford Coast','lab','ref'),
  ('seat-287','Wexford Coast Briarfield East','wexfordcoast','Wexford Coast','ref','lab'),
  ('seat-288','Wexford Coast Briarfield West','wexfordcoast','Wexford Coast','con','con'),
  ('seat-289','Wexford Coast Cedarham North','wexfordcoast','Wexford Coast','lab','con'),
  ('seat-290','Wexford Coast Cedarham South','wexfordcoast','Wexford Coast','con','lab'),
  ('seat-291','Wexford Coast Cedarham East','wexfordcoast','Wexford Coast','lab','ref'),
  ('seat-292','Wexford Coast Cedarham West','wexfordcoast','Wexford Coast','ld','lab'),
  ('seat-293','Wexford Coast Dunmere North','wexfordcoast','Wexford Coast','lab','lab'),
  ('seat-294','Wexford Coast Dunmere South','wexfordcoast','Wexford Coast','uip','con'),
  ('seat-295','Wexford Coast Dunmere East','wexfordcoast','Wexford Coast','lab','lab'),
  ('seat-296','Wexford Coast Dunmere West','wexfordcoast','Wexford Coast','con','ref'),
  ('seat-297','Wexford Coast Elmstead North','wexfordcoast','Wexford Coast','con','ref'),
  ('seat-298','Wexford Coast Elmstead South','wexfordcoast','Wexford Coast','ld','lab'),
  ('seat-299','Wexford Coast Elmstead East','wexfordcoast','Wexford Coast','lab','con'),
  ('seat-300','Wexford Coast Elmstead West','wexfordcoast','Wexford Coast','ref','lab'),
  ('seat-301','Wexford Coast Foxbridge North','wexfordcoast','Wexford Coast','grn','lab'),
  ('seat-302','Wexford Coast Foxbridge South','wexfordcoast','Wexford Coast','lab','ref'),
  ('seat-303','Wexford Coast Foxbridge East','wexfordcoast','Wexford Coast','con','lab'),
  ('seat-304','Wexford Coast Foxbridge West','wexfordcoast','Wexford Coast','lab','con'),
  ('seat-305','Wexford Coast Glenford North','wexfordcoast','Wexford Coast','con','con'),
  ('seat-306','Wexford Coast Glenford South','wexfordcoast','Wexford Coast','lab','lab'),
  ('seat-307','Wexford Coast Glenford East','wexfordcoast','Wexford Coast','uip','ref'),
  ('seat-308','Wexford Coast Glenford West','wexfordcoast','Wexford Coast','lab','lab'),
  ('seat-309','Wexford Coast Hartwick North','wexfordcoast','Wexford Coast','lab','lab'),
  ('seat-310','Wexford Coast Hartwick South','wexfordcoast','Wexford Coast','con','con'),
  ('seat-311','Wexford Coast Hartwick East','wexfordcoast','Wexford Coast','ld','lab'),
  ('seat-312','Wexford Coast Hartwick West','wexfordcoast','Wexford Coast','lab','ref'),
  ('seat-313','Wexford Coast Ivycross North','wexfordcoast','Wexford Coast','con','ref'),
  ('seat-314','Wexford Coast Ivycross South','wexfordcoast','Wexford Coast','grn','lab'),
  ('seat-315','Wexford Coast Ivycross East','wexfordcoast','Wexford Coast','lab','con'),
  ('seat-316','Wexford Coast Ivycross West','wexfordcoast','Wexford Coast','con','lab'),
  ('seat-317','Wexford Coast Juniper Bay North','wexfordcoast','Wexford Coast','ld','lab'),
  ('seat-318','Wexford Coast Juniper Bay South','wexfordcoast','Wexford Coast','con','ref'),
  ('seat-319','Wexford Coast Juniper Bay East','wexfordcoast','Wexford Coast','lab','lab'),
  ('seat-320','Wexford Coast Juniper Bay West','wexfordcoast','Wexford Coast','uip','con'),
  ('seat-321','Halcyon Alderwick North','halcyon','Halcyon','grn','lab'),
  ('seat-322','Halcyon Alderwick South','halcyon','Halcyon','lab','ld'),
  ('seat-323','Halcyon Alderwick East','halcyon','Halcyon','con','lab'),
  ('seat-324','Halcyon Alderwick West','halcyon','Halcyon','lab','ld'),
  ('seat-325','Halcyon Briarfield North','halcyon','Halcyon','con','ld'),
  ('seat-326','Halcyon Briarfield South','halcyon','Halcyon','lab','lab'),
  ('seat-327','Halcyon Briarfield East','halcyon','Halcyon','uip','ld'),
  ('seat-328','Halcyon Briarfield West','halcyon','Halcyon','lab','lab'),
  ('seat-329','Halcyon Cedarham North','halcyon','Halcyon','lab','lab'),
  ('seat-330','Halcyon Cedarham South','halcyon','Halcyon','con','ld'),
  ('seat-331','Halcyon Cedarham East','halcyon','Halcyon','ld','lab'),
  ('seat-332','Halcyon Cedarham West','halcyon','Halcyon','lab','ld'),
  ('seat-333','Halcyon Dunmere North','halcyon','Halcyon','con','ld'),
  ('seat-334','Halcyon Dunmere South','halcyon','Halcyon','grn','lab'),
  ('seat-335','Halcyon Dunmere East','halcyon','Halcyon','lab','ld'),
  ('seat-336','Halcyon Dunmere West','halcyon','Halcyon','con','lab'),
  ('seat-337','Halcyon Elmstead North','halcyon','Halcyon','ld','lab'),
  ('seat-338','Halcyon Elmstead South','halcyon','Halcyon','con','ld'),
  ('seat-339','Halcyon Elmstead East','halcyon','Halcyon','lab','lab'),
  ('seat-340','Halcyon Elmstead West','halcyon','Halcyon','uip','ld'),
  ('seat-341','Halcyon Foxbridge North','halcyon','Halcyon','con','ld'),
  ('seat-342','Halcyon Foxbridge South','halcyon','Halcyon','lab','lab'),
  ('seat-343','Halcyon Foxbridge East','halcyon','Halcyon','con','ld'),
  ('seat-344','Halcyon Foxbridge West','halcyon','Halcyon','ld','lab'),
  ('seat-345','Halcyon Glenford North','halcyon','Halcyon','ref','lab'),
  ('seat-346','Halcyon Glenford South','halcyon','Halcyon','con','ld'),
  ('seat-347','Halcyon Glenford East','halcyon','Halcyon','grn','lab'),
  ('seat-348','Halcyon Glenford West','halcyon','Halcyon','lab','ld'),
  ('seat-349','Halcyon Hartwick North','halcyon','Halcyon','lab','ld'),
  ('seat-350','Halcyon Hartwick South','halcyon','Halcyon','ld','lab'),
  ('seat-351','Halcyon Hartwick East','halcyon','Halcyon','con','ld'),
  ('seat-352','Halcyon Hartwick West','halcyon','Halcyon','lab','lab'),
  ('seat-353','Halcyon Ivycross North','halcyon','Halcyon','lab','lab'),
  ('seat-354','Halcyon Ivycross South','halcyon','Halcyon','con','ld'),
  ('seat-355','Halcyon Ivycross East','halcyon','Halcyon','lab','lab'),
  ('seat-356','Halcyon Ivycross West','halcyon','Halcyon','con','ld'),
  ('seat-357','Halcyon Juniper Bay North','halcyon','Halcyon','lab','ld'),
  ('seat-358','Halcyon Juniper Bay South','halcyon','Halcyon','ref','lab'),
  ('seat-359','Halcyon Juniper Bay East','halcyon','Halcyon','con','ld'),
  ('seat-360','Halcyon Juniper Bay West','halcyon','Halcyon','grn','lab'),
  ('seat-361','Greyfen Alderwick North','greyfen','Greyfen','con','lab'),
  ('seat-362','Greyfen Alderwick South','greyfen','Greyfen','lab','lab'),
  ('seat-363','Greyfen Alderwick East','greyfen','Greyfen','con','grn'),
  ('seat-364','Greyfen Alderwick West','greyfen','Greyfen','ld','lab'),
  ('seat-365','Greyfen Briarfield North','greyfen','Greyfen','ref','lab'),
  ('seat-366','Greyfen Briarfield South','greyfen','Greyfen','con','lab'),
  ('seat-367','Greyfen Briarfield East','greyfen','Greyfen','grn','lab'),
  ('seat-368','Greyfen Briarfield West','greyfen','Greyfen','lab','grn'),
  ('seat-369','Greyfen Cedarham North','greyfen','Greyfen','lab','grn'),
  ('seat-370','Greyfen Cedarham South','greyfen','Greyfen','ld','lab'),
  ('seat-371','Greyfen Cedarham East','greyfen','Greyfen','con','lab'),
  ('seat-372','Greyfen Cedarham West','greyfen','Greyfen','lab','lab'),
  ('seat-373','Greyfen Dunmere North','greyfen','Greyfen','lab','lab'),
  ('seat-374','Greyfen Dunmere South','greyfen','Greyfen','con','grn'),
  ('seat-375','Greyfen Dunmere East','greyfen','Greyfen','lab','lab'),
  ('seat-376','Greyfen Dunmere West','greyfen','Greyfen','con','lab'),
  ('seat-377','Greyfen Elmstead North','greyfen','Greyfen','lab','lab'),
  ('seat-378','Greyfen Elmstead South','greyfen','Greyfen','ref','lab'),
  ('seat-379','Greyfen Elmstead East','greyfen','Greyfen','con','grn'),
  ('seat-380','Greyfen Elmstead West','greyfen','Greyfen','grn','lab'),
  ('seat-381','Greyfen Foxbridge North','greyfen','Greyfen','con','lab'),
  ('seat-382','Greyfen Foxbridge South','greyfen','Greyfen','lab','lab'),
  ('seat-383','Greyfen Foxbridge East','greyfen','Greyfen','ld','lab'),
  ('seat-384','Greyfen Foxbridge West','greyfen','Greyfen','con','grn'),
  ('seat-385','Greyfen Glenford North','greyfen','Greyfen','uip','grn'),
  ('seat-386','Greyfen Glenford South','greyfen','Greyfen','lab','lab'),
  ('seat-387','Greyfen Glenford East','greyfen','Greyfen','con','lab'),
  ('seat-388','Greyfen Glenford West','greyfen','Greyfen','lab','lab'),
  ('seat-389','Greyfen Hartwick North','greyfen','Greyfen','ld','lab'),
  ('seat-390','Greyfen Hartwick South','greyfen','Greyfen','lab','grn'),
  ('seat-391','Greyfen Hartwick East','greyfen','Greyfen','ref','lab'),
  ('seat-392','Greyfen Hartwick West','greyfen','Greyfen','con','lab'),
  ('seat-393','Greyfen Ivycross North','greyfen','Greyfen','lab','lab'),
  ('seat-394','Greyfen Ivycross South','greyfen','Greyfen','con','lab'),
  ('seat-395','Greyfen Ivycross East','greyfen','Greyfen','lab','grn'),
  ('seat-396','Greyfen Ivycross West','greyfen','Greyfen','ld','lab'),
  ('seat-397','Greyfen Juniper Bay North','greyfen','Greyfen','lab','lab'),
  ('seat-398','Greyfen Juniper Bay South','greyfen','Greyfen','uip','lab'),
  ('seat-399','Greyfen Juniper Bay East','greyfen','Greyfen','lab','lab'),
  ('seat-400','Greyfen Juniper Bay West','greyfen','Greyfen','con','grn'),
  ('seat-401','Ashbourne Alderwick North','ashbourne','Ashbourne','con','con'),
  ('seat-402','Ashbourne Alderwick South','ashbourne','Ashbourne','lab','con'),
  ('seat-403','Ashbourne Alderwick East','ashbourne','Ashbourne','ld','con'),
  ('seat-404','Ashbourne Alderwick West','ashbourne','Ashbourne','con','ref'),
  ('seat-405','Ashbourne Briarfield North','ashbourne','Ashbourne','uip','ref'),
  ('seat-406','Ashbourne Briarfield South','ashbourne','Ashbourne','lab','con'),
  ('seat-407','Ashbourne Briarfield East','ashbourne','Ashbourne','con','con'),
  ('seat-408','Ashbourne Briarfield West','ashbourne','Ashbourne','lab','con'),
  ('seat-409','Ashbourne Cedarham North','ashbourne','Ashbourne','ld','con'),
  ('seat-410','Ashbourne Cedarham South','ashbourne','Ashbourne','lab','ref'),
  ('seat-411','Ashbourne Cedarham East','ashbourne','Ashbourne','ref','con'),
  ('seat-412','Ashbourne Cedarham West','ashbourne','Ashbourne','con','con'),
  ('seat-413','Ashbourne Dunmere North','ashbourne','Ashbourne','lab','con'),
  ('seat-414','Ashbourne Dunmere South','ashbourne','Ashbourne','con','con'),
  ('seat-415','Ashbourne Dunmere East','ashbourne','Ashbourne','lab','ref'),
  ('seat-416','Ashbourne Dunmere West','ashbourne','Ashbourne','ld','con'),
  ('seat-417','Ashbourne Elmstead North','ashbourne','Ashbourne','lab','con'),
  ('seat-418','Ashbourne Elmstead South','ashbourne','Ashbourne','uip','con'),
  ('seat-419','Ashbourne Elmstead East','ashbourne','Ashbourne','lab','con'),
  ('seat-420','Ashbourne Elmstead West','ashbourne','Ashbourne','con','ref'),
  ('seat-421','Ashbourne Foxbridge North','ashbourne','Ashbourne','con','ref'),
  ('seat-422','Ashbourne Foxbridge South','ashbourne','Ashbourne','ld','con'),
  ('seat-423','Ashbourne Foxbridge East','ashbourne','Ashbourne','lab','con'),
  ('seat-424','Ashbourne Foxbridge West','ashbourne','Ashbourne','ref','con'),
  ('seat-425','Ashbourne Glenford North','ashbourne','Ashbourne','grn','con'),
  ('seat-426','Ashbourne Glenford South','ashbourne','Ashbourne','lab','ref'),
  ('seat-427','Ashbourne Glenford East','ashbourne','Ashbourne','con','con'),
  ('seat-428','Ashbourne Glenford West','ashbourne','Ashbourne','lab','con'),
  ('seat-429','Ashbourne Hartwick North','ashbourne','Ashbourne','con','con'),
  ('seat-430','Ashbourne Hartwick South','ashbourne','Ashbourne','lab','con'),
  ('seat-431','Ashbourne Hartwick East','ashbourne','Ashbourne','uip','ref'),
  ('seat-432','Ashbourne Hartwick West','ashbourne','Ashbourne','lab','con'),
  ('seat-433','Ashbourne Ivycross North','ashbourne','Ashbourne','lab','con'),
  ('seat-434','Ashbourne Ivycross South','ashbourne','Ashbourne','con','con'),
  ('seat-435','Ashbourne Ivycross East','ashbourne','Ashbourne','ld','con'),
  ('seat-436','Ashbourne Ivycross West','ashbourne','Ashbourne','lab','ref'),
  ('seat-437','Ashbourne Juniper Bay North','ashbourne','Ashbourne','con','ref'),
  ('seat-438','Ashbourne Juniper Bay South','ashbourne','Ashbourne','grn','con'),
  ('seat-439','Ashbourne Juniper Bay East','ashbourne','Ashbourne','lab','con'),
  ('seat-440','Ashbourne Juniper Bay West','ashbourne','Ashbourne','con','con'),
  ('seat-441','Kingsmere Alderwick North','kingsmere','Kingsmere','con','lab'),
  ('seat-442','Kingsmere Alderwick South','kingsmere','Kingsmere','ld','con'),
  ('seat-443','Kingsmere Alderwick East','kingsmere','Kingsmere','lab','lab'),
  ('seat-444','Kingsmere Alderwick West','kingsmere','Kingsmere','ref','ref'),
  ('seat-445','Kingsmere Briarfield North','kingsmere','Kingsmere','grn','ref'),
  ('seat-446','Kingsmere Briarfield South','kingsmere','Kingsmere','lab','lab'),
  ('seat-447','Kingsmere Briarfield East','kingsmere','Kingsmere','con','con'),
  ('seat-448','Kingsmere Briarfield West','kingsmere','Kingsmere','lab','lab'),
  ('seat-449','Kingsmere Cedarham North','kingsmere','Kingsmere','con','lab'),
  ('seat-450','Kingsmere Cedarham South','kingsmere','Kingsmere','lab','ref'),
  ('seat-451','Kingsmere Cedarham East','kingsmere','Kingsmere','uip','lab'),
  ('seat-452','Kingsmere Cedarham West','kingsmere','Kingsmere','lab','con'),
  ('seat-453','Kingsmere Dunmere North','kingsmere','Kingsmere','lab','con'),
  ('seat-454','Kingsmere Dunmere South','kingsmere','Kingsmere','con','lab'),
  ('seat-455','Kingsmere Dunmere East','kingsmere','Kingsmere','ld','ref'),
  ('seat-456','Kingsmere Dunmere West','kingsmere','Kingsmere','lab','lab'),
  ('seat-457','Kingsmere Elmstead North','kingsmere','Kingsmere','con','lab'),
  ('seat-458','Kingsmere Elmstead South','kingsmere','Kingsmere','grn','con'),
  ('seat-459','Kingsmere Elmstead East','kingsmere','Kingsmere','lab','lab'),
  ('seat-460','Kingsmere Elmstead West','kingsmere','Kingsmere','con','ref'),
  ('seat-461','Kingsmere Foxbridge North','kingsmere','Kingsmere','ld','ref'),
  ('seat-462','Kingsmere Foxbridge South','kingsmere','Kingsmere','con','lab'),
  ('seat-463','Kingsmere Foxbridge East','kingsmere','Kingsmere','lab','con'),
  ('seat-464','Kingsmere Foxbridge West','kingsmere','Kingsmere','uip','lab'),
  ('seat-465','Kingsmere Glenford North','kingsmere','Kingsmere','con','lab'),
  ('seat-466','Kingsmere Glenford South','kingsmere','Kingsmere','lab','ref'),
  ('seat-467','Kingsmere Glenford East','kingsmere','Kingsmere','con','lab'),
  ('seat-468','Kingsmere Glenford West','kingsmere','Kingsmere','ld','con'),
  ('seat-469','Kingsmere Hartwick North','kingsmere','Kingsmere','ref','con'),
  ('seat-470','Kingsmere Hartwick South','kingsmere','Kingsmere','con','lab'),
  ('seat-471','Kingsmere Hartwick East','kingsmere','Kingsmere','grn','ref'),
  ('seat-472','Kingsmere Hartwick West','kingsmere','Kingsmere','lab','lab'),
  ('seat-473','Kingsmere Ivycross North','kingsmere','Kingsmere','lab','lab'),
  ('seat-474','Kingsmere Ivycross South','kingsmere','Kingsmere','ld','con'),
  ('seat-475','Kingsmere Ivycross East','kingsmere','Kingsmere','con','lab'),
  ('seat-476','Kingsmere Ivycross West','kingsmere','Kingsmere','lab','ref'),
  ('seat-477','Kingsmere Juniper Bay North','kingsmere','Kingsmere','lab','ref'),
  ('seat-478','Kingsmere Juniper Bay South','kingsmere','Kingsmere','con','lab'),
  ('seat-479','Kingsmere Juniper Bay East','kingsmere','Kingsmere','lab','con'),
  ('seat-480','Kingsmere Juniper Bay West','kingsmere','Kingsmere','con','lab'),
  ('seat-481','Stonehaven Alderwick North','stonehaven','Stonehaven','ld','ld'),
  ('seat-482','Stonehaven Alderwick South','stonehaven','Stonehaven','con','lab'),
  ('seat-483','Stonehaven Alderwick East','stonehaven','Stonehaven','lab','ld'),
  ('seat-484','Stonehaven Alderwick West','stonehaven','Stonehaven','uip','lab'),
  ('seat-485','Stonehaven Briarfield North','stonehaven','Stonehaven','con','lab'),
  ('seat-486','Stonehaven Briarfield South','stonehaven','Stonehaven','lab','ld'),
  ('seat-487','Stonehaven Briarfield East','stonehaven','Stonehaven','con','lab'),
  ('seat-488','Stonehaven Briarfield West','stonehaven','Stonehaven','ld','ld'),
  ('seat-489','Stonehaven Cedarham North','stonehaven','Stonehaven','ref','ld'),
  ('seat-490','Stonehaven Cedarham South','stonehaven','Stonehaven','con','lab'),
  ('seat-491','Stonehaven Cedarham East','stonehaven','Stonehaven','grn','ld'),
  ('seat-492','Stonehaven Cedarham West','stonehaven','Stonehaven','lab','lab'),
  ('seat-493','Stonehaven Dunmere North','stonehaven','Stonehaven','lab','lab'),
  ('seat-494','Stonehaven Dunmere South','stonehaven','Stonehaven','ld','ld'),
  ('seat-495','Stonehaven Dunmere East','stonehaven','Stonehaven','con','lab'),
  ('seat-496','Stonehaven Dunmere West','stonehaven','Stonehaven','lab','ld'),
  ('seat-497','Stonehaven Elmstead North','stonehaven','Stonehaven','lab','ld'),
  ('seat-498','Stonehaven Elmstead South','stonehaven','Stonehaven','con','lab'),
  ('seat-499','Stonehaven Elmstead East','stonehaven','Stonehaven','lab','ld'),
  ('seat-500','Stonehaven Elmstead West','stonehaven','Stonehaven','con','lab'),
  ('seat-501','Stonehaven Foxbridge North','stonehaven','Stonehaven','lab','lab'),
  ('seat-502','Stonehaven Foxbridge South','stonehaven','Stonehaven','ref','ld'),
  ('seat-503','Stonehaven Foxbridge East','stonehaven','Stonehaven','con','lab'),
  ('seat-504','Stonehaven Foxbridge West','stonehaven','Stonehaven','grn','ld'),
  ('seat-505','Stonehaven Glenford North','stonehaven','Stonehaven','con','ld'),
  ('seat-506','Stonehaven Glenford South','stonehaven','Stonehaven','lab','lab'),
  ('seat-507','Stonehaven Glenford East','stonehaven','Stonehaven','ld','ld'),
  ('seat-508','Stonehaven Glenford West','stonehaven','Stonehaven','con','lab'),
  ('seat-509','Stonehaven Hartwick North','stonehaven','Stonehaven','uip','lab'),
  ('seat-510','Stonehaven Hartwick South','stonehaven','Stonehaven','lab','ld'),
  ('seat-511','Stonehaven Hartwick East','stonehaven','Stonehaven','con','lab'),
  ('seat-512','Stonehaven Hartwick West','stonehaven','Stonehaven','lab','ld'),
  ('seat-513','Stonehaven Ivycross North','stonehaven','Stonehaven','ld','ld'),
  ('seat-514','Stonehaven Ivycross South','stonehaven','Stonehaven','lab','lab'),
  ('seat-515','Stonehaven Ivycross East','stonehaven','Stonehaven','ref','ld'),
  ('seat-516','Stonehaven Ivycross West','stonehaven','Stonehaven','con','lab'),
  ('seat-517','Stonehaven Juniper Bay North','stonehaven','Stonehaven','lab','lab'),
  ('seat-518','Stonehaven Juniper Bay South','stonehaven','Stonehaven','con','ld'),
  ('seat-519','Stonehaven Juniper Bay East','stonehaven','Stonehaven','lab','lab'),
  ('seat-520','Stonehaven Juniper Bay West','stonehaven','Stonehaven','ld','ld'),
  ('seat-521','Greenwater Alderwick North','greenwater','Greenwater','lab','lab'),
  ('seat-522','Greenwater Alderwick South','greenwater','Greenwater','ref','grn'),
  ('seat-523','Greenwater Alderwick East','greenwater','Greenwater','con','lab'),
  ('seat-524','Greenwater Alderwick West','greenwater','Greenwater','grn','lab'),
  ('seat-525','Greenwater Briarfield North','greenwater','Greenwater','con','lab'),
  ('seat-526','Greenwater Briarfield South','greenwater','Greenwater','lab','lab'),
  ('seat-527','Greenwater Briarfield East','greenwater','Greenwater','ld','grn'),
  ('seat-528','Greenwater Briarfield West','greenwater','Greenwater','con','lab'),
  ('seat-529','Greenwater Cedarham North','greenwater','Greenwater','uip','lab'),
  ('seat-530','Greenwater Cedarham South','greenwater','Greenwater','lab','lab'),
  ('seat-531','Greenwater Cedarham East','greenwater','Greenwater','con','lab'),
  ('seat-532','Greenwater Cedarham West','greenwater','Greenwater','lab','grn'),
  ('seat-533','Greenwater Dunmere North','greenwater','Greenwater','ld','grn'),
  ('seat-534','Greenwater Dunmere South','greenwater','Greenwater','lab','lab'),
  ('seat-535','Greenwater Dunmere East','greenwater','Greenwater','ref','lab'),
  ('seat-536','Greenwater Dunmere West','greenwater','Greenwater','con','lab'),
  ('seat-537','Greenwater Elmstead North','greenwater','Greenwater','lab','lab'),
  ('seat-538','Greenwater Elmstead South','greenwater','Greenwater','con','grn'),
  ('seat-539','Greenwater Elmstead East','greenwater','Greenwater','lab','lab'),
  ('seat-540','Greenwater Elmstead West','greenwater','Greenwater','ld','lab'),
  ('seat-541','Greenwater Foxbridge North','greenwater','Greenwater','lab','lab'),
  ('seat-542','Greenwater Foxbridge South','greenwater','Greenwater','uip','lab'),
  ('seat-543','Greenwater Foxbridge East','greenwater','Greenwater','lab','grn'),
  ('seat-544','Greenwater Foxbridge West','greenwater','Greenwater','con','lab'),
  ('seat-545','Greenwater Glenford North','greenwater','Greenwater','con','lab'),
  ('seat-546','Greenwater Glenford South','greenwater','Greenwater','ld','lab'),
  ('seat-547','Greenwater Glenford East','greenwater','Greenwater','lab','lab'),
  ('seat-548','Greenwater Glenford West','greenwater','Greenwater','ref','grn'),
  ('seat-549','Greenwater Hartwick North','greenwater','Greenwater','grn','grn'),
  ('seat-550','Greenwater Hartwick South','greenwater','Greenwater','lab','lab'),
  ('seat-551','Greenwater Hartwick East','greenwater','Greenwater','con','lab'),
  ('seat-552','Greenwater Hartwick West','greenwater','Greenwater','lab','lab'),
  ('seat-553','Greenwater Ivycross North','greenwater','Greenwater','con','lab'),
  ('seat-554','Greenwater Ivycross South','greenwater','Greenwater','lab','grn'),
  ('seat-555','Greenwater Ivycross East','greenwater','Greenwater','uip','lab'),
  ('seat-556','Greenwater Ivycross West','greenwater','Greenwater','lab','lab'),
  ('seat-557','Greenwater Juniper Bay North','greenwater','Greenwater','lab','lab'),
  ('seat-558','Greenwater Juniper Bay South','greenwater','Greenwater','con','lab'),
  ('seat-559','Greenwater Juniper Bay East','greenwater','Greenwater','ld','grn'),
  ('seat-560','Greenwater Juniper Bay West','greenwater','Greenwater','lab','lab'),
  ('seat-561','Moorland Alderwick North','moorland','Moorland','lab','con'),
  ('seat-562','Moorland Alderwick South','moorland','Moorland','uip','con'),
  ('seat-563','Moorland Alderwick East','moorland','Moorland','lab','ref'),
  ('seat-564','Moorland Alderwick West','moorland','Moorland','con','con'),
  ('seat-565','Moorland Briarfield North','moorland','Moorland','con','con'),
  ('seat-566','Moorland Briarfield South','moorland','Moorland','ld','con'),
  ('seat-567','Moorland Briarfield East','moorland','Moorland','lab','con'),
  ('seat-568','Moorland Briarfield West','moorland','Moorland','ref','ref'),
  ('seat-569','Moorland Cedarham North','moorland','Moorland','grn','ref'),
  ('seat-570','Moorland Cedarham South','moorland','Moorland','lab','con'),
  ('seat-571','Moorland Cedarham East','moorland','Moorland','con','con'),
  ('seat-572','Moorland Cedarham West','moorland','Moorland','lab','con'),
  ('seat-573','Moorland Dunmere North','moorland','Moorland','con','con'),
  ('seat-574','Moorland Dunmere South','moorland','Moorland','lab','ref'),
  ('seat-575','Moorland Dunmere East','moorland','Moorland','uip','con'),
  ('seat-576','Moorland Dunmere West','moorland','Moorland','lab','con'),
  ('seat-577','Moorland Elmstead North','moorland','Moorland','lab','con'),
  ('seat-578','Moorland Elmstead South','moorland','Moorland','con','con'),
  ('seat-579','Moorland Elmstead East','moorland','Moorland','ld','ref'),
  ('seat-580','Moorland Elmstead West','moorland','Moorland','lab','con'),
  ('seat-581','Moorland Foxbridge North','moorland','Moorland','con','con'),
  ('seat-582','Moorland Foxbridge South','moorland','Moorland','grn','con'),
  ('seat-583','Moorland Foxbridge East','moorland','Moorland','lab','con'),
  ('seat-584','Moorland Foxbridge West','moorland','Moorland','con','ref'),
  ('seat-585','Moorland Glenford North','moorland','Moorland','ld','ref'),
  ('seat-586','Moorland Glenford South','moorland','Moorland','con','con'),
  ('seat-587','Moorland Glenford East','moorland','Moorland','lab','con'),
  ('seat-588','Moorland Glenford West','moorland','Moorland','uip','con'),
  ('seat-589','Moorland Hartwick North','moorland','Moorland','con','con'),
  ('seat-590','Moorland Hartwick South','moorland','Moorland','lab','ref'),
  ('seat-591','Moorland Hartwick East','moorland','Moorland','con','con'),
  ('seat-592','Moorland Hartwick West','moorland','Moorland','ld','con'),
  ('seat-593','Moorland Ivycross North','moorland','Moorland','ref','con'),
  ('seat-594','Moorland Ivycross South','moorland','Moorland','con','con'),
  ('seat-595','Moorland Ivycross East','moorland','Moorland','grn','ref'),
  ('seat-596','Moorland Ivycross West','moorland','Moorland','lab','con'),
  ('seat-597','Moorland Juniper Bay North','moorland','Moorland','lab','con'),
  ('seat-598','Moorland Juniper Bay South','moorland','Moorland','ld','con'),
  ('seat-599','Moorland Juniper Bay East','moorland','Moorland','con','con'),
  ('seat-600','Moorland Juniper Bay West','moorland','Moorland','lab','ref'),
  ('seat-601','New H Central Alderwick North','newhcentral','New H Central','con','con'),
  ('seat-602','New H Central Alderwick South','newhcentral','New H Central','grn','lab'),
  ('seat-603','New H Central Alderwick East','newhcentral','New H Central','lab','ref'),
  ('seat-604','New H Central Alderwick West','newhcentral','New H Central','con','lab'),
  ('seat-605','New H Central Briarfield North','newhcentral','New H Central','ld','lab'),
  ('seat-606','New H Central Briarfield South','newhcentral','New H Central','con','con'),
  ('seat-607','New H Central Briarfield East','newhcentral','New H Central','lab','lab'),
  ('seat-608','New H Central Briarfield West','newhcentral','New H Central','uip','ref'),
  ('seat-609','New H Central Cedarham North','newhcentral','New H Central','con','ref'),
  ('seat-610','New H Central Cedarham South','newhcentral','New H Central','lab','lab'),
  ('seat-611','New H Central Cedarham East','newhcentral','New H Central','con','con'),
  ('seat-612','New H Central Cedarham West','newhcentral','New H Central','ld','lab'),
  ('seat-613','New H Central Dunmere North','newhcentral','New H Central','ref','lab'),
  ('seat-614','New H Central Dunmere South','newhcentral','New H Central','con','ref'),
  ('seat-615','New H Central Dunmere East','newhcentral','New H Central','grn','lab'),
  ('seat-616','New H Central Dunmere West','newhcentral','New H Central','lab','con'),
  ('seat-617','New H Central Elmstead North','newhcentral','New H Central','lab','con'),
  ('seat-618','New H Central Elmstead South','newhcentral','New H Central','ld','lab'),
  ('seat-619','New H Central Elmstead East','newhcentral','New H Central','con','ref'),
  ('seat-620','New H Central Elmstead West','newhcentral','New H Central','lab','lab'),
  ('seat-621','New H Central Foxbridge North','newhcentral','New H Central','lab','lab'),
  ('seat-622','New H Central Foxbridge South','newhcentral','New H Central','con','con'),
  ('seat-623','New H Central Foxbridge East','newhcentral','New H Central','lab','lab'),
  ('seat-624','New H Central Foxbridge West','newhcentral','New H Central','con','ref'),
  ('seat-625','New H Central Glenford North','newhcentral','New H Central','lab','ref'),
  ('seat-626','New H Central Glenford South','newhcentral','New H Central','ref','lab'),
  ('seat-627','New H Central Glenford East','newhcentral','New H Central','con','con'),
  ('seat-628','New H Central Glenford West','newhcentral','New H Central','grn','lab'),
  ('seat-629','New H Central Hartwick North','newhcentral','New H Central','con','lab'),
  ('seat-630','New H Central Hartwick South','newhcentral','New H Central','lab','ref'),
  ('seat-631','New H Central Hartwick East','newhcentral','New H Central','ld','lab'),
  ('seat-632','New H Central Hartwick West','newhcentral','New H Central','con','con'),
  ('seat-633','New H Central Ivycross North','newhcentral','New H Central','uip','con'),
  ('seat-634','New H Central Ivycross South','newhcentral','New H Central','lab','lab'),
  ('seat-635','New H Central Ivycross East','newhcentral','New H Central','con','ref'),
  ('seat-636','New H Central Ivycross West','newhcentral','New H Central','lab','lab'),
  ('seat-637','New H Central Juniper Bay North','newhcentral','New H Central','ld','lab'),
  ('seat-638','New H Central Juniper Bay South','newhcentral','New H Central','lab','con'),
  ('seat-639','New H Central Juniper Bay East','newhcentral','New H Central','ref','lab'),
  ('seat-640','New H Central Juniper Bay West','newhcentral','New H Central','con','ref')
on conflict (seat_id) do update set
  seat_name = excluded.seat_name,
  region_id = excluded.region_id,
  region_name = excluded.region_name,
  previous_winner = excluded.previous_winner,
  predicted_winner = excluded.predicted_winner;

-- One hidden election plan. Only RPC functions below may expose a seat after it is declared.
create table if not exists public.newh_surprise_rounds (
  id uuid primary key default gen_random_uuid(),
  year text not null default '2026',
  active boolean not null default true,
  final_winner text not null,
  runner_up text not null,
  actual_totals jsonb not null,
  exit_poll jsonb not null,
  exit_leader text not null,
  exit_poll_revealed boolean not null default false,
  declared_count integer not null default 0,
  created_at timestamptz not null default now()
);

create unique index if not exists newh_one_active_surprise_round
  on public.newh_surprise_rounds ((active)) where active;

create table if not exists public.newh_surprise_results (
  round_id uuid not null references public.newh_surprise_rounds(id) on delete cascade,
  seat_id text not null references public.newh_seat_catalogue(seat_id) on delete cascade,
  party_id text not null,
  revealed boolean not null default false,
  revealed_at timestamptz,
  reveal_order integer,
  primary key (round_id, seat_id)
);

alter table public.newh_seat_catalogue enable row level security;
alter table public.newh_surprise_rounds enable row level security;
alter table public.newh_surprise_results enable row level security;

-- Do not let the public anon key inspect hidden plans directly.
revoke all on public.newh_seat_catalogue from anon, authenticated;
revoke all on public.newh_surprise_rounds from anon, authenticated;
revoke all on public.newh_surprise_results from anon, authenticated;

create or replace function public.newh_party_short(p_id text)
returns text language sql immutable as $$
  select case p_id
    when 'con' then 'CON' when 'lab' then 'LAB' when 'ld' then 'LD'
    when 'ref' then 'REF' when 'grn' then 'GRN' when 'uip' then 'UIP'
    when 'ind' then 'IND' else upper(coalesce(p_id,'?')) end;
$$;

-- Generates a new locked 640-seat election. It intentionally does NOT return
-- the final winner or final totals.
create or replace function public.newh_create_surprise_election(p_year text default '2026')
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_round uuid := gen_random_uuid();
  v_eligible text[] := array['con','lab','ld'];
  v_final text;
  v_runner text;
  v_third text;
  v_exit_leader text;
  v_winner_target int;
  v_runner_target int;
  v_third_target int;
  v_ref_target int;
  v_grn_target int;
  v_uip_target int;
  v_ind_target int;
  v_remaining int;
  v_minor_remaining int;
  ep_leader int;
  ep_final int;
  ep_third int;
  ep_ref int;
  ep_grn int;
  ep_uip int;
  ep_ind int;
  ep_remaining int;
  v_actual jsonb;
  v_exit jsonb;
begin
  update public.newh_surprise_rounds set active = false where active;

  v_final := v_eligible[1 + floor(random() * array_length(v_eligible,1))::int];
  select x into v_runner from unnest(v_eligible) as x where x <> v_final order by random() limit 1;
  select x into v_third from unnest(v_eligible) as x where x <> v_final and x <> v_runner limit 1;

  -- Close but believable race. The hidden winner is always the largest party,
  -- but may or may not have a 321-seat majority.
  v_winner_target := 285 + floor(random() * 51)::int; -- 285..335
  v_runner_target := 205 + floor(random() * 56)::int; -- 205..260
  if v_runner_target >= v_winner_target then
    v_runner_target := v_winner_target - (12 + floor(random() * 18)::int);
  end if;

  v_remaining := 640 - v_winner_target - v_runner_target;
  v_third_target := greatest(12, floor(v_remaining * (0.42 + random() * 0.18))::int);
  v_minor_remaining := v_remaining - v_third_target;
  v_ref_target := floor(v_minor_remaining * 0.37)::int;
  v_grn_target := floor(v_minor_remaining * 0.27)::int;
  v_uip_target := floor(v_minor_remaining * 0.13)::int;
  v_ind_target := v_minor_remaining - v_ref_target - v_grn_target - v_uip_target;

  v_actual := jsonb_build_object(
    v_final, v_winner_target,
    v_runner, v_runner_target,
    v_third, v_third_target,
    'ref', v_ref_target,
    'grn', v_grn_target,
    'uip', v_uip_target,
    'ind', v_ind_target
  );

  -- Exit poll deliberately points to a different eligible party than the real winner.
  select x into v_exit_leader from unnest(v_eligible) as x where x <> v_final order by random() limit 1;
  ep_leader := 300 + floor(random() * 26)::int; -- 300..325
  ep_final := 260 + floor(random() * 31)::int;  -- 260..290
  if ep_final >= ep_leader then ep_final := ep_leader - 9; end if;
  ep_remaining := 640 - ep_leader - ep_final;
  ep_third := greatest(5, floor(ep_remaining * (0.34 + random() * 0.15))::int);
  ep_remaining := ep_remaining - ep_third;
  ep_ref := floor(ep_remaining * 0.34)::int;
  ep_grn := floor(ep_remaining * 0.27)::int;
  ep_uip := floor(ep_remaining * 0.14)::int;
  ep_ind := ep_remaining - ep_ref - ep_grn - ep_uip;

  v_exit := jsonb_build_object(
    v_exit_leader, ep_leader,
    v_final, ep_final,
    (select x from unnest(v_eligible) x where x <> v_exit_leader and x <> v_final limit 1), ep_third,
    'ref', ep_ref,
    'grn', ep_grn,
    'uip', ep_uip,
    'ind', ep_ind
  );

  insert into public.newh_surprise_rounds
    (id, year, active, final_winner, runner_up, actual_totals, exit_poll, exit_leader)
  values
    (v_round, coalesce(nullif(p_year,''),'2026'), true, v_final, v_runner, v_actual, v_exit, v_exit_leader);

  -- Randomise constituency locations while preserving the exact secret final totals.
  with ranked as (
    select seat_id, row_number() over (order by random()) as rn
    from public.newh_seat_catalogue
  )
  insert into public.newh_surprise_results (round_id, seat_id, party_id)
  select v_round, seat_id,
    case
      when rn <= v_winner_target then v_final
      when rn <= v_winner_target + v_runner_target then v_runner
      when rn <= v_winner_target + v_runner_target + v_third_target then v_third
      when rn <= v_winner_target + v_runner_target + v_third_target + v_ref_target then 'ref'
      when rn <= v_winner_target + v_runner_target + v_third_target + v_ref_target + v_grn_target then 'grn'
      when rn <= v_winner_target + v_runner_target + v_third_target + v_ref_target + v_grn_target + v_uip_target then 'uip'
      else 'ind'
    end
  from ranked;

  return jsonb_build_object(
    'ok', true,
    'active', true,
    'year', coalesce(nullif(p_year,''),'2026'),
    'declaredCount', 0,
    'remaining', 640,
    'exitPollRevealed', false,
    'message', '640 hidden constituency results generated and locked. Final winner remains secret.'
  );
end;
$$;

create or replace function public.newh_surprise_status()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare r public.newh_surprise_rounds%rowtype;
begin
  select * into r from public.newh_surprise_rounds where active order by created_at desc limit 1;
  if r.id is null then return jsonb_build_object('active',false); end if;
  return jsonb_build_object(
    'active', true,
    'year', r.year,
    'declaredCount', r.declared_count,
    'remaining', 640-r.declared_count,
    'exitPollRevealed', r.exit_poll_revealed,
    'complete', r.declared_count >= 640
  );
end;
$$;

-- Returns the saved 22:00 exit poll, but never returns the real final winner.
create or replace function public.newh_reveal_exit_poll()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r public.newh_surprise_rounds%rowtype;
  rows jsonb;
begin
  select * into r from public.newh_surprise_rounds where active order by created_at desc limit 1;
  if r.id is null then raise exception 'No surprise election exists. Create one first.'; end if;
  update public.newh_surprise_rounds set exit_poll_revealed = true where id = r.id;

  select jsonb_agg(jsonb_build_object('partyId',p,'seats',coalesce((r.exit_poll->>p)::int,0)) order by ord)
  into rows
  from (values ('con',1),('lab',2),('ld',3),('ref',4),('grn',5),('uip',6),('ind',7)) as t(p,ord);

  return jsonb_build_object(
    'ok', true,
    'title', 'EXIT POLL',
    'leaderPartyId', r.exit_leader,
    'rows', rows,
    'total', 640,
    'message', '22:00 exit poll revealed. The real final result is still locked.'
  );
end;
$$;

-- Reveal one hidden result. Pass NULL/omit p_seat_id for a random undeclared seat,
-- or pass a seat id to reveal a specific constituency without choosing its winner.
create or replace function public.newh_reveal_declaration(p_seat_id text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r public.newh_surprise_rounds%rowtype;
  s record;
  new_count int;
begin
  select * into r from public.newh_surprise_rounds where active order by created_at desc limit 1 for update;
  if r.id is null then raise exception 'No surprise election exists. Create one first.'; end if;
  if r.declared_count >= 640 then raise exception 'All 640 constituencies are already declared.'; end if;

  if p_seat_id is null or p_seat_id = '' then
    select sr.seat_id, sr.party_id, c.seat_name, c.region_name, c.previous_winner, c.predicted_winner
    into s
    from public.newh_surprise_results sr
    join public.newh_seat_catalogue c on c.seat_id = sr.seat_id
    where sr.round_id = r.id and not sr.revealed
    order by random()
    limit 1
    for update of sr;
  else
    select sr.seat_id, sr.party_id, c.seat_name, c.region_name, c.previous_winner, c.predicted_winner
    into s
    from public.newh_surprise_results sr
    join public.newh_seat_catalogue c on c.seat_id = sr.seat_id
    where sr.round_id = r.id and sr.seat_id = p_seat_id and not sr.revealed
    limit 1
    for update of sr;
  end if;

  if s.seat_id is null then raise exception 'That constituency is already declared or does not exist.'; end if;
  new_count := r.declared_count + 1;

  update public.newh_surprise_results
  set revealed = true, revealed_at = now(), reveal_order = new_count
  where round_id = r.id and seat_id = s.seat_id;
  update public.newh_surprise_rounds set declared_count = new_count where id = r.id;

  return jsonb_build_object(
    'ok', true,
    'seatId', s.seat_id,
    'seatName', s.seat_name,
    'region', s.region_name,
    'partyId', s.party_id,
    'previousWinner', s.previous_winner,
    'predictedWinner', s.predicted_winner,
    'declaredCount', new_count,
    'remaining', 640-new_count,
    'complete', new_count >= 640
  );
end;
$$;

create or replace function public.newh_undo_last_declaration()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r public.newh_surprise_rounds%rowtype;
  s record;
begin
  select * into r from public.newh_surprise_rounds where active order by created_at desc limit 1 for update;
  if r.id is null then raise exception 'No surprise election exists.'; end if;
  if r.declared_count <= 0 then return jsonb_build_object('ok',false,'message','Nothing to undo.'); end if;

  select sr.seat_id, sr.party_id into s
  from public.newh_surprise_results sr
  where sr.round_id = r.id and sr.revealed
  order by sr.reveal_order desc nulls last, sr.revealed_at desc
  limit 1 for update;

  update public.newh_surprise_results
  set revealed=false, revealed_at=null, reveal_order=null
  where round_id=r.id and seat_id=s.seat_id;
  update public.newh_surprise_rounds
  set declared_count=greatest(0,declared_count-1)
  where id=r.id;

  return jsonb_build_object('ok',true,'seatId',s.seat_id,'partyId',s.party_id,'declaredCount',r.declared_count-1,'remaining',641-r.declared_count);
end;
$$;

-- Function permissions: public users can operate the reveal engine, but still cannot
-- query the hidden tables themselves.
revoke all on function public.newh_party_short(text) from public;
revoke all on function public.newh_create_surprise_election(text) from public;
revoke all on function public.newh_surprise_status() from public;
revoke all on function public.newh_reveal_exit_poll() from public;
revoke all on function public.newh_reveal_declaration(text) from public;
revoke all on function public.newh_undo_last_declaration() from public;

grant execute on function public.newh_create_surprise_election(text) to anon, authenticated;
grant execute on function public.newh_surprise_status() to anon, authenticated;
grant execute on function public.newh_reveal_exit_poll() to anon, authenticated;
grant execute on function public.newh_reveal_declaration(text) to anon, authenticated;
grant execute on function public.newh_undo_last_declaration() to anon, authenticated;
