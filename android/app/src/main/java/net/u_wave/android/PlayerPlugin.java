package net.u_wave.android;

import android.content.Context;
import android.os.Handler;
import com.google.android.exoplayer2.ExoPlayerFactory;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSourceFactory;
import com.google.android.exoplayer2.util.Util;
import com.google.android.exoplayer2.video.VideoListener;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.util.Map;
import org.schabi.newpipe.extractor.NewPipe;

public class PlayerPlugin implements MethodCallHandler, VideoListener {
  public static final String NAME = "u-wave.net/player";

  /** Plugin registration. */
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), NAME);
    NewPipe.init(new DartDownloader(channel));
    channel.setMethodCallHandler(new PlayerPlugin(registrar, channel));
  }

  private final DefaultHttpDataSourceFactory dataSourceFactory;
  private final Registrar registrar;
  private final SimpleExoPlayer player;
  private PlaybackAction currentPlayback;
  private final MethodChannel channel;

  private PlayerPlugin(Registrar registrar, MethodChannel channel) {
    this.registrar = registrar;
    this.channel = channel;

    Context context = registrar.context();
    dataSourceFactory =
        new DefaultHttpDataSourceFactory(Util.getUserAgent(context, "android.u-wave.net"));

    player = ExoPlayerFactory.newSimpleInstance(context);

    player.addVideoListener(this);
  }

  private void runOnMainThread(Runnable runner) {
    Handler mainThread = new Handler(registrar.context().getMainLooper());
    mainThread.post(runner);
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

    final String sourceType = data.get("sourceType");
    final String sourceID = data.get("sourceID");
    final int seek = Integer.parseInt(data.get("seek"));
    final byte playbackType = Integer.decode(data.get("playbackType")).byteValue();

    if (sourceType == null) {
      result.error("MissingParameter", "Missing parameter \"sourceType\"", null);
      return;
    }
    if (sourceID == null) {
      result.error("MissingParameter", "Missing parameter \"sourceID\"", null);
      return;
    }

    final PlaybackAction.Entry entry =
        new PlaybackAction.Entry(sourceType, sourceID, seek, playbackType);
    final PlaybackAction action =
        new PlaybackAction(
            registrar,
            result,
            dataSourceFactory,
            entry,
            new PlaybackAction.Listener() {
              @Override
              public void onEnd(PlaybackAction self) {
                runOnMainThread(
                    () -> {
                      player.removeListener(self);
                      player.stop();
                      player.clearVideoSurface();
                    });
              }
            });

    runOnMainThread(
        () -> {
          player.addListener(action);
          player.setVideoSurface(action.getSurface());
        });
    currentPlayback = action;

    new Thread(
            () -> {
              final MediaSource mediaSource = action.getMediaSource();
              runOnMainThread(
                  () -> {
                    player.prepare(mediaSource);
                    player.seekTo(seek);
                    player.setPlayWhenReady(true);
                  });
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
      final MediaSource mediaSource = currentPlayback.getMediaSource();
      player.prepare(mediaSource);
      player.seekTo(currentPlayback.getCurrentSeek());
      System.out.println(
          "PlaybackAction["
              + currentPlayback.getEntry().sourceType
              + ":"
              + currentPlayback.getEntry().sourceID
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

  /* VideoListener */
  @Override
  public void onRenderedFirstFrame() {
    if (currentPlayback != null) {
      currentPlayback.onRenderedFirstFrame();
    }
  }

  @Override
  public void onVideoSizeChanged(int width, int height, int rotation, float pixelRatio) {
    if (currentPlayback != null) {
      currentPlayback.onVideoSizeChanged(width, height, rotation, pixelRatio);
    }
  }
}
