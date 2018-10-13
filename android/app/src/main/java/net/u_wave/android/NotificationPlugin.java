package net.u_wave.android;

import android.app.Notification;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.support.v4.app.NotificationCompat;
import android.support.v4.app.NotificationManagerCompat;
import android.view.View;
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
    channel.setMethodCallHandler(new NotificationPlugin(registrar, channel));
  }

  private final Registrar registrar;
  private final MethodChannel channel;
  private final SharedPreferences preferences;
  private BroadcastReceiver receiver;
  private NowPlayingNotification nowPlayingNotification;
  private NowPlaying nowPlaying;
  private boolean enabled = true;
  private int vote = 0;

  private NotificationPlugin(Registrar registrar, MethodChannel channel) {
    final Context context = registrar.context();
    this.registrar = registrar;
    this.channel = channel;

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

    if (receiver == null) {
      receiver = new Receiver(channel);
      IntentFilter filter = new IntentFilter();
      filter.addAction(ACTION_UPVOTE);
      filter.addAction(ACTION_DOWNVOTE);
      filter.addAction(ACTION_MUTE_UNMUTE);
      filter.addAction(ACTION_DISCONNECT);
      registrar.context().registerReceiver(receiver, filter);
    }
  }

  private void cancelNowPlayingNotification() {
    if (receiver != null) {
      registrar.context().unregisterReceiver(receiver);
      receiver = null;
    }

    NotificationManagerCompat manager = getNotificationManager();
    manager.cancel(NOTIFY_NOW_PLAYING);
  }

  private void onNowPlaying(Map<String, String> args, Result result) {
    vote = 0;

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
    final boolean isCurrentUser = args.get("isCurrentUser").equals("true");

    nowPlaying = new NowPlaying(args.get("artist"), args.get("title"), duration, seek, isCurrentUser);
    nowPlayingNotification.update(nowPlaying);

    if (enabled) publishNowPlayingNotification();

    result.success(null);
  }

  private void onVote(int direction, Result result) {
    vote = direction;

    nowPlayingNotification.update(nowPlaying, vote);

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
    nowPlayingNotification.update(nowPlaying, vote);

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
      case "setVote":
        onVote((Integer) call.arguments, result);
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
    public boolean isCurrentUser;

    NowPlaying(String artist, String title, int duration, int progress, boolean isCurrentUser) {
      this.artist = artist;
      this.title = title;
      this.duration = duration;
      this.progress = progress;
      this.isCurrentUser = isCurrentUser;
    }

    public void setProgress(int duration, int progress) {
      this.duration = duration;
      this.progress = progress;
    }
  }

  private static class NowPlayingNotification {
    private static final String NAME = "u-wave.net/nowPlaying";

    private static final int NOVOTE = 0;
    private static final int UPVOTE = 1;
    private static final int DOWNVOTE = -1;

    private NotificationCompat.Builder builder;
    private RemoteViews view;
    private Context context;

    NowPlayingNotification(Context context) {
      this.context = context;
      create();
    }

    private void create() {
      view = new RemoteViews("net.u_wave.android", R.layout.player_notification);

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
      update(nowPlaying, NOVOTE);
    }

    public void update(NowPlaying nowPlaying, int vote) {
      create();

      view.setTextViewText(R.id.artist, nowPlaying.artist);
      view.setTextViewText(R.id.title, nowPlaying.title);
      view.setProgressBar(R.id.progressBar, nowPlaying.duration, nowPlaying.progress, false);

      if (nowPlaying.isCurrentUser) {
        view.setViewVisibility(R.id.upvote, vote == UPVOTE ? View.GONE : View.VISIBLE);
        view.setViewVisibility(R.id.upvoteActive, vote == UPVOTE ? View.VISIBLE : View.GONE);
        view.setViewVisibility(R.id.downvote, vote == DOWNVOTE ? View.GONE : View.VISIBLE);
        view.setViewVisibility(R.id.downvoteActive, vote == DOWNVOTE ? View.VISIBLE : View.GONE);
      } else {
        view.setViewVisibility(R.id.upvote, View.GONE);
        view.setViewVisibility(R.id.upvoteActive, View.GONE);
        view.setViewVisibility(R.id.downvote, View.GONE);
        view.setViewVisibility(R.id.downvoteActive, View.GONE);
      }
    }
  }

  private static class Receiver extends BroadcastReceiver {
    private final MethodChannel channel;

    Receiver(final MethodChannel channel) {
      this.channel = channel;
    }

    @Override
    public void onReceive(Context context, Intent intent) {
      System.out.println("Receiving broadcast: " + intent.getAction());
      // TODO these should use an EventChannel more likely?
      channel.invokeMethod("intent", intent.getAction());
    }
  }
}
