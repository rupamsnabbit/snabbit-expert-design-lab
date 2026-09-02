package com.snabbit.runner.shared.features.kavach.shield.domain.upload

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldUploadQueue
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.withTimeoutOrNull
import org.koin.core.context.GlobalContext
import java.util.concurrent.TimeUnit

/**
 * Drains the clip outbox out of band. WorkManager persists the request in its own DB, so this survives
 * process death and reboot — unlike the in-process coroutine scopes, which only stayed alive because an
 * unrelated Flutter foreground service happened to hold the process up.
 */
class ShieldSyncWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        // Koin starts in Application.onCreate, which always precedes a Worker; missing means a bootstrap
        // failure, so retry rather than drop the backlog.
        val queue = GlobalContext.getOrNull()?.getOrNull<ShieldUploadQueue>() ?: return Result.retry()

        // Bounded: ApiPreflight awaits token hydration with no timeout of its own, and a headless run has
        // no UI to unblock it. Bounding here keeps the in-app auth paths untouched.
        // Cancellation is rethrown, not swallowed — withTimeoutOrNull needs it to report the timeout, and
        // WorkManager stopping us must not look like a drain failure.
        val drained = withTimeoutOrNull(DRAIN_TIMEOUT_MS) {
            try {
                queue.processQueue()
                true
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                false
            }
        }
        if (drained != true) return Result.retry()

        // Stop when the outbox is empty, not when this job's clips are done — an earlier job's stuck clip
        // must not be abandoned. Rows left → retry, and WorkManager applies the backoff.
        return if (queue.hasPending()) Result.retry() else Result.success()
    }

    companion object {
        private const val DRAIN_TIMEOUT_MS = 4L * 60L * 1000L
        private const val WORK_NAME = "shield_clip_sync"

        /**
         * [expedite] = an explicit user-driven moment (checkout). KEEP would collapse it into a pending
         * request that may be minutes into its backoff, so nothing runs sooner; REPLACE resets the
         * backoff and drains now. The pass-driven path stays KEEP — REPLACE there would re-enqueue
         * immediately after every pass that left rows behind, i.e. a hot retry loop.
         */
        fun enqueue(context: Context, expedite: Boolean = false) {
            val request = OneTimeWorkRequestBuilder<ShieldSyncWorker>()
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .build()
            val policy = if (expedite) ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.KEEP
            WorkManager.getInstance(context).enqueueUniqueWork(WORK_NAME, policy, request)
        }
    }
}

/** Android [ShieldSyncScheduler] — hands the drain to WorkManager. */
class WorkManagerShieldSyncScheduler(private val context: Context) : ShieldSyncScheduler {
    override fun schedule(expedite: Boolean) = ShieldSyncWorker.enqueue(context, expedite)
}
