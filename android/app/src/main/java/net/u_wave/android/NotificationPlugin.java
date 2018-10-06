package net.u_wave.android;

import java.util.Map;
import android.R;
import android.support.v4.app.NotificationCompat;
import android.support.v4.app.NotificationManagerCompat;
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
  private NotificationCompat.Builder notificationBuilder;

  private NotificationPlugin(Registrar registrar) {
    this.registrar = registrar;

    notificationBuilder = new NotificationCompat.Builder(registrar.context(), NAME)
      .setSmallIcon(R.drawable.ic_media_play)
      .setOngoing(true);
  }

  private void onNowPlaying(Map<String, String> args, Result result) {
    System.out.println("[NotificationPlugin] nowPlaying: " + args.get("artist") + " - " + args.get("title"));

    notificationBuilder
      .setContentTitle(args.get("title"))
      .setContentText(args.get("artist"))
      .setProgress(100, 70, false)
      .build();

    NotificationManagerCompat manager = NotificationManagerCompat.from(registrar.context());
    manager.notify(NOTIFY_NOW_PLAYING, notificationBuilder.build());

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
