package net.u_wave.android;

import android.app.Notification;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.support.v4.app.NotificationCompat;
import android.support.v4.app.NotificationManagerCompat;
import android.widget.RemoteViews;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.util.List;
import java.util.Map;

public class NotificationPlugin
    implements MethodCallHandler, SharedPreferences.OnSharedPreferenceChangeListener {
  public static final String NAME = "u-wave.net/notification";
  private static final String PREFERENCE_NAME = "flutter.nowPlayingNotification";
  private static final int NOTIFY_NOW_PLAYING = 0;

  private static final String ACTION_UPVOTE = "net.u_wave.android.UPVOTE";
  private static final String ACTION_DOWNVOTE = "net.u_wave.android.DOWNVOTE";
  private static final String ACTION_MUTE_UNMUTE = "net.u_wave.android.MUTE_UNMUTE";
  private static final String ACTION_DISCONNECT = "net.u_wave.android.DISCONNECT";

  /** Plugin registration. */
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), NAME);
    channel.setMethodCallHandler(new NotificationPlugin(registrar));
  }

  private final Registrar registrar;
  private final SharedPreferences preferences;
  private NowPlayingNotification nowPlayingNotification;
  private NowPlaying nowPlaying;
  private boolean enabled = true;

  private NotificationPlugin(Registrar registrar) {
    final Context context = registrar.context();
    this.registrar = registrar;

    nowPlayingNotification = new NowPlayingNotification(context);
    preferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);

    preferences.registerOnSharedPreferenceChangeListener(this);
    setEnabled(preferences.getBoolean(PREFERENCE_NAME, enabled));
  }

  public void close() {
    cancelNowPlayingNotification();
    preferences.unregisterOnSharedPreferenceChangeListener(this);
  }

  private NotificationManagerCompat getNotificationManager() {
    return NotificationManagerCompat.from(registrar.context());
  }

  private void setEnabled(boolean enabled) {
    this.enabled = enabled;
    if (nowPlaying != null) {
      if (enabled) {
        publishNowPlayingNotification();
      } else {
        cancelNowPlayingNotification();
      }
    }
  }

  private void publishNowPlayingNotification() {
    NotificationManagerCompat manager = getNotificationManager();
    manager.notify(NOTIFY_NOW_PLAYING, nowPlayingNotification.build());
  }

  private void cancelNowPlayingNotification() {
    NotificationManagerCompat manager = getNotificationManager();
    manager.cancel(NOTIFY_NOW_PLAYING);
  }

  private void onNowPlaying(Map<String, String> args, Result result) {
    if (args == null) {
      nowPlaying = null;
      cancelNowPlayingNotification();
      result.success(null);
      return;
    }

    System.out.println(
        "[NotificationPlugin] nowPlaying: " + args.get("artist") + " - " + args.get("title"));
    final int duration = Integer.parseInt(args.get("duration"));
    final int seek = Integer.parseInt(args.get("seek"));

    nowPlaying = new NowPlaying(args.get("artist"), args.get("title"), duration, seek);
    nowPlayingNotification.update(nowPlaying);

    if (enabled) publishNowPlayingNotification();

    result.success(null);
  }

  private void onProgress(List<Integer> args, Result result) {
    if (args.size() != 2) {
      throw new IllegalArgumentException(
          "Incorrect number of arguments to setProgress, expected 2");
    }
    if (nowPlaying == null) {
      throw new RuntimeException("No media is currently played");
    }

    final int progress = args.get(0);
    final int duration = args.get(1);

    nowPlaying.setProgress(duration, progress);
    nowPlayingNotification.update(nowPlaying);

    if (enabled) publishNowPlayingNotification();

    result.success(null);
  }

  /* MethodCallHandler */
  @Override
  @SuppressWarnings("unchecked")
  public void onMethodCall(MethodCall call, Result result) {
    switch (call.method) {
      case "nowPlaying":
        onNowPlaying((Map<String, String>) call.arguments, result);
        return;
      case "setProgress":
        onProgress((List<Integer>) call.arguments, result);
        return;
      default:
        result.notImplemented();
        return;
    }
  }

  /* OnSharedPreferenceChangeListener */
  public void onSharedPreferenceChanged(SharedPreferences self, String key) {
    if (!key.equals(PREFERENCE_NAME)) {
      return;
    }

    setEnabled(self.getBoolean(PREFERENCE_NAME, enabled));
  }

  private static class NowPlaying {
    public final String artist;
    public final String title;
    public int duration;
    public int progress;

    NowPlaying(String artist, String title, int duration, int progress) {
      this.artist = artist;
      this.title = title;
      this.duration = duration;
      this.progress = progress;
    }

    public void setProgress(int duration, int progress) {
      this.duration = duration;
      this.progress = progress;
    }
  }

  private static class NowPlayingNotification {
    private static final String NAME = "u-wave.net/nowPlaying";

    private NotificationCompat.Builder builder;
    private RemoteViews view;
    private Context context;

    NowPlayingNotification(Context context) {
      this.context = context;
      create();
    }

    private void create() {
      view = new RemoteViews("net.u_wave.android", R.layout.player_notification);

      // TODO hook these up via a background service.
      view.setOnClickPendingIntent(
          R.id.upvote,
          PendingIntent.getBroadcast(
              context,
              NOTIFY_NOW_PLAYING,
              new Intent(ACTION_UPVOTE),
              PendingIntent.FLAG_UPDATE_CURRENT));
      view.setOnClickPendingIntent(
          R.id.downvote,
          PendingIntent.getBroadcast(
              context,
              NOTIFY_NOW_PLAYING,
              new Intent(ACTION_DOWNVOTE),
              PendingIntent.FLAG_UPDATE_CURRENT));
      view.setOnClickPendingIntent(
          R.id.muteUnmute,
          PendingIntent.getBroadcast(
              context,
              NOTIFY_NOW_PLAYING,
              new Intent(ACTION_MUTE_UNMUTE),
              PendingIntent.FLAG_UPDATE_CURRENT));
      view.setOnClickPendingIntent(
          R.id.disconnect,
          PendingIntent.getBroadcast(
              context,
              NOTIFY_NOW_PLAYING,
              new Intent(ACTION_DISCONNECT),
              PendingIntent.FLAG_UPDATE_CURRENT));

      builder =
          new NotificationCompat.Builder(context, NAME)
              .setOngoing(true)
              .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
              .setSmallIcon(R.mipmap.ic_launcher)
              .setCustomContentView(view);
    }

    public Notification build() {
      return builder.build();
    }

    public void update(NowPlaying nowPlaying) {
      create();
      view.setTextViewText(R.id.artist, nowPlaying.artist);
      view.setTextViewText(R.id.title, nowPlaying.title);
      view.setProgressBar(R.id.progressBar, nowPlaying.duration, nowPlaying.progress, false);
    }
  }
}
