"""Approved read-only trial audit. Customer and transaction IDs stay in memory.

Enumerate customers to find production App Store trials starting 2026-09-01 through
2026-11-06. Emit aggregate counts only. Never persist raw responses or identifiers.
"""
import concurrent.futures
from collections import Counter, defaultdict
import datetime as dt
import json
import subprocess
import threading
import time
from urllib.parse import quote, urljoin, urlparse
import requests

BASE = 'https://api.revenuecat.com/v2/projects/projf454902e'
START = int(dt.datetime(2026, 9, 1, tzinfo=dt.timezone.utc).timestamp() * 1000)
END = int(dt.datetime(2026, 11, 7, tzinfo=dt.timezone.utc).timestamp() * 1000)
LOCK = threading.Lock()
NEXT_CALL = 0.0
FIELDS = ('event_timestamp_ms', 'purchased_at_ms', 'expiration_at_ms', 'period_type',
          'product_id', 'store', 'environment', 'cancel_reason', 'expiration_reason',
          'is_trial_conversion', 'price', 'original_transaction_id', 'transaction_id')


def main():
    global NEXT_CALL
    key = subprocess.run(['security', 'find-generic-password', '-s',
                          'voiceyourtext-revenuecat-key', '-w'],
                         capture_output=True, text=True, check=True).stdout.strip()
    headers = {'Authorization': 'Bearer ' + key}

    def items(path):
        global NEXT_CALL
        result = []
        url = urljoin('https://api.revenuecat.com', path)
        while url:
            if urlparse(url).netloc != 'api.revenuecat.com':
                raise RuntimeError('Unexpected pagination host')
            for attempt in range(5):
                with LOCK:
                    wait = max(0, NEXT_CALL - time.monotonic())
                    if wait:
                        time.sleep(wait)
                    NEXT_CALL = time.monotonic() + 0.17
                try:
                    response = requests.get(url, headers=headers, timeout=30)
                except requests.RequestException:
                    # Do not expose a customer ID embedded in the failed request URL.
                    raise RuntimeError('RevenueCat request failed') from None
                if response.status_code in (429, 500, 502, 503, 504):
                    time.sleep(min(30, 2 ** attempt))
                    continue
                if response.status_code != 200:
                    raise RuntimeError(f'RevenueCat HTTP {response.status_code}')
                data = response.json()
                break
            else:
                raise RuntimeError('RevenueCat retries exhausted')
            result.extend(data.get('items', []))
            following = data.get('next_page')
            url = urljoin('https://api.revenuecat.com', following) if following else None
        return result

    customers = items(BASE + '/customers?limit=100')
    # Candidate restriction is reported; reconcile with Charts before calling it exhaustive.
    candidates = [c['id'] for c in customers if (c.get('last_seen_at') or 0) >= START
                  and (c.get('first_seen_at') or 0) < END]
    enumerated = len(customers)
    del customers
    print(json.dumps({'enumerated': enumerated, 'candidates': len(candidates)}), flush=True)

    def collect(customer_id):
        path = BASE + '/customers/' + quote(customer_id, safe='')
        raw = items(path + '/events?environment=production&limit=100')
        events, fields, types = [], set(), set()
        for item in raw:
            body = item.get('body') or {}
            if not isinstance(body, dict):
                raise RuntimeError('Unexpected event body format')
            fields.update(body.keys())
            event = {k: body[k] for k in FIELDS if k in body}
            event['type'] = (body.get('type') or item.get('type', '')).removeprefix('PURCHASES_')
            event['event_timestamp_ms'] = body.get('event_timestamp_ms') or item.get('occurred_at')
            types.add(event['type'])
            events.append(event)
        del raw
        trials = [e for e in events if e.get('period_type') == 'TRIAL'
                  and e['type'] == 'INITIAL_PURCHASE' and e.get('store') == 'APP_STORE'
                  and e.get('environment') == 'PRODUCTION'
                  and START <= (e.get('purchased_at_ms') or e.get('event_timestamp_ms') or 0) < END]
        has_join_id = False
        if trials:
            attributes = items(path + '/attributes?limit=100')
            has_join_id = any(a.get('name') == '$firebaseAppInstanceId' and a.get('value') for a in attributes)
            del attributes
        # Only temporary process memory holds IDs. Nothing below writes them to disk/stdout.
        return customer_id, events, trials, bool(has_join_id), fields, types

    groups = defaultdict(Counter)
    seen = set()
    fields, types = set(), set()
    trial_customers, with_join = 0, 0
    now = int(time.time() * 1000)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for index, (customer_id, events, trials, has_join, row_fields, row_types) in enumerate(pool.map(collect, candidates), 1):
            fields.update(row_fields)
            types.update(row_types)
            if trials:
                trial_customers += 1
                with_join += has_join
            for trial in trials:
                start = trial.get('purchased_at_ms') or trial['event_timestamp_ms']
                transaction = trial.get('original_transaction_id')
                dedup = trial.get('transaction_id') or (customer_id, start, trial.get('product_id'))
                if dedup in seen:
                    continue
                seen.add(dedup)
                group = groups[dt.datetime.fromtimestamp(start / 1000, dt.timezone.utc).strftime('%Y-%m')]
                group['trial_starts'] += 1
                group['has_firebase_join_attribute'] += has_join
                group['transaction_link_available'] += transaction is not None
                # Never associate another subscription using time alone.
                linked = sorted([e for e in events if transaction and e.get('original_transaction_id') == transaction
                                 and e.get('environment') == 'PRODUCTION' and e.get('store') == 'APP_STORE'
                                 and (e.get('event_timestamp_ms') or 0) >= start],
                                key=lambda e: e['event_timestamp_ms'])
                cancel = [e for e in linked if e['type'] == 'CANCELLATION']
                expired = [e for e in linked if e['type'] == 'EXPIRATION']
                billing = [e for e in linked if e['type'] == 'BILLING_ISSUE']
                converted = [e for e in linked if e.get('is_trial_conversion') is True]
                group['explicit_trial_conversions'] += bool(converted)
                group['expiration_events'] += bool(expired)
                group['billing_issue_events'] += bool(billing)
                group['cancellation_events'] += bool(cancel)
                if cancel:
                    hours = (cancel[0]['event_timestamp_ms'] - start) / 3_600_000
                    bucket = 'within_1h' if hours < 1 else '1_to_24h' if hours < 24 else 'after_24h'
                    group['first_cancel_' + bucket] += 1
                    group['cancel_reason_' + str(cancel[0].get('cancel_reason', 'UNKNOWN'))] += 1
                if expired:
                    group['expiration_reason_' + str(expired[-1].get('expiration_reason', 'UNKNOWN'))] += 1
                if not expired and not converted:
                    if (trial.get('expiration_at_ms') or 0) > now:
                        group['initial_trial_end_in_future'] += 1
                    else:
                        group['outcome_unresolved'] += 1
            if index % 50 == 0:
                print(json.dumps({'processed': index, 'trial_customers': trial_customers}), flush=True)
    print(json.dumps({'complete': True, 'fetched_at': dt.datetime.now(dt.timezone.utc).isoformat(),
                      'enumerated': enumerated, 'candidates': len(candidates),
                      'trial_customers': trial_customers, 'customers_with_firebase_attribute': with_join,
                      'months': dict(groups), 'event_field_names': sorted(fields),
                      'event_types_seen': sorted(types)}, ensure_ascii=False, indent=2), flush=True)


if __name__ == '__main__':
    main()
