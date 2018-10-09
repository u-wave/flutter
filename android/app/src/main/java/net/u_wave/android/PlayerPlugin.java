package net.u_wave.android;

import android.content.Context;
import android.net.Uri;
import android.view.Surface;
import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.DefaultLoadControl;
import com.google.android.exoplayer2.DefaultRenderersFactory;
import com.google.android.exoplayer2.ExoPlaybackException;
import com.google.android.exoplayer2.ExoPlayerFactory;
import com.google.android.exoplayer2.PlaybackParameters;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.Timeline;
import com.google.android.exoplayer2.source.ExtractorMediaSource;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.source.MergingMediaSource;
import com.google.android.exoplayer2.source.TrackGroupArray;
import com.google.android.exoplayer2.source.dash.DashMediaSource;
import com.google.android.exoplayer2.source.dash.DefaultDashChunkSource;
import com.google.android.exoplayer2.source.hls.HlsMediaSource;
import com.google.android.exoplayer2.source.smoothstreaming.DefaultSsChunkSource;
import com.google.android.exoplayer2.source.smoothstreaming.SsMediaSource;
import com.google.android.exoplayer2.trackselection.AdaptiveTrackSelection;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import com.google.android.exoplayer2.trackselection.TrackSelectionArray;
import com.google.android.exoplayer2.upstream.BandwidthMeter;
import com.google.android.exoplayer2.upstream.DefaultBandwidthMeter;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSourceFactory;
import com.google.android.exoplayer2.util.Util;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.TextureRegistry;
import io.flutter.view.TextureRegistry.SurfaceTextureEntry;
import java.io.IOException;
import java.util.Map;
import org.schabi.newpipe.extractor.NewPipe;
import org.schabi.newpipe.extractor.exceptions.ExtractionException;
import org.schabi.newpipe.extractor.stream.AudioStream;
import org.schabi.newpipe.extractor.stream.StreamInfo;
import org.schabi.newpipe.extractor.stream.VideoStream;

public class PlayerPlugin implements MethodCallHandler, Player.EventListener, SimpleExoPlayer.VideoListener {
  private static class PlaybackType {
    public static final byte DISABLED = 0;
    public static final byte AUDIO_ONLY = 1;
    public static final byte BOTH = 2;
  }

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
  private Surface surface;
  private SurfaceTextureEntry textureEntry;
  private Result currentResult;
  private String preferredResolution = "360p";
  private final MethodChannel channel;

  private PlayerPlugin(Registrar registrar, MethodChannel channel) {
    this.registrar = registrar;
    this.channel = channel;

    Context context = registrar.context();
    dataSourceFactory =
        new DefaultHttpDataSourceFactory(Util.getUserAgent(context, "android.u-wave.net"));

    BandwidthMeter bandwidthMeter = new DefaultBandwidthMeter();
    player =
        ExoPlayerFactory.newSimpleInstance(
            new DefaultRenderersFactory(context),
            new DefaultTrackSelector(new AdaptiveTrackSelection.Factory(bandwidthMeter)),
            new DefaultLoadControl());
    player.addListener(this);
    player.setVideoListener(this);
  }

  void onPlay(Map<String, String> data, final Result result) {
    if (currentResult != null) {
      currentResult.error("Cancel", "Cancelled: received new play call", null);
      currentResult = null;
    }

    if (textureEntry != null) {
      textureEntry.release();
      textureEntry = null;
    }

    if (data == null) {
      player.stop();
      player.clearVideoSurface();
      result.success(null);
      return;
    }

    final String sourceType = data.get("sourceType");
    final String sourceID = data.get("sourceID");
    final int seek = Integer.parseInt(data.get("seek"));
    final int playbackType = Integer.parseInt(data.get("playbackType"));

    if (sourceType == null) {
      result.error("MissingParameter", "Missing parameter \"sourceType\"", null);
      return;
    }
    if (sourceID == null) {
      result.error("MissingParameter", "Missing parameter \"sourceID\"", null);
      return;
    }

    final TextureRegistry textures = registrar.textures();

    if (playbackType == PlaybackType.BOTH) {
      textureEntry = textures.createSurfaceTexture();
      surface = new Surface(textureEntry.surfaceTexture());
      player.setVideoSurface(surface);
    } else {
      textureEntry = null;
      surface = null;
      player.setVideoSurface(null);
    }

    currentResult = result;

    Runnable loader =
        new Runnable() {
          public void run() {
            try {
              String sourceName = getSourceNameFor(sourceType);
              String sourceURL = getSourceURLFor(sourceType, sourceID);

              StreamInfo info = StreamInfo.getInfo(NewPipe.getService(sourceName), sourceURL);

              MediaSource mediaSource = getCombinedMediaSource(info, playbackType);
              player.prepare(mediaSource);
              player.seekTo(seek);
              player.setPlayWhenReady(true);
            } catch (IOException err) {
              currentResult.error("IOException", err.getMessage(), null);
              currentResult = null;
              err.printStackTrace();
            } catch (ExtractionException err) {
              currentResult.error("ExtractionException", err.getMessage(), null);
              currentResult = null;
              err.printStackTrace();
            }
          }
        };

    new Thread(loader).start();
  }

  private AudioStream getPreferredAudioStream(StreamInfo info) {
    AudioStream bestStream = null;
    for (AudioStream stream : info.getAudioStreams()) {
      System.out.println(
          "  audio: "
              + stream.getFormat().getName()
              + " "
              + stream.getFormat().getMimeType()
              + " - "
              + stream.getAverageBitrate()
              + "bps");

      if (bestStream == null) {
        bestStream = stream;
      } else if (stream.getAverageBitrate() > bestStream.getAverageBitrate()) {
        bestStream = stream;
      }
    }

    if (bestStream != null) {
      System.out.println(
          "best: " + bestStream.getFormat().getName() + " at " + bestStream.getUrl());
    } else {
      System.out.println("!! no audio streams");
    }

    return bestStream;
  }

