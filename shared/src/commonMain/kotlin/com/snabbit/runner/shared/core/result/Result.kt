package com.snabbit.runner.shared.core.result

/**
 * Discriminated union for success/failure, used across the network and
 * repository layers (§2.2). Compile-time exhaustive `when` forces callers
 * to handle both branches.
 *
 * NOTE: Shadows `kotlin.Result` from the default imports. Files using this
 * type must import it explicitly:
 *
 *     import com.snabbit.runner.shared.core.result.Result
 */
sealed class Result<out V, out E> {
    data class Ok<V>(val value: V) : Result<V, Nothing>()
    data class Err<E>(val error: E) : Result<Nothing, E>()
}

inline fun <V, E> Result<V, E>.onSuccess(action: (V) -> Unit): Result<V, E> {
    if (this is Result.Ok) action(value)
    return this
}

inline fun <V, E> Result<V, E>.onError(action: (E) -> Unit): Result<V, E> {
    if (this is Result.Err) action(error)
    return this
}
