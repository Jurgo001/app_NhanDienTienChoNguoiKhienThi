package com.example.app_ho_tro_nguoi_khiem_thi

import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.KeyEvent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val holdDurationMs = 3000L
    private val handler = Handler(Looper.getMainLooper())
    private var shortcutsChannel: MethodChannel? = null
    private var captureEnabled = false
    private var countingMode = false
    private var heldKey: Int? = null
    private var holdFired = false
    private var holdTask: Runnable? = null
    private var firstDownTime = 0L
    private var bothKeysDown = false
    private val comboKeys = mutableSetOf<Int>()

    private fun isVolumeKey(code: Int) =
        code == KeyEvent.KEYCODE_VOLUME_UP || code == KeyEvent.KEYCODE_VOLUME_DOWN

    private fun clearHold() {
        holdTask?.let(handler::removeCallbacks)
        holdTask = null
        heldKey = null
        holdFired = false
        firstDownTime = 0L
    }

    private fun setCaptureEnabled(enabled: Boolean, isCounting: Boolean = false) {
        captureEnabled = enabled
        countingMode = isCounting
        if (!enabled) {
            clearHold()
            bothKeysDown = false
            comboKeys.clear()
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (!captureEnabled || !isVolumeKey(event.keyCode)) {
            return super.dispatchKeyEvent(event)
        }
        val code = event.keyCode
        // Ngoài chế độ đếm, phím giảm âm lượng luôn thuộc về Android,
        // trừ khi đang phát hiện tổ hợp hai phím.
        if (code == KeyEvent.KEYCODE_VOLUME_DOWN && !countingMode &&
            heldKey == null && !bothKeysDown) {
            return super.dispatchKeyEvent(event)
        }
        if (bothKeysDown) {
            if (event.action == KeyEvent.ACTION_DOWN) comboKeys.add(code)
            if (event.action == KeyEvent.ACTION_UP) {
                comboKeys.remove(code)
                if (comboKeys.isEmpty()) bothKeysDown = false
            }
            return super.dispatchKeyEvent(event)
        }
        when (event.action) {
            KeyEvent.ACTION_DOWN -> {
                if (heldKey == null && event.repeatCount == 0) {
                    heldKey = code
                    firstDownTime = event.downTime
                    holdFired = false
                    val task = Runnable {
                        if (captureEnabled && heldKey == code && !holdFired) {
                            holdFired = true
                            val action = if (code == KeyEvent.KEYCODE_VOLUME_UP)
                                "volume_up" else "volume_down"
                            shortcutsChannel?.invokeMethod("onLongPress", action)
                        }
                    }
                    holdTask = task
                    handler.postDelayed(task, holdDurationMs)
                    return true
                }
                if (heldKey == code) return true // Bỏ sự kiện auto-repeat.
                if (heldKey != null && heldKey != code) {
                    // Không chiếm tổ hợp hai phím. Cố gắng trả về hệ thống.
                    // Một số bản Android/TalkBack bắt tổ hợp ở mức OS trước Activity.
                    val first = heldKey!!
                    val replayDownTime = firstDownTime
                    clearHold()
                    bothKeysDown = true
                    comboKeys.add(first)
                    comboKeys.add(code)
                    super.dispatchKeyEvent(KeyEvent(
                        replayDownTime, SystemClock.uptimeMillis(),
                        KeyEvent.ACTION_DOWN, first, 0
                    ))
                    return super.dispatchKeyEvent(event)
                }
            }
            KeyEvent.ACTION_UP -> {
                if (heldKey == code) {
                    val completedHold = holdFired
                    clearHold()
                    if (!completedHold) {
                        // Nhấn ngắn: chỉnh đúng một nấc khi THẢ phím.
                        // Tránh đổi âm lượng liên tục trước khi đủ ba giây.
                        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val direction = if (code == KeyEvent.KEYCODE_VOLUME_UP)
                            AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER
                        audio.adjustSuggestedStreamVolume(
                            direction,
                            AudioManager.USE_DEFAULT_STREAM_TYPE,
                            AudioManager.FLAG_SHOW_UI
                        )
                    }
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onPause() {
        setCaptureEnabled(false)
        super.onPause()
    }

    override fun onDestroy() {
        setCaptureEnabled(false)
        shortcutsChannel?.setMethodCallHandler(null)
        shortcutsChannel = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shortcutsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "doc_tien_viet/volume_shortcuts"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "setCaptureEnabled") {
                    setCaptureEnabled(
                        call.argument<Boolean>("enabled") == true,
                        call.argument<Boolean>("countingMode") == true
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
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
