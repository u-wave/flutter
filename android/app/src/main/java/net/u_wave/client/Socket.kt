package net.u_wave.client

import java.net.URL
import kotlinx.serialization.*
import kotlinx.serialization.json.*
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.channels.ReceiveChannel
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener

private val json = Json(JsonConfiguration.Default)

// Messages for client actions
@Serializable
sealed class SendMessage(val command: String) {
  fun toJson() = json.stringify(serializer(), this)
}

@Serializable data class SendVoteMessage(@SerialName("data") val value: Int) : SendMessage("vote")
@Serializable data class SendChatMessage(@SerialName("data") val message: String) : SendMessage("sendChat")

// Notification messages from the server
@Serializable sealed class ReceiveMessage()
@Serializable data class ChatMessage(val id: String, val userID: String, val message: String, val timestamp: Int): ReceiveMessage()
@Serializable class ChatDeleteAllMessage() : ReceiveMessage()
@Serializable data class ChatDeleteOneMessage(@SerialName("_id") val id: String) : ReceiveMessage()
@Serializable data class ChatDeleteUserMessage(val userID: String) : ReceiveMessage()
// @Serializable data class UserJoinMessage(val user: User)
@Serializable data class UserLeaveMessage(val userID: String): ReceiveMessage()
@Serializable data class UserNameChangeMessage(val userID: String, val username: String) : ReceiveMessage()
@Serializable data class VoteMessage(@SerialName("_id") val userID: String, val value: Int): ReceiveMessage()
@Serializable data class FavoriteMessage(val userID: String, val historyID: String): ReceiveMessage()
@Serializable data class PlaylistCycleMessage(val playlistID: String): ReceiveMessage()
@Serializable data class WaitlistJoinMessage(val userID: String, val waitlist: ArrayList<String>): ReceiveMessage()
@Serializable data class WaitlistLeaveMessage(val userID: String, val waitlist: ArrayList<String>): ReceiveMessage()
@Serializable data class WaitlistAddMessage(val userID: String, val waitlist: ArrayList<String>): ReceiveMessage()
@Serializable data class WaitlistRemoveMessage(val userID: String, val waitlist: ArrayList<String>): ReceiveMessage()
@Serializable data class WaitlistUpdateMessage(val waitlist: ArrayList<String>): ReceiveMessage()
@Serializable data class WaitlistLockMessage(val locked: Boolean): ReceiveMessage()
@Serializable class WaitlistClearMessage() : ReceiveMessage()

private fun parseReceivedMessage(rawMessage: JsonObject): ReceiveMessage? =
  when (rawMessage.getAs<JsonLiteral>("command").content) {
    "chatMessage" -> json.fromJson<ChatMessage>(ChatMessage.serializer(), rawMessage.getAs<JsonObject>("data"))
    "chatDelete" -> ChatDeleteAllMessage()
    "chatDeleteByID" -> json.fromJson<ChatDeleteOneMessage>(ChatDeleteOneMessage.serializer(), rawMessage.getAs<JsonObject>("data"))
    "chatDeleteByUser" -> json.fromJson<ChatDeleteUserMessage>(ChatDeleteUserMessage.serializer(), rawMessage.getAs<JsonObject>("data"))
    "vote" -> json.fromJson<VoteMessage>(VoteMessage.serializer(), rawMessage.getAs<JsonObject>("data"))
    "favorite" -> json.fromJson<FavoriteMessage>(FavoriteMessage.serializer(), rawMessage.getAs<JsonObject>("data"))
    "playlistCycle" -> json.fromJson<PlaylistCycleMessage>(PlaylistCycleMessage.serializer(), rawMessage.getAs<JsonObject>("data"))
    "leave" -> json.fromJson<UserLeaveMessage>(UserLeaveMessage.serializer(), rawMessage.getAs<JsonObject>("data"))
    else -> null
  }

class Socket(socketFactory: WebSocket.Factory, val url: URL): WebSocketListener() {
  private var ws = Request.Builder()
    .url(url)
    .build()
    .let { request -> socketFactory.newWebSocket(request, this) }
  private val messageChannel = Channel<ReceiveMessage>()
  private var authToken: String? = null

  val messages: ReceiveChannel<ReceiveMessage>
    get() = this.messageChannel

  fun authenticate(authToken: String) {
    this.authToken = authToken
    ws.send(authToken)
  }

  // Send a message to the server.
  fun send(message: SendMessage) {
    ws.send(message.toJson())
  }

  private fun emit(message: ReceiveMessage) {
    val channel = this.messageChannel
    runBlocking {
      channel.send(message)
    }
  }

  // WebSocketListener

  override fun onOpen(ws: WebSocket, response: Response) {}
  override fun onMessage(ws: WebSocket, text: String) {
    if (text == "-") return
    val rawMessage = Json.plain.parseJson(text).jsonObject
    val message = parseReceivedMessage(rawMessage)

    message?.let { emit(it) }
  }
  override fun onClosing(ws: WebSocket, code: Int, reason: String) {}
  override fun onClosed(ws: WebSocket, code: Int, reason: String) {}
}
