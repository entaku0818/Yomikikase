"""Run a reviewed aggregate BigQuery SQL file, with a dry run and 100 MB cap.

Requires requests and existing gcloud ADC credentials. Prints aggregate rows only;
SQL must not select raw user identifiers or content. Does not store credentials.
"""
import argparse
import json
import subprocess
from pathlib import Path

import requests


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sql', type=Path)
    args = parser.parse_args()
    token = subprocess.run(
        ['gcloud', 'auth', 'application-default', 'print-access-token'],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    headers = {'Authorization': f'Bearer {token}', 'x-goog-user-project': 'voilog'}
    base = 'https://bigquery.googleapis.com/bigquery/v2/projects/voiceyourtext'
    query = {'query': args.sql.read_text(), 'useLegacySql': False}
    result = requests.post(base + '/jobs', headers=headers, json={
        'configuration': {'dryRun': True, 'query': query}}, timeout=30)
    if result.status_code != 200:
        raise SystemExit(f'Dry run failed: HTTP {result.status_code}')
    data = result.json()
    if data.get('status', {}).get('errorResult'):
        raise SystemExit('Dry run returned a query error')
    if data.get('statistics', {}).get('query', {}).get('statementType') != 'SELECT':
        raise SystemExit('Only a single SELECT statement is allowed')
    estimated = int(data.get('statistics', {}).get('totalBytesProcessed', 0))
    if estimated > 100_000_000:
        raise SystemExit(f'Query exceeds 100 MB cap: {estimated}')
    result = requests.post(base + '/queries', headers=headers, json={
        **query, 'maximumBytesBilled': '100000000', 'timeoutMs': 20000,
        'location': 'US'}, timeout=30)
    if result.status_code != 200:
        raise SystemExit(f'Query failed: HTTP {result.status_code}')
    data = result.json()
    if not data.get('jobComplete') or data.get('errors'):
        raise SystemExit('Query incomplete or errored; do not interpret as empty data')
    if data.get('pageToken'):
        raise SystemExit('Unexpected pagination; refusing to report partial results')
    names = [f['name'] for f in data.get('schema', {}).get('fields', [])]
    rows = [dict(zip(names, [v['v'] for v in r['f']])) for r in data.get('rows', [])]
    print(json.dumps({'estimated_bytes': estimated, 'rows': rows}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
