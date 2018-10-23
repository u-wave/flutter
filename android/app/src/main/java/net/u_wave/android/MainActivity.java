package net.u_wave.android;

import android.os.Bundle;
import android.content.Intent;
import io.flutter.app.FlutterActivity;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
  private static PlayerPlugin player;
  private static NotificationPlugin notifications;
  private static WebSocketPlugin webSocket;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);

    player = PlayerPlugin.registerWith(registrarFor(PlayerPlugin.class.getName()));
    notifications = NotificationPlugin.registerWith(registrarFor(NotificationPlugin.class.getName()));
    webSocket = WebSocketPlugin.registerWith(registrarFor(WebSocketPlugin.class.getName()));

    ListenService.registerWith(registrarFor(ListenService.class.getName()));
  }

  public static PlayerPlugin getPlayer() {
    return player;
  }
  public static NotificationPlugin getNotifications() {
    return notifications;
  }
  public static WebSocketPlugin getWebSocket() {
    return webSocket;
  }
}
