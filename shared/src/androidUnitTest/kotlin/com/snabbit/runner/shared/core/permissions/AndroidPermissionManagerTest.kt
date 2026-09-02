package com.snabbit.runner.shared.core.permissions

import android.Manifest
import android.os.Build
import androidx.activity.ComponentActivity
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.permissions.fakes.FakeGrantManager
import dev.brewkits.grant.AppGrant
import dev.brewkits.grant.GrantStatus
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Robolectric tests for the Android orchestration in [AndroidPermissionManager] that the pure
 * commonTest suite can't reach: the unexpected-failure → re-askable DENIED contract, the batched
 * requestMultiple failure path, the stripped/undeclared → NOT_AVAILABLE refinement, and the
 * DENIED → DENIED_ALWAYS upgrade (which the manager computes itself, since Grant can't in our
 * GrantFactory + launcher setup).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.TIRAMISU])
class AndroidPermissionManagerTest {

    private val context get() = RuntimeEnvironment.getApplication()

    /** Capturing reporter (shared CrashReporter is a fun interface, so a lambda suffices). */
    private class RecordingReporter : CrashReporter {
        val nonFatals = mutableListOf<Throwable>()
        override fun report(throwable: Throwable, meta: Map<String, String>) {
            nonFatals += throwable
        }
    }

    private fun manager(grant: FakeGrantManager, reporter: CrashReporter = RecordingReporter()) =
        AndroidPermissionManager(context, grant, reporter)

    @Before
    fun declareTestPermissions() {
        // Mirror the app's manifest: declare the runtime perms the tests use, but deliberately NOT
        // the media perms (the app strips READ_MEDIA_* via tools:node="remove"). refine()'s
        // declared-check reads this to distinguish "stripped → NOT_AVAILABLE" from a real denial.
        shadowOf(context.packageManager)
            .getInternalMutablePackageInfo(context.packageName)
            .requestedPermissions = arrayOf(
            Manifest.permission.CAMERA,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.READ_CONTACTS,
        )
    }

    // --- Unexpected Grant failure → re-askable DENIED, NEVER permanent NOT_AVAILABLE ---

    @Test
    fun `request returns DENIED (not NOT_AVAILABLE) and records when Grant throws`() = runTest {
        val reporter = RecordingReporter()
        val grant = FakeGrantManager(failure = RuntimeException("oem boom"))
        assertEquals(PermissionStatus.DENIED, manager(grant, reporter).request(SnabbitPermission.Camera))
        assertTrue("failure must be recorded", reporter.nonFatals.isNotEmpty())
    }

    @Test
    fun `check returns DENIED when Grant throws`() = runTest {
        val grant = FakeGrantManager(failure = RuntimeException("boom"))
        assertEquals(PermissionStatus.DENIED, manager(grant).check(SnabbitPermission.Camera))
    }

    @Test
    fun `requestMultiple emits DENIED for every runtime permission when the batch throws`() = runTest {
        val reporter = RecordingReporter()
        val grant = FakeGrantManager(failure = RuntimeException("batch boom"))
        val results = manager(grant, reporter).requestMultiple(
            listOf(SnabbitPermission.LocationFine, SnabbitPermission.Camera),
        ).toList()
        assertEquals(
            listOf(
                SnabbitPermission.LocationFine to PermissionStatus.DENIED,
                SnabbitPermission.Camera to PermissionStatus.DENIED,
            ),
            results,
        )
        assertTrue(reporter.nonFatals.isNotEmpty())
    }

    @Test
    fun `requestMultiple preserves input order and maps batched statuses`() = runTest {
        val grant = FakeGrantManager().apply {
            setStatus(AppGrant.LOCATION.identifier, GrantStatus.GRANTED)
            setStatus(AppGrant.CAMERA.identifier, GrantStatus.DENIED)
        }
        val results = manager(grant).requestMultiple(
            listOf(SnabbitPermission.LocationFine, SnabbitPermission.Camera),
        ).toList()
        assertEquals(SnabbitPermission.LocationFine to PermissionStatus.GRANTED, results[0])
        assertEquals(SnabbitPermission.Camera to PermissionStatus.DENIED, results[1])
    }

    // --- refine(): manual DENIED → DENIED_ALWAYS (Grant can't compute it in our setup) ---

    @Test
    fun `check on a never-requested permission stays DENIED`() = runTest {
        val grant = FakeGrantManager().apply { setStatus(AppGrant.CAMERA.identifier, GrantStatus.DENIED) }
        // No prior request through this module → never-asked → must stay re-askable DENIED.
        assertEquals(PermissionStatus.DENIED, manager(grant).check(SnabbitPermission.Camera))
    }

    @Test
    fun `request DENIED without an attached Activity stays DENIED`() = runTest {
        val grant = FakeGrantManager().apply { setStatus(AppGrant.CAMERA.identifier, GrantStatus.DENIED) }
        // Asked (marks requested) but no Activity to read rationale → safe DENIED, not DENIED_ALWAYS.
        assertEquals(PermissionStatus.DENIED, manager(grant).request(SnabbitPermission.Camera))
    }

    @Test
    fun `request DENIED with Activity and no rationale becomes DENIED_ALWAYS`() = runTest {
        val grant = FakeGrantManager().apply { setStatus(AppGrant.CAMERA.identifier, GrantStatus.DENIED) }
        val mgr = manager(grant)
        val activity = Robolectric.buildActivity(ComponentActivity::class.java).create().get()
        mgr.attachActivity(activity)
        // Robolectric's shouldShowRequestPermissionRationale defaults to false → "don't ask again".
        assertEquals(PermissionStatus.DENIED_ALWAYS, mgr.request(SnabbitPermission.Camera))
    }

    @Test
    fun `stripped (undeclared) permission reports NOT_AVAILABLE`() = runTest {
        // READ_MEDIA_IMAGES is intentionally NOT in the declared set (the app strips it), so Photos
        // can't be granted by dialog or in Settings → NOT_AVAILABLE, not a misleading DENIED.
        // FakeGrantManager's default NOT_DETERMINED maps to DENIED, which refine() upgrades to
        // NOT_AVAILABLE because the manifest entry is absent.
        assertEquals(
            PermissionStatus.NOT_AVAILABLE,
            manager(FakeGrantManager()).check(SnabbitPermission.Photos),
        )
    }
}
