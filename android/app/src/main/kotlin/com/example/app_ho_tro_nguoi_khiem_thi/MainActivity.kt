package com.example.app_ho_tro_nguoi_khiem_thi

import android.content.Context
import android.view.accessibility.AccessibilityManager
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
    private var accessibilityChannel: MethodChannel? = null
    private var explorationListener: AccessibilityManager.TouchExplorationStateChangeListener? = null
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
        // Khi tuy chon phim tat TAT, Android nhan nguyen ven su kien phim am luong.
        // Khi bat phan hoi ra man hinh (touch exploration), khong chiem phim
        // de tranh can tro thao tac TalkBack tren dien thoai.
        if (!captureEnabled || !isVolumeKey(event.keyCode)) {
            return super.dispatchKeyEvent(event)
        }
        val accessibility = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        if (accessibility.isTouchExplorationEnabled) {
            return super.dispatchKeyEvent(event)
        }
        val code = event.keyCode
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
                        if (captureEnabled && heldKey == code && !holdFired &&
                            !accessibility.isTouchExplorationEnabled) {
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
                if (heldKey == code) return true // Khong tang/giam lien tuc khi BAT phim tat.
                if (heldKey != null && heldKey != code) {
                    // Khong co y chiem to hop 2 phim. Co gang tra lai he thong.
                    // Tuy nhien khong the bao dam tren moi Android khi tuy chon BAT.
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
                        // Khi BAT phim tat, bam ngan van doi 1 nac am luong.
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
        explorationListener?.let { listener ->
            val manager = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
            manager.removeTouchExplorationStateChangeListener(listener)
        }
        explorationListener = null
        accessibilityChannel?.setMethodCallHandler(null)
        accessibilityChannel = null
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
        // Touch exploration is the relevant accessibility mode for TalkBack.
        // Do not query which app/service is enabled or request accessibility permissions.
        val accessibility = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        accessibilityChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "money_recognition/touch_exploration"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "isTouchExplorationEnabled") {
                    result.success(accessibility.isTouchExplorationEnabled)
                } else {
                    result.notImplemented()
                }
            }
            explorationListener?.let { listener ->
                accessibility.removeTouchExplorationStateChangeListener(listener)
            }
            val listener = AccessibilityManager.TouchExplorationStateChangeListener { enabled ->
                channel.invokeMethod("onTouchExplorationChanged", enabled)
            }
            explorationListener = listener
            accessibility.addTouchExplorationStateChangeListener(listener)
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
