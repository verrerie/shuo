package app.shuo.ime

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.content.res.ColorStateList
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import app.shuo.R
import app.shuo.controller.DictationState

class KeyboardView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : FrameLayout(context, attrs) {

    private val micButton: View
    private val langButton: TextView
    private val statusLabel: TextView
    private var pulseAnimator: ObjectAnimator? = null

    var onMicTap: (() -> Unit)? = null
    var onLangClick: (() -> Unit)? = null

    init {
        LayoutInflater.from(context).inflate(R.layout.keyboard_view, this, true)
        micButton = findViewById(R.id.mic_button)
        langButton = findViewById(R.id.lang_button)
        statusLabel = findViewById(R.id.status_label)
        micButton.setOnClickListener { onMicTap?.invoke() }
        langButton.setOnClickListener { onLangClick?.invoke() }
    }

    fun render(state: DictationState, language: String) {
        langButton.text = language
        when (state) {
            is DictationState.Idle -> {
                tintMic(R.color.mic_idle)
                statusLabel.visibility = GONE
                stopPulse()
            }
            is DictationState.Recording -> {
                tintMic(R.color.mic_recording)
                statusLabel.visibility = GONE
                startPulse()
            }
            is DictationState.Finalizing -> {
                tintMic(R.color.mic_finalizing)
                statusLabel.visibility = VISIBLE
                statusLabel.text = "…"
                stopPulse()
            }
            is DictationState.Error -> {
                tintMic(R.color.mic_error)
                statusLabel.visibility = VISIBLE
                statusLabel.text = context.getString(errorStringRes(state.message))
                stopPulse()
            }
        }
    }

    private fun tintMic(colorRes: Int) {
        micButton.backgroundTintList =
            ColorStateList.valueOf(ContextCompat.getColor(context, colorRes))
    }

    private fun errorStringRes(code: String): Int = when (code) {
        "no_api_key" -> R.string.error_no_api_key
        "cap_reached" -> R.string.error_cap_reached
        "401" -> R.string.error_api_rejected
        else -> R.string.error_generic
    }

    private fun startPulse() {
        if (pulseAnimator != null) return
        pulseAnimator = ObjectAnimator.ofFloat(micButton, "alpha", 0.55f, 1.0f).apply {
            duration = 800
            repeatMode = ValueAnimator.REVERSE
            repeatCount = ValueAnimator.INFINITE
            start()
        }
    }

    private fun stopPulse() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        micButton.alpha = 1.0f
    }
}
