package net.u_wave.android;

import org.json.JSONObject;
import org.json.JSONException;
import android.os.Binder;
import android.content.Context;
import android.content.Intent;
import android.app.Service;
import android.util.Log;
import io.flutter.plugin.common.MethodChannel.Result;

public class ListenService extends Service implements WebSocketPlugin.MessageListener {
  private static final String TAG = "ListenService";
  private PlayerPlugin player;
  private NotificationPlugin notifications;
  private WebSocketPlugin webSocket;

  /* Service */
  @Override
  public void onCreate() {
    Log.d(TAG, "onCreate()");
    player = MainActivity.getPlayer();
    notifications = MainActivity.getNotifications();
    webSocket = MainActivity.getWebSocket();

    if (player == null || notifications == null || webSocket == null) {
      throw new RuntimeException("Tried to create service but the necessary background components are not initialized.");
    }

    webSocket.addMessageListener(this);
  }

  @Override
  public int onStartCommand(Intent intent, int flags, int startId) {
    Log.d(TAG, "onStartCommand()");
    return START_NOT_STICKY;
  }

  @Override
  public ListenBinder onBind(Intent intent) {
    Log.d(TAG, "onBind()");
    return new ListenBinder(this);
  }

  @Override
  public void onDestroy() {
    Log.d(TAG, "onDestroy()");
    notifications.unforeground();
    webSocket.removeMessageListener(this);
    player = null;
    notifications = null;
    webSocket = null;
  }

  /* WebSocketPlugin.Listener */
  @Override
  public void onSocketMessage(String message) {
    if (!message.contains("advance") && !message.contains("chatMessage")) {
      // Avoid parsing JSON if it's not an advance or mention message anyway
      return;
    }

    try {
      final JSONObject object = new JSONObject(message);
      switch (object.getString("command")) {
        case "advance":
          onAdvance(object.getJSONObject("data"));
          break;
        case "chatMessage":
          // TODO check for notification
          break;
      }
    } catch (JSONException err) {
      // Ignore
    }
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

    Log.d(TAG, String.format("Starting playback [%s:%s]", sourceType, sourceID));
    player.stop();
    player.play(sourceType, sourceID, seek, playbackType, new Result() {
      public void success(Object value) {}
      public void error(String name, String message, Object data) {}
      public void notImplemented() {}
    });
  }

  public void foreground() {
    notifications.foreground();
    startForeground(notifications.getForegroundNotificationId(), notifications.getNowPlayingNotification());
  }

  public void background() {
    notifications.unforeground();
    stopForeground(STOP_FOREGROUND_DETACH);
  }

  public static class ListenBinder extends Binder {
    private final ListenService service;

    ListenBinder(final ListenService service) {
      this.service = service;
    }

    public void foreground() {
      service.foreground();
    }

    public void background() {
      service.background();
    }

    public ListenService getService() {
      return service;
    }
  }
}
