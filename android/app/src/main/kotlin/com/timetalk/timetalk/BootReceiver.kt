package com.timetalk.timetalk

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.app.AlarmManager
import android.app.PendingIntent

/**
 * Boot Receiver for Talk Time - BULLETPROOF VERSION
 * 
 * CRITICAL: This receiver restarts the background service when:
 * - Phone boots up
 * - App is updated
 * - Quick boot completes (device-specific)
 * - Locked boot completes (direct boot)
 * 
 * This ensures the time announcement service continues working
 * even after phone restarts, for disabled users who rely on it.
 * 
 * BULLETPROOF APPROACH:
 * 1. Sets flags in SharedPreferences to trigger Flutter service restart
 * 2. flutter_background_service with autoStartOnBoot: true handles the rest
 * 3. AlarmManager backup is set by Flutter code
 */
class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "TalkTime_BootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "============================================")
        Log.d(TAG, ">>> BOOT RECEIVER TRIGGERED <<<")
        Log.d(TAG, "Action: $action")
        Log.d(TAG, "============================================")
        
        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                Log.d(TAG, ">>> Starting Talk Time background service after boot/update")
                handleBootComplete(context)
            }
        }
    }
    
    private fun handleBootComplete(context: Context) {
        try {
            // Check if service should be running
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            // flutter_shared_preferences prefixes keys with "flutter."
            val serviceRunning = prefs.getBoolean("flutter.service_running", false)
            val intervalMinutes = prefs.getLong("flutter.intervalMinutes", 0L)
            
            Log.d(TAG, "Service should run: $serviceRunning")
            Log.d(TAG, "Interval: $intervalMinutes minutes")
            
            if (serviceRunning && intervalMinutes > 0) {
                Log.d(TAG, "✓ Conditions met for service restart")
                
                // Mark boot completed so Flutter knows to check service
                prefs.edit()
                    .putBoolean("flutter.boot_completed", true)
                    .putLong("flutter.boot_time", System.currentTimeMillis())
                    .apply()
                
                // The flutter_background_service plugin with autoStartOnBoot: true
                // will handle restarting the service automatically.
                // This receiver just sets flags and logs the event.
                
                Log.d(TAG, "✓ Boot flags set - Flutter service will auto-restart")
                Log.d(TAG, "============================================")
                
            } else {
                Log.d(TAG, "✗ Service not configured to run or interval is 0")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in boot handler: ${e.message}", e)
        }
    }
}
