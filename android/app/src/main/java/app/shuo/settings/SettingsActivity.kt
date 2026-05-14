package app.shuo.settings

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.Spinner
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import app.shuo.R

class SettingsActivity : AppCompatActivity() {

    private lateinit var config: ConfigStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)
        config = ConfigStore(this)

        val apiKeyField = findViewById<EditText>(R.id.api_key_field)
        val langSpinner = findViewById<Spinner>(R.id.lang_spinner)
        val capField = findViewById<EditText>(R.id.cap_field)
        val saveButton = findViewById<Button>(R.id.save_button)

        apiKeyField.setText(config.apiKey)
        capField.setText(config.dailyCapMinutes.toString())

        val langs = listOf("zh", "en", "fr")
        langSpinner.setSelection(langs.indexOf(config.defaultLanguage).coerceAtLeast(0))

        saveButton.setOnClickListener {
            config.apiKey = apiKeyField.text.toString().trim()
            config.defaultLanguage = langs[langSpinner.selectedItemPosition]
            config.dailyCapMinutes = capField.text.toString().toIntOrNull() ?: 60
            Toast.makeText(this, "Saved", Toast.LENGTH_SHORT).show()
        }

        requestMicrophonePermission()
    }

    private fun requestMicrophonePermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 1)
        }
    }
}
