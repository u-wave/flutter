package net.u_wave.client

import java.net.URL
import okhttp3.OkHttpClient
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.channels.broadcast
import kotlinx.coroutines.channels.consumeEach

data class UwaveServer(
  val apiUrl: URL,
  val socketUrl: URL
)

data class User(
  val userID: String,
  var avatar: String,
  var username: String,
  var roles: ArrayList<String>
)

class UwaveClient(val client: OkHttpClient, val server: UwaveServer) {
  val socket = Socket(client, server.socketUrl)
  val messages = socket.messages.broadcast()

  init {
    GlobalScope.launch {
      messages.openSubscription().consumeEach {
        print(it)
      }
    }
  }
}
