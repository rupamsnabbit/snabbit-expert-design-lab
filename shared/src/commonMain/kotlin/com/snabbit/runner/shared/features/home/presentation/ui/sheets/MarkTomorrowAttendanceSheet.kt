package com.snabbit.runner.shared.features.home.presentation.ui.sheets

import androidx.compose.runtime.Composable
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.ui.AttendanceButtonRow
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.calendar_illustration

/**
 * "Mark tomorrow's attendance" sheet — Figma DS 1583:6506, Dart port of
 * `lib/widgets/attendance_flow/provisional_attendance_before_logout.dart`.
 *
 * Triggered server-side via the `PA_BEFORE_LOGOUT` widget. Forces the runner
 * to mark tomorrow's attendance before logging out — typically non-dismissable.
 *
 * Slot composition over [AttendanceSheetShell]:
 *  - **header**: 100dp calendar illustration.
 *  - **title**: "Mark tomorrow's attendance" ([HomeStrings.markTomorrowTitle]).
 *  - **content**: gray-100 inset [SheetDateBox] (date + shift window).
 *  - **actions**: Destructive Absent / Success Present [AttendanceButtonRow].
 */
@Composable
fun MarkTomorrowAttendanceSheet(
    dateLabel: String,
    shiftWindowLabel: String,
    strings: HomeStrings,
    onMarkAbsent: () -> Unit,
    onMarkPresent: () -> Unit,
    loadingAbsent: Boolean = false,
    loadingPresent: Boolean = false,
) {
    AttendanceSheetShell(
        header = { SheetIllustration(Res.drawable.calendar_illustration) },
        title = strings.markTomorrowTitle,
        content = { SheetDateBox(dateLabel = dateLabel, shiftWindowLabel = shiftWindowLabel) },
        actions = {
            AttendanceButtonRow(
                absentLabel = strings.sheetAbsentCta,
                presentLabel = strings.sheetPresentCta,
                onAbsent = onMarkAbsent,
                onPresent = onMarkPresent,
                absentLoading = loadingAbsent,
                presentLoading = loadingPresent,
            )
        },
    )
}
