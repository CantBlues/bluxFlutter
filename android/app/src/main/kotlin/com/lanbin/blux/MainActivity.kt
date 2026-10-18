package com.lanbin.blux

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/// System-calendar reminders for the daily ad-log tasks.
/// Channel "kitt/calendar": hasPermission / ensurePermission /
/// createEvent / eventExists / deleteEvent. Every failure degrades to
/// null/false — nothing is ever thrown back to Dart (startup calls this
/// before any UI exists, a denied permission must stay silent).
class MainActivity : FlutterActivity() {

    private var pendingPerm: MethodChannel.Result? = null

    companion object {
        private const val REQ_CAL = 9001
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
            r.success(null)
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

    /// first visible calendar the app can write into, preferring
    /// reminder-capable ones; null when the device has no usable account
    private fun pickCalendarId(): Long? {
        var id: Long? = null
        try {
            contentResolver.query(
                CalendarContract.Calendars.CONTENT_URI,
                arrayOf(CalendarContract.Calendars._ID),
                "visible=1 AND calendar_access_level>=300 " +
                        "AND (account_type IS NULL OR account_type NOT LIKE '%contact%')",
                null,
                "CASE WHEN calendar_reminders_supported=1 THEN 0 ELSE 1 END, " +
                        "CASE WHEN account_type='com.google' THEN 0 ELSE 1 END, _id")
                ?.use { c -> if (c.moveToFirst()) id = c.getLong(0) }
        } catch (e: Exception) {
            return null
        }
        return id
    }

    private fun createEvent(title: String, startMs: Long,
                            durMin: Int, remMin: Int): Long? {
        if (!hasCal()) return null
        try {
            val calId = pickCalendarId() ?: return null
            val v = ContentValues().apply {
                put(CalendarContract.Events.CALENDAR_ID, calId)
                put(CalendarContract.Events.TITLE, title)
                put(CalendarContract.Events.DTSTART, startMs)
                put(CalendarContract.Events.DTEND, startMs + durMin * 60_000L)
                // required — CalendarContract throws without it
                put(CalendarContract.Events.EVENT_TIMEZONE,
                        TimeZone.getDefault().id)
                // CalendarProvider only lets the creating package delete
                // events it owns; it tracks that package here
                put(CalendarContract.Events.SYNC_DATA2, packageName)
            }
            val uri = contentResolver.insert(
                CalendarContract.Events.CONTENT_URI, v) ?: return null
            val id = try {
                ContentUris.parseId(uri)
            } catch (e: NumberFormatException) {
                return null
            }
            v.clear()
            v.put(CalendarContract.Reminders.EVENT_ID, id)
            v.put(CalendarContract.Reminders.MINUTES, remMin)
            v.put(CalendarContract.Reminders.METHOD,
                  CalendarContract.Reminders.METHOD_ALERT)
            try {
                contentResolver.insert(CalendarContract.Reminders.CONTENT_URI, v)
            } catch (e: Exception) { /* calendar w/o reminders: event still made */ }
            return id
        } catch (e: Exception) {
            return null
        }
    }

    private fun eventExists(id: Long): Boolean {
        if (!hasCal()) return false
        try {
            contentResolver.query(
                ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id),
                arrayOf(CalendarContract.Events._ID), null, null, null)
                ?.use { return it.moveToFirst() }
        } catch (e: Exception) { /* fallthrough */ }
        return false
    }

    private fun deleteEvent(id: Long): Boolean = try {
        contentResolver.delete(
            ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id),
            null, null)
        true // rows==0 is fine too: already gone — callers only drop the key
    } catch (e: Exception) {
        false // SecurityException: ownership lost (event synced elsewhere)
    }
}
