-- Reference cohort only: purchase_success can be a trial, paid purchase, or repeated purchase.
-- Do not label this cohort RevenueCat trial users without a deterministic identity join.
-- Fixed observation end: 2026-11-07 00:00 UTC; this intentionally excludes the partial current day.
WITH events AS (
  SELECT user_pseudo_id, event_timestamp, event_name, event_params, app_info.version AS version
  FROM `voiceyourtext.analytics_431236332.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20261001' AND '20261107'
    AND platform = 'IOS'
    AND event_timestamp < UNIX_MICROS(TIMESTAMP('2026-11-07'))
), cohort AS (
  SELECT user_pseudo_id, MIN(event_timestamp) AS started_at
  FROM events
  WHERE event_name = 'subscription_purchase_success'
    AND event_timestamp >= UNIX_MICROS(TIMESTAMP('2026-10-01'))
    AND event_timestamp < UNIX_MICROS(TIMESTAMP('2026-11-01'))
    AND user_pseudo_id IS NOT NULL
  GROUP BY user_pseudo_id
), behavior AS (
  SELECT c.user_pseudo_id, c.started_at,
    COUNTIF(e.event_timestamp >= c.started_at + 86400000000) > 0 AS any_event_after_24h,
    COUNTIF(e.event_name = 'session_start' AND e.event_timestamp >= c.started_at + 86400000000) > 0 AS returned_after_24h,
    COUNTIF(e.event_name = 'session_start' AND e.event_timestamp >= c.started_at + 86400000000
      AND e.event_timestamp < c.started_at + 172800000000) > 0 AS returned_d1,
    COUNTIF(e.event_name = 'session_start' AND e.event_timestamp >= c.started_at + 259200000000
      AND e.event_timestamp < c.started_at + 345600000000) > 0 AS returned_d3,
    COUNTIF(e.event_name = 'session_start' AND e.event_timestamp >= c.started_at + 604800000000
      AND e.event_timestamp < c.started_at + 691200000000) > 0 AS returned_d7,
    COUNTIF(e.event_name IN ('speech_completed', 'content_playback_completed')) > 0 AS recorded_completion,
    COUNTIF(e.event_name = 'content_playback_requested') > 0 AS recorded_request,
    COUNTIF(e.event_name = 'voicevox_toggle' AND EXISTS(
      SELECT 1 FROM UNNEST(e.event_params) p WHERE p.key='enabled' AND p.value.string_value='true')) > 0 AS enabled_voicevox
  FROM cohort c LEFT JOIN events e ON c.user_pseudo_id=e.user_pseudo_id
    AND e.event_timestamp >= c.started_at
    AND e.event_timestamp < c.started_at + 691200000000
  GROUP BY c.user_pseudo_id,c.started_at
)
SELECT COUNT(*) AS purchase_success_installations,
  COUNTIF(any_event_after_24h) AS installations_with_any_event_after_24h,
  COUNTIF(returned_after_24h) AS returned_after_24h_within_8d,
  COUNTIF(started_at + 172800000000 <= UNIX_MICROS(TIMESTAMP('2026-11-07'))) AS d1_observable,
  COUNTIF(returned_d1 AND started_at + 172800000000 <= UNIX_MICROS(TIMESTAMP('2026-11-07'))) AS d1_returned,
  COUNTIF(started_at + 345600000000 <= UNIX_MICROS(TIMESTAMP('2026-11-07'))) AS d3_observable,
  COUNTIF(returned_d3 AND started_at + 345600000000 <= UNIX_MICROS(TIMESTAMP('2026-11-07'))) AS d3_returned,
  COUNTIF(started_at + 691200000000 <= UNIX_MICROS(TIMESTAMP('2026-11-07'))) AS d7_observable,
  COUNTIF(returned_d7 AND started_at + 691200000000 <= UNIX_MICROS(TIMESTAMP('2026-11-07'))) AS d7_returned,
  COUNTIF(recorded_completion) AS installations_with_completion_signal,
  COUNTIF(recorded_request) AS installations_with_new_request_signal,
  COUNTIF(enabled_voicevox) AS installations_enabling_voicevox
FROM behavior;
