-- Both refresh_estimated_vehicle_positions() and refresh_crowd_vehicle_positions()
-- have existed since Round 15/20 but were only ever called by a developer
-- manually running admin/scripts/refresh-vehicle-positions.mjs on their own
-- machine — not a real, always-on production data source. Scheduling them
-- via pg_cron (a standard Supabase extension) makes "realtime" vehicle
-- positions genuinely continuous without depending on anyone keeping a
-- script running.
--
-- pg_cron's minimum granularity is whole minutes — that's coarser than the
-- Node poller's 20s cadence, but still consistent with this table's own
-- honesty labeling ('near_real_time'/'estimated', never 'real_time'), so a
-- ~60s worst-case staleness doesn't misrepresent anything.
create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'refresh_estimated_vehicle_positions',
  '* * * * *',
  $$select public.refresh_estimated_vehicle_positions();$$
);

select cron.schedule(
  'refresh_crowd_vehicle_positions',
  '* * * * *',
  $$select public.refresh_crowd_vehicle_positions();$$
);

comment on extension pg_cron is
  'Drives refresh_estimated_vehicle_positions()/refresh_crowd_vehicle_positions() every minute — see 20260806120000_vehicle_positions_cron.sql. Without this, public.vehicle_positions only updates when someone manually runs admin/scripts/refresh-vehicle-positions.mjs.';
