package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.features.kavach.shield.data.store.ModelAssetResolver

/** Deterministic resolver — returns a fake absolute path per file, no real I/O. */
class FakeModelAssetResolver(
    private val base: String = "/tmp/models",
) : ModelAssetResolver {
    var resolved: MutableList<String> = mutableListOf()
        private set

    override suspend fun resolve(fileName: String): String {
        resolved.add(fileName)
        return "$base/$fileName"
    }
}
