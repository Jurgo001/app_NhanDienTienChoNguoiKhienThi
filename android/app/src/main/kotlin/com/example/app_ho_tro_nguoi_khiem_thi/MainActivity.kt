package com.example.app_ho_tro_nguoi_khiem_thi

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "money_recognition/camera_capabilities"
        ).setMethodCallHandler { call, result ->
            if (call.method != "hasTorch") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val cameraId = call.argument<String>("cameraId")
            val supported = if (cameraId == null) false else runCatching {
                val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                manager.getCameraCharacteristics(cameraId)
                    .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }.getOrDefault(false)
            result.success(supported)
        }
    }
}
