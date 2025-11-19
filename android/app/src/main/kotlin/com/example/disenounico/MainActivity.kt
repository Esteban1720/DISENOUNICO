package com.example.disenounico

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "disenounico/permissions"
	private val REQUEST_CODE_POST_NOTIFICATIONS = 12345
	private var pendingResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"requestNotificationPermission" -> {
					// If Android < 13, permission is granted by default
					if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
						result.success(true)
						return@setMethodCallHandler
					}
					// If already granted
					if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
						result.success(true)
						return@setMethodCallHandler
					}
					// request permission
					pendingResult = result
					ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE_POST_NOTIFICATIONS)
				}
				else -> result.notImplemented()
			}
		}
	}

	override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
		if (requestCode == REQUEST_CODE_POST_NOTIFICATIONS) {
			val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
			pendingResult?.success(granted)
			pendingResult = null
		}
	}
}
