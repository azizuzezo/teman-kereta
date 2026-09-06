-- Remove the premium/subscription feature entirely -- the app is now free for
-- everyone (product decision). Drops the schema backing the paywall/free-trial/
-- QRIS-payment flow that lib/features/premium/ and the premium-*-payment Edge
-- Functions used; those Flutter/Edge Function files are removed separately.

alter publication supabase_realtime drop table if exists public.subscriptions;

drop function if exists public.claim_trial(text);

drop table if exists public.premium_payments;
drop table if exists public.device_trial_claims;
drop table if exists public.subscriptions;

update public.app_config
set value = coalesce(value, '{}'::jsonb) - 'premium_price_idr' - 'premium_period_days' - 'premium_trial_days'
where key = 'remote_config';