  private VideoStream getPreferredVideoStream(StreamInfo info) {
    VideoStream bestStream = null;
    for (VideoStream stream : info.getVideoStreams()) {
      System.out.println(
          "  video: "
              + stream.getFormat().getName()
              + " "
              + stream.getFormat().getMimeType()
              + " - "
              + stream.getResolution());

      if (bestStream == null) {
        bestStream = stream;
      }
      if (stream.getResolution().equals(preferredResolution)) {
        bestStream = stream;
      }
    }

    if (bestStream != null) {
      System.out.println(
          "best: " + bestStream.getFormat().getName() + " at " + bestStream.getUrl());
    } else {
      System.out.println("!! no video streams");
    }

    return bestStream;
  }

  private MediaSource getCombinedMediaSource(StreamInfo info, int playbackType) {
    final VideoStream videoStream = getPreferredVideoStream(info);
    AudioStream audioStream = null;

    if (videoStream == null || videoStream.isVideoOnly() || playbackType == PlaybackType.AUDIO_ONLY) {
      audioStream = getPreferredAudioStream(info);
    }

    if (videoStream == null && audioStream == null) {
      return null;
    }

    final MediaSource videoSource =
        videoStream != null ? getMediaSource(Uri.parse(videoStream.getUrl())) : null;
    final MediaSource audioSource =
        audioStream != null ? getMediaSource(Uri.parse(audioStream.getUrl())) : null;

    MediaSource mediaSource = videoSource != null ? videoSource : audioSource;
    if (playbackType == PlaybackType.AUDIO_ONLY) {
      mediaSource = audioSource != null ? audioSource : videoSource;
    } else if (videoSource != null && audioSource != null) {
      mediaSource = new MergingMediaSource(new MediaSource[] {videoSource, audioSource});
    }

    return mediaSource;
  }

  private MediaSource getMediaSource(Uri uri) {
    switch (Util.inferContentType(uri)) {
      case C.TYPE_SS:
        return new SsMediaSource.Factory(
                new DefaultSsChunkSource.Factory(dataSourceFactory), dataSourceFactory)
            .createMediaSource(uri);
      case C.TYPE_DASH:
        return new DashMediaSource.Factory(
                new DefaultDashChunkSource.Factory(dataSourceFactory), dataSourceFactory)
            .createMediaSource(uri);
      case C.TYPE_HLS:
        return new HlsMediaSource.Factory(dataSourceFactory).createMediaSource(uri);
      case C.TYPE_OTHER:
        return new ExtractorMediaSource.Factory(dataSourceFactory).createMediaSource(uri);
    }
    return null;
  }

  private static String getSourceNameFor(String sourceType) {
    if (sourceType.equals("youtube")) return "YouTube";
    if (sourceType.equals("soundcloud")) return "SoundCloud";
    return null;
  }

  private static String getSourceURLFor(String sourceType, String sourceID) {
    if (sourceType.equals("youtube")) {
      return "https://youtube.com/watch?v=" + sourceID;
    }
    if (sourceType.equals("soundcloud")) {
      return "https://api.soundcloud.com/tracks/" + sourceID;
    }
    return null;
  }

  /* MethodCallHandler */
  @Override
  @SuppressWarnings("unchecked")
  public void onMethodCall(MethodCall call, Result result) {
    if (call.method.equals("play")) {
      onPlay((Map<String, String>) call.arguments, result);
    } else {
      result.notImplemented();
    }
  }

  /* Player.EventListener */
  @Override
  public void onLoadingChanged(boolean isLoading) {
    if (isLoading) {
      System.out.println("onLoadingChanged: loading");
    } else {
      System.out.println("onLoadingChanged: not loading");
    }
  }

  @Override
  public void onPlayerStateChanged(boolean playWhenReady, int readyState) {
    System.out.println(
        "onPlayerStateChanged playWhenReady="
            + (playWhenReady ? "true" : "false")
            + " readyState="
            + readyState);

    if (readyState == Player.STATE_READY) {
      currentResult.success(textureEntry != null ? textureEntry.id() : null);
      currentResult = null;
    }
  }

  @Override
  public void onPositionDiscontinuity(int reason) {
    System.out.println("onPositionDiscontinuity reason=" + reason);
  }

  @Override
  public void onPlaybackParametersChanged(PlaybackParameters playbackParameters) {
    System.out.println("onPlaybackParametersChanged");
  }

  @Override
  public void onTimelineChanged(Timeline timeline, Object manifest, int reason) {
    System.out.println("onTimelineChanged reason=" + reason);
  }

  @Override
  public void onPlayerError(ExoPlaybackException err) {
    currentResult.error("ExoPlaybackException", err.getMessage(), null);
    currentResult = null;
    err.printStackTrace();
  }

  @Override
  public void onTracksChanged(TrackGroupArray ignored, TrackSelectionArray trackSelections) {}

  @Override
  public void onSeekProcessed() {
    System.out.println("onSeekProcessed");
  }

  @Override
  public void onRepeatModeChanged(int mode) {
    System.out.println("onRepeatModeChanged enabled=" + mode);
  }

  @Override
  public void onShuffleModeEnabledChanged(boolean enabled) {
    System.out.println("onShuffleModeEnabledChanged enabled=" + (enabled ? "true" : "false"));
  }

  /* Player.VideoListener */
  @Override
  public void onRenderedFirstFrame() {}

  @Override
  public void onVideoSizeChanged(int width, int height, int rotation, float pixelRatio) {
    channel.invokeMethod("setAspectRatio", (double) width / (double) height);
  }
}
