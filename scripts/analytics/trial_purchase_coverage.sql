-- Aggregate only; never select installation/customer identifiers into the report.
SELECT app_info.version AS app_version,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key='source') AS source,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key='plan_type') AS plan_type,
  (SELECT COALESCE(value.string_value,CAST(value.int_value AS STRING)) FROM UNNEST(event_params) WHERE key='trial_eligible') AS trial_eligible,
  (SELECT COALESCE(value.string_value,CAST(value.int_value AS STRING)) FROM UNNEST(event_params) WHERE key='debug_mode') AS debug_mode,
  COUNT(*) AS events, COUNT(DISTINCT user_pseudo_id) AS installations
FROM `voiceyourtext.analytics_431236332.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20261001' AND '20261101'
  AND platform='IOS' AND event_name='subscription_purchase_success'
  AND event_timestamp >= UNIX_MICROS(TIMESTAMP('2026-10-01'))
  AND event_timestamp < UNIX_MICROS(TIMESTAMP('2026-11-01'))
GROUP BY app_version,source,plan_type,trial_eligible,debug_mode;
