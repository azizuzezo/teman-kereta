-- GAPEKA 2026 cutover for the networks hosted in the database (KRL Jabodetabek, KRL Yogyakarta).
-- NOT a migration and not run automatically. Run each block by hand in the Supabase SQL editor, in order, reading
-- the output before going on. See README.md in this folder.
--
-- What it touches: only public.trips of operator "KAI Commuter" (gtfs) on lines BOGOR, CIKARANG, RANGKAS,
-- TANGERANG, PRIOK and YKPL, only service_date >= 2026-12-01, and only trips that did NOT come from the GAPEKA 2026
-- feed (their external_trip_id starts with GJ26_). Deleting a trip cascades to its stop_times, vehicle positions and
-- crowd rows (on delete cascade); user records that point at it are set to null (on delete set null).

-- 1. PREVIEW: which old-schedule trips exist on or after 1 December (these would show next to the new ones).
select l.code, min(t.service_date) as first_day, max(t.service_date) as last_day, count(*) as old_trips
from public.trips t
join public.lines l on l.id = t.line_id
join public.operators o on o.id = l.operator_id
where o.name = 'KAI Commuter' and o.data_source_type = 'gtfs'
  and l.code in ('BOGOR', 'CIKARANG', 'RANGKAS', 'TANGERANG', 'PRIOK', 'YKPL')
  and t.service_date >= date '2026-12-01'
  and coalesce(t.external_trip_id, '') not like 'GJ26\_%'
group by l.code
order by l.code;

-- 1b. PREVIEW: user records that would lose their link to one of those trips (set to null, not deleted).
select 'trips referenced by user rows' as what, count(*)
from public.trips t
join public.lines l on l.id = t.line_id
join public.operators o on o.id = l.operator_id
where o.name = 'KAI Commuter' and o.data_source_type = 'gtfs'
  and l.code in ('BOGOR', 'CIKARANG', 'RANGKAS', 'TANGERANG', 'PRIOK', 'YKPL')
  and t.service_date >= date '2026-12-01'
  and coalesce(t.external_trip_id, '') not like 'GJ26\_%';

-- 2. DELETE the old-schedule trips from 1 December on. Wrapped in a transaction: check the row count it reports
--    against step 1, then COMMIT (or ROLLBACK if it does not match).
begin;
delete from public.trips t
using public.lines l, public.operators o
where l.id = t.line_id and o.id = l.operator_id
  and o.name = 'KAI Commuter' and o.data_source_type = 'gtfs'
  and l.code in ('BOGOR', 'CIKARANG', 'RANGKAS', 'TANGERANG', 'PRIOK', 'YKPL')
  and t.service_date >= date '2026-12-01'
  and coalesce(t.external_trip_id, '') not like 'GJ26\_%';
-- commit;
-- rollback;

-- 3. The operator id the import script needs (run before importing).
select id, name from public.operators where name = 'KAI Commuter' and data_source_type = 'gtfs';

-- 4. AFTER IMPORT: trips per day around the switch. 30 Nov = old schedule only, 1 Dec on = GAPEKA only.
select t.service_date, l.code,
       count(*) filter (where t.external_trip_id like 'GJ26\_%') as gapeka_2026,
       count(*) filter (where coalesce(t.external_trip_id, '') not like 'GJ26\_%') as old
from public.trips t
join public.lines l on l.id = t.line_id
join public.operators o on o.id = l.operator_id
where o.name = 'KAI Commuter' and o.data_source_type = 'gtfs'
  and l.code in ('BOGOR', 'CIKARANG', 'RANGKAS', 'TANGERANG', 'PRIOK', 'YKPL')
  and t.service_date between date '2026-11-29' and date '2026-12-03'
group by 1, 2
order by 1, 2;

-- 5. AFTER IMPORT: no duplicate lines were created (each code exactly once for the operator).
select l.code, count(*)
from public.lines l join public.operators o on o.id = l.operator_id
where o.name = 'KAI Commuter' and o.data_source_type = 'gtfs'
group by l.code
order by l.code;

-- ROLLBACK of the import, if needed: remove the GAPEKA trips (old ones for December must then be re-imported from
-- whatever feed produced them).
-- delete from public.trips t using public.lines l, public.operators o
-- where l.id = t.line_id and o.id = l.operator_id and o.name = 'KAI Commuter' and o.data_source_type = 'gtfs'
--   and t.external_trip_id like 'GJ26\_%';
