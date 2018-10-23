package net.u_wave.android;

import org.json.JSONObject;
import org.json.JSONException;
import android.os.Binder;
import android.content.Context;
import android.content.Intent;
import android.app.Service;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

class ListenService extends Service {
  public static final String NAME = "u-wave.net/background";
  private PlayerPlugin player;
  private NotificationPlugin notifications;
  private WebSocketPlugin webSocket;

  public static void registerWith(Registrar registrar) {
    final Context context = registrar.activity();
    final Intent intent = new Intent(context, ListenService.class);
    final MethodChannel channel = new MethodChannel(registrar.messenger(), NAME);

    channel.setMethodCallHandler((call, result) -> {
      if (call.method.equals("start")) {
        context.startService(intent);
        result.success(null);
      } else if (call.method.equals("stop")) {
        context.stopService(intent);
        result.success(null);
      } else {
        result.notImplemented();
      }
    });
  }

  @Override
  public void onCreate() {
    player = MainActivity.getPlayer();
    notifications = MainActivity.getNotifications();
    webSocket = MainActivity.getWebSocket();

    if (player == null || notifications == null || webSocket == null) {
      throw new RuntimeException("Tried to create service but the necessary background components are not initialized.");
    }

    webSocket.setMessageListener(this::onWebSocketMessage);
  }

  private void onAdvance(final JSONObject object) throws JSONException {
    if (object == null) {
      player.stop();
      return;
    }

    final JSONObject entry = object.getJSONObject("media");
    final JSONObject media = entry.getJSONObject("media");
    final String sourceType = media.getString("sourceType");
    final String sourceID = media.getString("sourceID");
    final String artist = entry.getString("artist");
    final String title = entry.getString("title");
    final int seek = entry.getInt("start");
    // TODO use sharedpreferences
    final byte playbackType = PlaybackAction.PlaybackType.AUDIO_ONLY;

    player.stop();
    player.play(sourceType, sourceID, seek, playbackType, new Result() {
      public void success(Object value) {}
      public void error(String name, String message, Object data) {}
      public void notImplemented() {}
    });
  }

  private void onWebSocketMessage(String message) {
    try {
      final JSONObject object = new JSONObject(message);
      switch (object.getString("command")) {
        case "advance":
          onAdvance(object.getJSONObject("data"));
          break;
      }
    } catch (JSONException err) {
      // Ignore
    }
  }

  @Override
  public int onStartCommand(Intent intent, int flags, int startId) {
    notifications.foreground();
    startForeground(notifications.getForegroundNotificationId(), notifications.getNowPlayingNotification());
    return START_NOT_STICKY;
  }

  @Override
  public ListenBinder onBind(Intent intent) {
    return new ListenBinder(this);
  }

  @Override
  public void onDestroy() {
    notifications.unforeground();
  }

  public static class ListenBinder extends Binder {
    final ListenService service;

    ListenBinder(final ListenService service) {
      this.service = service;
    }

    ListenService getService() {
      return service;
    }
  }
}
