package app.shuo.settings

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import java.time.LocalDate

class ConfigStore(context: Context) {

    private val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)

    private val secure: SharedPreferences = EncryptedSharedPreferences.create(
        "shuo_secure",
        masterKeyAlias,
        context,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    private val prefs: SharedPreferences =
        context.getSharedPreferences("shuo", Context.MODE_PRIVATE)

    var apiKey: String
        get() = secure.getString("openai_api_key", "") ?: ""
        set(value) { secure.edit().putString("openai_api_key", value).apply() }

    var defaultLanguage: String
        get() = prefs.getString("default_language", "zh") ?: "zh"
        set(value) { prefs.edit().putString("default_language", value).apply() }

    var dailyCapMinutes: Int
        get() = prefs.getInt("daily_cap_minutes", 60)
        set(value) { prefs.edit().putInt("daily_cap_minutes", value).apply() }

    val dailyUsageSeconds: Int
        get() {
            val today = LocalDate.now().toString()
            val savedDay = prefs.getString("usage_day", "") ?: ""
            return if (savedDay == today) prefs.getInt("daily_usage_seconds", 0) else 0
        }

    val capReached: Boolean
        get() = dailyUsageSeconds >= dailyCapMinutes * 60

    fun addUsageSeconds(seconds: Int) {
        val today = LocalDate.now().toString()
        val current = dailyUsageSeconds
        prefs.edit()
            .putString("usage_day", today)
            .putInt("daily_usage_seconds", current + seconds)
            .apply()
    }

    fun wipeApiKey() {
        secure.edit().remove("openai_api_key").apply()
    }
}
