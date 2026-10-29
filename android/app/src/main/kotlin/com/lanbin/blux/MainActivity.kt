package com.lanbin.blux

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.provider.CalendarContract
import android.provider.CalendarContract.Calendars
import android.provider.CalendarContract.Events
import android.provider.CalendarContract.Reminders
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/// System-calendar reminders for the daily ad-log tasks.
/// Channel "kitt/calendar": hasPermission / ensurePermission /
/// createEvent / eventExists / deleteEvent.
///
/// createEvent never throws: it answers {"id": <long>} on success or
/// {"error": "<reason>"} on failure, so the UI can tell the user *why*
/// nothing showed up in their calendar instead of failing silently.
class MainActivity : FlutterActivity() {

    private var pendingPerm: MethodChannel.Result? = null

    companion object {
        private const val REQ_CAL = 9001

        /// local calendar created when the device has no account we can
        /// write into (very common on ROMs without a Google account)
        private const val LOCAL_ACCOUNT = "K.I.T.T."
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kitt/calendar")
            .setMethodCallHandler { call, result -> onCall(call, result) }
    }

    private fun hasCal(): Boolean =
        checkSelfPermission(Manifest.permission.WRITE_CALENDAR) ==
                PackageManager.PERMISSION_GRANTED &&
        checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
                PackageManager.PERMISSION_GRANTED

    private fun onCall(call: MethodCall, r: MethodChannel.Result) {
        try {
            when (call.method) {
                "hasPermission" -> r.success(hasCal())
                "ensurePermission" -> ensurePerm(r)
                "createEvent" -> r.success(
                    createEvent(
                        call.argument<String>("title") ?: "K.I.T.T.",
                        (call.argument<Number>("startMs") ?: 0L).toLong(),
                        (call.argument<Number>("durationMin") ?: 10).toInt(),
                        (call.argument<Number>("reminderMin") ?: 0).toInt()))
                "eventExists" -> r.success(
                    eventExists((call.argument<Number>("id") ?: 0L).toLong()))
                "deleteEvent" -> r.success(
                    deleteEvent((call.argument<Number>("id") ?: 0L).toLong()))
                else -> r.notImplemented()
            }
        } catch (e: Exception) {
            // never throw back to Dart (startup calls this before any UI)
            if (call.method == "createEvent") {
                r.success(err("日历异常：${e.javaClass.simpleName}"))
            } else {
                r.success(null)
            }
        }
    }

    // ---- permission ----

    private fun ensurePerm(r: MethodChannel.Result) {
        if (hasCal()) {
            r.success(true)
            return
        }
        // settle any earlier hanging request so Dart never awaits forever
        pendingPerm?.success(false)
        pendingPerm = r
        requestPermissions(
            arrayOf(Manifest.permission.WRITE_CALENDAR,
                    Manifest.permission.READ_CALENDAR), REQ_CAL)
    }

