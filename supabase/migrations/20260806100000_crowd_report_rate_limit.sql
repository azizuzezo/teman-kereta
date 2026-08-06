-- ============================================================================
-- Abuse hardening for crowd_position_reports (flagged open since Round 20 —
-- the timestamp-window CHECK constraint alone doesn't stop a client from
-- spamming many reports per trip within a valid window).
--
-- Two independent guards, both enforced inside the existing insert RLS
-- policy's `with check` so a malicious anon client can't bypass them by
-- calling the table directly with a different query shape:
--
-- 1. Per-device_session_id rate limit: at most one report every 15 seconds
--    per device_session_id. CrowdPositionReporter's real client cadence is a
--    20s timer, so this never blocks a genuine report — it only blocks a
--    client (buggy retry loop, or deliberate spam) hammering inserts under
--    the same session id. This does NOT stop an attacker who generates a
--    fresh random device_session_id per request — that id is unauthenticated
--    client-supplied data, the same limitation every anon-key-only
--    architecture has without device attestation (Play Integrity/App Check
--    — deliberately not part of this project, no Firebase anywhere per the
--    privacy page). Real protection against a determined attacker would need
--    that, or Supabase's own gateway-level rate limiting (a dashboard/infra
--    setting, not something a migration can express).
--
-- 2. A coarse geographic sanity bound: the entire bundled KRL Jabodetabek
--    feed's real stations (checked directly from stops.txt, not guessed)
--    sit within lat -6.595..-6.11, lon 106.251..107.145. Padded generously
--    to lat -6.8..-5.9, lon 106.0..107.35 to tolerate normal GPS drift near
--    the network's edges. A report outside that box is definitely not a
--    real KRL position, whatever produced it.
-- ============================================================================

create or replace function public.crowd_position_report_rate_ok(p_device_session_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.crowd_position_reports
    where device_session_id = p_device_session_id
      and created_at > now() - interval '15 seconds'
  )
$$;

comment on function public.crowd_position_report_rate_ok is
  'RLS insert guard for crowd_position_reports: at most one report per device_session_id every 15 seconds (real client cadence is 20s, so this never blocks a genuine report).';

revoke all on function public.crowd_position_report_rate_ok(text) from public;
grant execute on function public.crowd_position_report_rate_ok(text) to anon, authenticated;

drop policy "Anyone can report their own position" on public.crowd_position_reports;

create policy "Anyone can report their own position"
  on public.crowd_position_reports
  for insert
  to anon, authenticated
  with check (
    public.crowd_position_report_rate_ok(device_session_id)
    and latitude between -6.8 and -5.9
    and longitude between 106.0 and 107.35
  );
