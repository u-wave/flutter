package net.u_wave.android

import android.os.Bundle
import io.flutter.app.FlutterActivity
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity(): FlutterActivity() {
  override protected fun onCreate(savedInstanceState: Bundle) {
    super.onCreate(savedInstanceState)
    GeneratedPluginRegistrant.registerWith(this)

    PlayerPlugin.registerWith(registrarFor(PlayerPlugin::class.qualifiedName))
    NotificationPlugin.registerWith(registrarFor(NotificationPlugin::class.qualifiedName))
    WebSocketPlugin.registerWith(registrarFor(WebSocketPlugin::class.qualifiedName))
  }
}
