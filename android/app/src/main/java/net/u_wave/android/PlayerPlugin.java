package net.u_wave.android;

import android.content.Context;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSourceFactory;
import com.google.android.exoplayer2.util.Util;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.util.Map;
import org.schabi.newpipe.extractor.NewPipe;

public class PlayerPlugin implements MethodCallHandler {
  public static final String NAME = "u-wave.net/player";

  /** Plugin registration. */
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), NAME);
    NewPipe.init(new DartDownloader(channel));
    channel.setMethodCallHandler(new PlayerPlugin(registrar, channel));
  }

  private final DefaultHttpDataSourceFactory dataSourceFactory;
  private final Registrar registrar;
  private PlaybackAction currentPlayback;
  private final MethodChannel channel;

  private PlayerPlugin(Registrar registrar, MethodChannel channel) {
    this.registrar = registrar;
    this.channel = channel;

    Context context = registrar.context();
    dataSourceFactory =
        new DefaultHttpDataSourceFactory(Util.getUserAgent(context, "android.u-wave.net"));
  }

  void onPlay(Map<String, String> data, final Result result) {
    if (currentPlayback != null) {
      currentPlayback.cancel();
      currentPlayback = null;
    }

    if (data == null) {
      result.success(null);
      return;
    }

    final String sourceName = data.get("sourceName");
    final String sourceUrl = data.get("sourceUrl");
    final int seek = Integer.parseInt(data.get("seek"));
    final byte playbackType = Integer.decode(data.get("playbackType")).byteValue();

    if (sourceName == null) {
      result.error("MissingParameter", "Missing parameter \"sourceName\"", null);
      return;
    }
    if (sourceUrl == null) {
      result.error("MissingParameter", "Missing parameter \"sourceUrl\"", null);
      return;
    }

    final PlaybackAction.Entry entry =
        new PlaybackAction.Entry(sourceName, sourceUrl, seek, playbackType);
    final PlaybackAction action = new PlaybackAction(registrar, result, dataSourceFactory, entry);

    currentPlayback = action;

    new Thread(
            () -> {
              action.start();
            })
        .start();
  }

  private void onSetPlaybackType(Integer playbackType, Result result) {
    if (playbackType == null) {
      result.error("MissingParameter", "Missing parameter \"playbackType\"", null);
      return;
    }

    final byte playbackTypeId = playbackType.byteValue();

    if (currentPlayback != null) {
      currentPlayback.getEntry().setPlaybackType(playbackTypeId);
      currentPlayback.start();
      System.out.println(
          "PlaybackAction["
              + currentPlayback.getEntry().sourceUrl
              + "] getCurrentSeek(): "
              + currentPlayback.getCurrentSeek());
      result.success(null);
    } else {
      result.error("NoPlayback", "Can't change playback type because nothing is playing.", null);
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
}
