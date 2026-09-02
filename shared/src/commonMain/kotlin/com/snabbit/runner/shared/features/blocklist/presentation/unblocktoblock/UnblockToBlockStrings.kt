package com.snabbit.runner.shared.features.blocklist.presentation.unblocktoblock

import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.blocklist.presentation.list.BlockListStrings
import com.snabbit.runner.shared.features.blocklist.presentation.list.localized

/**
 * UI text for the "unblock to block" screen (shown when the runner tries to block someone but is
 * already at the block cap). Server-driven i18n, fed as data. [titlePrefix] precedes the customer's
 * name in the heading ("Unblock someone to block <name>"); [blockList] threads the block-list copy.
 */
data class UnblockToBlockStrings(
    /** i18n key `unblock_someone_to_block`. Heading before the (pink) customer name. */
    val titlePrefix: String = "Unblock someone to block",
    val blockList: BlockListStrings = BlockListStrings(),
)

/**
 * Overlays the server-driven i18n map onto these [UnblockToBlockStrings], threading the nested
 * [blockList] through [BlockListStrings.localized]. Absent keys fall back to English.
 */
fun UnblockToBlockStrings.localized(store: LocalizationStore): UnblockToBlockStrings = copy(
    titlePrefix = store.getMessage("block_list.title", titlePrefix),
    blockList = blockList.localized(store),
)
