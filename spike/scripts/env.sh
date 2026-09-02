#!/usr/bin/env bash
# Shared config for the WS0 spike scripts. Override via environment.
export PKG="${PKG:-com.snabbit.runner}"
export SERVICE="$PKG/com.snabbit.runner.shared.core.background.SnabbitForegroundService"
export TAG="MqttSoakSpike"
export RUNNER_ID="${RUNNER_ID:-0}"
export TOPIC="maestro/user/${RUNNER_ID}/state"
# Host as seen FROM THE PHONE. Emulator: 10.0.2.2. Real device: your laptop's
# LAN IP (phone and laptop on the same network), e.g. HOST=192.168.1.23.
export HOST="${HOST:-10.0.2.2}"
export PORT="${PORT:-1883}"
# `timeout` is GNU coreutils: present on Linux, absent on stock macOS where it
# ships as `gtimeout` (brew install coreutils). Resolve whichever is available.
export TIMEOUT="$(command -v timeout || command -v gtimeout || true)"
