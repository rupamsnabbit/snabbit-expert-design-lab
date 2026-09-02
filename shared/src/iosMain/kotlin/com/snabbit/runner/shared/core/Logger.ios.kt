package com.snabbit.runner.shared.core

actual fun defaultLogger(): Logger = IosLogger

private object IosLogger : Logger {
    override fun d(tag: String, message: String) {
        println("D/$tag: $message")
    }

    override fun w(tag: String, message: String, throwable: Throwable?) {
        println("W/$tag: $message${throwable?.let { " (${it.message})" }.orEmpty()}")
    }

    override fun e(tag: String, message: String, throwable: Throwable?) {
        println("E/$tag: $message${throwable?.let { " (${it.message})" }.orEmpty()}")
    }
}
