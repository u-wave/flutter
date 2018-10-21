package net.u_wave.android;

import android.os.Bundle;
import io.flutter.app.FlutterActivity;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);

    PlayerPlugin.registerWith(registrarFor(PlayerPlugin.class.getName()));
    NotificationPlugin.registerWith(registrarFor(NotificationPlugin.class.getName()));
    WebSocketPlugin.registerWith(registrarFor(WebSocketPlugin.class.getName()));
  }
}
