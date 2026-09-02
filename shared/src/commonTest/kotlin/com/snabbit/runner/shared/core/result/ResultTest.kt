package com.snabbit.runner.shared.core.result

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ResultTest {

    @Test
    fun ok_holdsValue() {
        val result: Result<Int, String> = Result.Ok(42)
        assertTrue(result is Result.Ok)
        assertEquals(42, result.value)
    }

    @Test
    fun err_holdsError() {
        val result: Result<Int, String> = Result.Err("boom")
        assertTrue(result is Result.Err)
        assertEquals("boom", result.error)
    }

    @Test
    fun onSuccess_runsOnlyOnOk() {
        var called = false
        var seen: Int? = null

        Result.Ok<Int>(7).onSuccess { called = true; seen = it }
        assertTrue(called)
        assertEquals(7, seen)

        called = false
        Result.Err<String>("x").onSuccess { called = true }
        assertFalse(called)
    }

    @Test
    fun onError_runsOnlyOnErr() {
        var called = false
        var seen: String? = null

        Result.Err<String>("nope").onError { called = true; seen = it }
        assertTrue(called)
        assertEquals("nope", seen)

        called = false
        Result.Ok<Int>(1).onError { called = true }
        assertFalse(called)
    }

    @Test
    fun onSuccess_returnsSelf_forChaining() {
        val ok: Result<Int, String> = Result.Ok(1)
        assertEquals(ok, ok.onSuccess { })

        val err: Result<Int, String> = Result.Err("e")
        assertEquals(err, err.onSuccess { })
    }

    @Test
    fun onError_returnsSelf_forChaining() {
        val ok: Result<Int, String> = Result.Ok(1)
        assertEquals(ok, ok.onError { })

        val err: Result<Int, String> = Result.Err("e")
        assertEquals(err, err.onError { })
    }
}
