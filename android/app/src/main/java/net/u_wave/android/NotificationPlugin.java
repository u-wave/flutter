package net.u_wave.android;

import java.util.Map;
import android.app.Notification;
import android.app.NotificationManager;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

public class NotificationPlugin implements MethodCallHandler {
  public static final String NAME = "u-wave.net/notification";
  private static final int NOTIFY_NOW_PLAYING = 0;

  /** Plugin registration. */
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), NAME);
    channel.setMethodCallHandler(new NotificationPlugin(registrar));
  }

  private final Registrar registrar;

  private NotificationPlugin(Registrar registrar) {
    this.registrar = registrar;
  }

  private void onNowPlaying(Map<String, String> args, Result result) {
    NotificationManager manager = registrar.context()
      .getSystemService(NotificationManager.class);
    Notification.Style style = new Notification.MediaStyle();
    manager.notify(NOTIFY_NOW_PLAYING,
        new Notification.Builder(registrar.context())
          .setContentTitle(args.get("title"))
          .setContentText(args.get("artist"))
          .setStyle(style)
          .setOngoing(true)
          .setProgress(100, 70, false)
          .build());
    result.success(null);
  }

  /* MethodCallHandler */
  @Override
  public void onMethodCall(MethodCall call, Result result) {
    if (call.method.equals("nowPlaying")) {
      onNowPlaying((Map<String, String>) call.arguments, result);
    } else {
      result.notImplemented();
    }
  }
}
