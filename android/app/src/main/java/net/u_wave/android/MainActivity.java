package net.u_wave.android;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import io.flutter.app.FlutterActivity;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
  private static final String TAG = "MainActivity";
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

    final ListenController controller = new ListenController(this);

    controller.registerWith(registrarFor(ListenService.class.getName()));

    Log.d(TAG, "Created");
  }

  @Override
  protected void onDestroy() {
    super.onDestroy();

    Log.d(TAG, "Destroyed");
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