    override fun onRequestPermissionsResult(requestCode: Int,
                                            permissions: Array<out String>,
                                            grantResults: IntArray) {
        // required: FlutterActivity forwards to activity-aware plugins
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_CAL) {
            val res = pendingPerm
            pendingPerm = null
            res?.success(grantResults.isNotEmpty() &&
                    grantResults.all { it == PackageManager.PERMISSION_GRANTED })
        }
    }

    // ---- calendar plumbing ----

    private fun err(msg: String): Map<String, Any?> = mapOf("error" to msg)

    /// first *visible* calendar the app can actually write into (Google
    /// preferred); when none is visible we create our own local calendar
    /// instead of writing into a calendar the user never sees
    private fun pickCalendarId(): Long? {
        val scored = mutableListOf<Pair<Long, Int>>()
        try {
            contentResolver.query(
                Calendars.CONTENT_URI,
                arrayOf(Calendars._ID, Calendars.ACCOUNT_TYPE, Calendars.VISIBLE),
                "${Calendars.CALENDAR_ACCESS_LEVEL}>=? AND ${Calendars.VISIBLE}=1",
                arrayOf(Calendars.CAL_ACCESS_CONTRIBUTOR.toString()),
                null
            )?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getLong(0)
                    val type = c.getString(1)
                    if (type != null && type.contains("contact", ignoreCase = true)) {
                        continue
                    }
                    var score = 0
                    if (type == "com.google") score += 2
                    if (type == CalendarContract.ACCOUNT_TYPE_LOCAL) score += 1
                    scored += id to score
                }
            }
        } catch (e: Exception) {
            // provider missing / no permission — try the local fallback below
        }
        scored.maxByOrNull { it.second }?.let { return it.first }
        return ensureLocalCalendar()
    }

    /// read-only calendar ("K.I.T.T.") used when there is no account to
    /// write into; creating it needs the sync-adapter query parameters
    private fun ensureLocalCalendar(): Long? {
        val syncUri = Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(Calendars.ACCOUNT_NAME, LOCAL_ACCOUNT)
            .appendQueryParameter(Calendars.ACCOUNT_TYPE,
                    CalendarContract.ACCOUNT_TYPE_LOCAL)
            .build()
        try {
            contentResolver.query(
                syncUri,
                arrayOf(Calendars._ID),
                "${Calendars.ACCOUNT_NAME}=? AND ${Calendars.ACCOUNT_TYPE}=?",
                arrayOf(LOCAL_ACCOUNT, CalendarContract.ACCOUNT_TYPE_LOCAL),
                null
            )?.use { c -> if (c.moveToFirst()) return c.getLong(0) }

            val v = ContentValues().apply {
                put(Calendars.ACCOUNT_NAME, LOCAL_ACCOUNT)
                put(Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
                put(Calendars.NAME, LOCAL_ACCOUNT)
                put(Calendars.CALENDAR_DISPLAY_NAME, LOCAL_ACCOUNT)
                put(Calendars.CALENDAR_COLOR, 0xFFD50000.toInt())
                put(Calendars.CALENDAR_ACCESS_LEVEL, Calendars.CAL_ACCESS_OWNER)
                put(Calendars.OWNER_ACCOUNT, LOCAL_ACCOUNT)
                put(Calendars.VISIBLE, 1)
                put(Calendars.SYNC_EVENTS, 1)
                put(Calendars.CALENDAR_TIME_ZONE, TimeZone.getDefault().id)
            }
            val uri = contentResolver.insert(syncUri, v) ?: return null
            return ContentUris.parseId(uri)
        } catch (e: Exception) {
            return null
        }
    }

    private fun createEvent(title: String, startMs: Long,
                            durMin: Int, remMin: Int): Map<String, Any?> {
        if (!hasCal()) return err("未获得日历权限")
        if (startMs <= 0L) return err("日程时间无效")
        val calId = pickCalendarId() ?: return err("系统里没有可写入的日历")
        val id = try {
            val v = ContentValues().apply {
                put(Events.CALENDAR_ID, calId)
                put(Events.TITLE, title)
                put(Events.DESCRIPTION, "由 K.I.T.T. 每日广告记录自动生成")
                put(Events.DTSTART, startMs)
                put(Events.DTEND, startMs + durMin.coerceAtLeast(1) * 60_000L)
                // required — CalendarContract throws without it
                put(Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
                // the calendar app only pops an alarm when HAS_ALARM is set
                put(Events.HAS_ALARM, 1)
            }
            val uri = contentResolver.insert(Events.CONTENT_URI, v)
                ?: return err("日历拒绝写入日程")
            ContentUris.parseId(uri)
        } catch (e: Exception) {
            return err("写入日历失败：${e.javaClass.simpleName}")
        }
        if (id <= 0L) return err("日历返回了无效的日程 id")

        try {
            val rv = ContentValues().apply {
                put(Reminders.EVENT_ID, id)
                put(Reminders.MINUTES, remMin.coerceAtLeast(0))
                put(Reminders.METHOD, Reminders.METHOD_ALERT)
            }
            contentResolver.insert(Reminders.CONTENT_URI, rv)
        } catch (e: Exception) {
            // calendar without reminder support: the event still exists
            return mapOf("id" to id, "error" to "该日历不支持提醒，日程已写入但不会弹通知")
        }
        return mapOf("id" to id)
    }

    private fun eventExists(id: Long): Boolean {
        if (!hasCal()) return false
        try {
            contentResolver.query(
                ContentUris.withAppendedId(Events.CONTENT_URI, id),
                arrayOf(Events._ID), null, null, null)
                ?.use { return it.moveToFirst() }
        } catch (e: Exception) { /* fallthrough */ }
        return false
    }

    private fun deleteEvent(id: Long): Boolean = try {
        contentResolver.delete(
            ContentUris.withAppendedId(Events.CONTENT_URI, id),
            null, null)
        true // rows==0 is fine too: already gone — callers only drop the key
    } catch (e: Exception) {
        false // SecurityException: event belongs to a calendar we can't touch
    }
}
