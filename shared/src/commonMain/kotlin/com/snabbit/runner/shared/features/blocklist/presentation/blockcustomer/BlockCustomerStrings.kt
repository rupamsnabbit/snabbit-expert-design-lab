package com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer

import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.blocklist.presentation.unblocktoblock.UnblockToBlockStrings
import com.snabbit.runner.shared.features.blocklist.presentation.unblocktoblock.localized

/**
 * UI text for the block-customer sheet, fed as data (server-driven i18n; English fallbacks matching
 * the Flutter copy keys). [unblockToBlock] threads the "unblock to block" copy for the MaxReached step.
 */
data class BlockCustomerStrings(
    /** i18n key `block_customer_warning_title`. */
    val title: String = "Are you sure you want to block?",
    /** i18n key `block_customer_warning_subtitle`. */
    val subtitle: String = "Once blocked, customer will not be able to make future bookings with you.",
    /** i18n key `no`. */
    val noLabel: String = "No",
    /** i18n key `yes`. */
    val yesLabel: String = "Yes",
    /** Generic block-failure copy. */
    val genericError: String = "Something went wrong. Please try again.",
    val unblockToBlock: UnblockToBlockStrings = UnblockToBlockStrings(),
)

/**
 * Overlays the server-driven i18n map onto these [BlockCustomerStrings], threading the nested
 * [unblockToBlock] through [UnblockToBlockStrings.localized] (which threads [blockList] in turn).
 * Absent keys fall back to English. Apply ONCE at the running host (ActiveJobOverlay) — the
 * cascade localizes the whole block-flow tree; never bake into a data-class default.
 */
fun BlockCustomerStrings.localized(store: LocalizationStore): BlockCustomerStrings = copy(
    title = store.getMessage("block_confirm.title", title),
    subtitle = store.getMessage("block_confirm.desc", subtitle),
    noLabel = store.getMessage("block_confirm.cta_no", noLabel),
    yesLabel = store.getMessage("block_confirm.cta_yes", yesLabel),
    genericError = store.getMessage("block_confirm.generic_error", genericError),
    unblockToBlock = unblockToBlock.localized(store),
)
