#!/usr/bin/env bash
# Publish a retained fake snapshot (mirrors the LLD App B envelope).
# Usage: ./publish_snapshot.sh [state_seq]
set -euo pipefail
source "$(dirname "$0")/env.sh"
SEQ="${1:-$(date +%s)}"
PAYLOAD=$(printf '{"event_type":"STATE_SNAPSHOT","schema_version":1,"epoch":0,"state_seq":%s,"widget":{"name":"SPIKE_TEST","data":{"seq":%s}},"ts":%s}' "$SEQ" "$SEQ" "$(date +%s)")
# How the publisher reaches the broker differs per platform. Linux can share the
# host network namespace (--network host + localhost). Docker Desktop (macOS)
# cannot, so target the compose-published port via the host.docker.internal alias.
if [[ "$(uname)" == "Darwin" ]]; then
  docker run --rm hivemq/mqtt-cli:latest \
    pub -h host.docker.internal -p 1883 -V 5 -q 1 -r -t "$TOPIC" -m "$PAYLOAD"
else
  docker run --rm --network host hivemq/mqtt-cli:latest \
    pub -h localhost -p 1883 -V 5 -q 1 -r -t "$TOPIC" -m "$PAYLOAD"
fi
echo "published retained seq=$SEQ to $TOPIC"
