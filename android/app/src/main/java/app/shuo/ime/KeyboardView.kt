package app.shuo.ime

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import app.shuo.R
import app.shuo.controller.DictationState

class KeyboardView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : FrameLayout(context, attrs) {

    private val pulseCircle: View
    private val stopButton: TextView
    private val langButton: TextView
    private val statusLabel: TextView
    private var pulseAnimator: ObjectAnimator? = null

    var onStopClick: (() -> Unit)? = null
    var onLangClick: (() -> Unit)? = null

    init {
        LayoutInflater.from(context).inflate(R.layout.keyboard_view, this, true)
        pulseCircle = findViewById(R.id.pulse_circle)
        stopButton = findViewById(R.id.stop_button)
        langButton = findViewById(R.id.lang_button)
        statusLabel = findViewById(R.id.status_label)
        stopButton.setOnClickListener { onStopClick?.invoke() }
        langButton.setOnClickListener { onLangClick?.invoke() }
    }

    fun render(state: DictationState, language: String) {
        langButton.text = language
        when (state) {
            is DictationState.Recording -> {
                stopButton.visibility = VISIBLE
                statusLabel.visibility = GONE
                startPulse()
            }
            is DictationState.Finalizing -> {
                stopButton.visibility = INVISIBLE
                statusLabel.visibility = VISIBLE
                statusLabel.text = "…"
                stopPulse()
            }
            is DictationState.Error -> {
                stopButton.visibility = GONE
                statusLabel.visibility = VISIBLE
                statusLabel.text = context.getString(errorStringRes(state.message))
                stopPulse()
            }
            DictationState.Idle -> {
                stopButton.visibility = GONE
                statusLabel.visibility = GONE
                stopPulse()
            }
        }
    }

    private fun errorStringRes(code: String): Int = when (code) {
        "no_api_key" -> R.string.error_no_api_key
        "cap_reached" -> R.string.error_cap_reached
        "401" -> R.string.error_api_rejected
        else -> R.string.error_generic
    }

    private fun startPulse() {
        if (pulseAnimator != null) return
        pulseAnimator = ObjectAnimator.ofFloat(pulseCircle, "alpha", 0.4f, 1.0f).apply {
            duration = 1000
            repeatMode = ValueAnimator.REVERSE
            repeatCount = ValueAnimator.INFINITE
            start()
        }
    }

    private fun stopPulse() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        pulseCircle.alpha = 1.0f
    }
}
