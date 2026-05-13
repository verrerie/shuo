package app.shuo.network

sealed class RealtimeEvent {
    object Connected : RealtimeEvent()
    data class Delta(val text: String) : RealtimeEvent()
    data class Completed(val text: String) : RealtimeEvent()
    data class Error(val code: String) : RealtimeEvent()
    data class Closed(val code: Int) : RealtimeEvent()
}
