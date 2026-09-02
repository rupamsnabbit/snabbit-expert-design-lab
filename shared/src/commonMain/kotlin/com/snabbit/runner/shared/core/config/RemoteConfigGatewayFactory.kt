package com.snabbit.runner.shared.core.config

/**
 * Platform factory for the app-wide [RemoteConfigGateway].
 *
 * Android reads Firebase Remote Config directly via the official SDK (B-native — no Flutter/Pigeon
 * bridge). iOS falls back to [DefaultRemoteConfigGateway] until its native impl lands (the cinterop /
 * Swift-shim stage), so the graph stays fail-safe — every key resolves to its call-site default.
 *
 * Generic and feature-agnostic: bound once in `coreModule`; consumed by any feature (Kavach, …).
 */
expect fun remoteConfigGateway(): RemoteConfigGateway
