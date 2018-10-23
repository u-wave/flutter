package net.u_wave.android;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSourceFactory;
import com.google.android.exoplayer2.util.Util;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.util.Map;
import org.schabi.newpipe.extractor.NewPipe;
import org.schabi.newpipe.extractor.utils.Localization;

public class PlayerPlugin implements MethodCallHandler, SharedPreferences.OnSharedPreferenceChangeListener {
  private static final String CHANNEL_NAME = "u-wave.net/player";

  /** Plugin registration. */
  public static PlayerPlugin registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), CHANNEL_NAME);
    // Currently the app only supports English
    NewPipe.init(new DartDownloader(channel), new Localization("en", "GB"));
    final PlayerPlugin plugin = new PlayerPlugin(registrar);
    channel.setMethodCallHandler(plugin);
    return plugin;
  }

  private final DefaultHttpDataSourceFactory dataSourceFactory;
  private final Registrar registrar;
  private final SharedPreferences preferences;
  private PlaybackAction currentPlayback;

  private PlayerPlugin(Registrar registrar) {
    this.registrar = registrar;

    Context context = registrar.context();
    dataSourceFactory =
        new DefaultHttpDataSourceFactory(Util.getUserAgent(context, "android.u-wave.net"));
    preferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
    preferences.registerOnSharedPreferenceChangeListener(this);
  }

  private void runInNewThread(Runnable callback) {
    new Thread(callback).start();
  }

  private void onPlay(Map<String, String> data, final Result result) {
    stop();

    if (data == null) {
      result.success(null);
      return;
    }

    final String sourceType = data.get("sourceType");
    final String sourceData = data.get("sourceData");
    final int seek = Integer.parseInt(data.get("seek"));
    final byte playbackType = Integer.decode(data.get("playbackType")).byteValue();

    try {
      play(sourceType, sourceData, seek, playbackType, result);
    } catch (RuntimeException err) {
      result.error(err.getClass().getName(), err.getMessage(), null);
    }
  }

  private void onSetPlaybackType(Integer playbackType, Result result) {
    if (playbackType == null) {
      result.error("MissingParameter", "Missing parameter \"playbackType\"", null);
      return;
    }

    setPlaybackType(playbackType.byteValue());
    result.success(null);
  }

  public void setPlaybackType(byte playbackType) {
    if (currentPlayback != null) {
      currentPlayback.getEntry().setPlaybackType(playbackType);
      currentPlayback.start();
      Log.d(
          String.format("PlaybackAction[%s]", currentPlayback.getEntry().sourceUrl),
          String.format("getCurrentSeek(): %d", currentPlayback.getCurrentSeek()));
      result.success(null);
    }
  }

  /* MethodCallHandler */
  @Override
  @SuppressWarnings("unchecked")
  public void onMethodCall(MethodCall call, Result result) {
    switch (call.method) {
      case "play":
        onPlay((Map<String, String>) call.arguments, result);
        break;
      case "setPlaybackType":
        onSetPlaybackType((Integer) call.arguments, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /* API */
  public void stop() {
    if (currentPlayback != null) {
      currentPlayback.cancel();
      currentPlayback = null;
    }
  }

  public void play(String sourceType, String sourceID, int seek, byte playbackType, Result result) {
    if (sourceType == null) {
      throw new IllegalArgumentException("Missing parameter \"sourceType\"");
    }
    if (sourceID == null) {
      throw new IllegalArgumentException("Missing parameter \"sourceID\"");
    }

    final String sourceName = PlayerUtils.getNewPipeSourceName(sourceType);
    final String sourceUrl = PlayerUtils.getNewPipeSourceUrl(sourceType, sourceID);

    final PlaybackAction.Entry entry =
        new PlaybackAction.Entry(sourceName, sourceUrl, seek, playbackType);
    final PlaybackAction action = new PlaybackAction(registrar, result, dataSourceFactory, entry);

    currentPlayback = action;

    runInNewThread(
        () -> {
          action.start();
        });
  }
}
