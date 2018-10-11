package net.u_wave.android;

import android.net.Uri;
import android.view.Surface;
import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.ExoPlaybackException;
import com.google.android.exoplayer2.PlaybackParameters;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.Timeline;
import com.google.android.exoplayer2.source.ExtractorMediaSource;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.source.MergingMediaSource;
import com.google.android.exoplayer2.source.TrackGroupArray;
import com.google.android.exoplayer2.source.dash.DashMediaSource;
import com.google.android.exoplayer2.source.dash.DefaultDashChunkSource;
import com.google.android.exoplayer2.source.hls.HlsMediaSource;
import com.google.android.exoplayer2.source.smoothstreaming.DefaultSsChunkSource;
import com.google.android.exoplayer2.source.smoothstreaming.SsMediaSource;
import com.google.android.exoplayer2.trackselection.TrackSelectionArray;
import com.google.android.exoplayer2.util.Util;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.TextureRegistry.SurfaceTextureEntry;
import java.io.IOException;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import org.schabi.newpipe.extractor.NewPipe;
import org.schabi.newpipe.extractor.exceptions.ExtractionException;
import org.schabi.newpipe.extractor.stream.AudioStream;
import org.schabi.newpipe.extractor.stream.StreamInfo;
import org.schabi.newpipe.extractor.stream.VideoStream;

class PlaybackAction implements Player.EventListener, SimpleExoPlayer.VideoListener {
  private boolean ended = false;
  private Result flutterResult;
  private final Entry entry;
  private final Listener listener;
  private final Surface surface;
  private final SurfaceTextureEntry textureEntry;
  private final DataSource.Factory dataSourceFactory;
  private int videoWidth;
  private int videoHeight;
  private final String id;
  private final Date startTime = new Date();

  private StreamInfo streamInfo;

  PlaybackAction(
      final Registrar registrar, final Result result, final DataSource.Factory dataSourceFactory, final Entry entry, final Listener listener) {
    flutterResult = result;
    this.dataSourceFactory = dataSourceFactory;
    this.entry = entry;
    this.listener = listener;
    id = entry.sourceType + ":" + entry.sourceID;

    if (entry.shouldPlayVideo()) {
      textureEntry = registrar.textures().createSurfaceTexture();
      surface = new Surface(textureEntry.surfaceTexture());
    } else {
      textureEntry = null;
      surface = null;
    }
  }

  public Entry getEntry() {
    return entry;
  }

  public Surface getSurface() {
    return surface;
  }

  public void cancel() {
    System.out.println("PlaybackAction[" + id + "] cancel()");
    if (streamInfo == null) {
      fail("Cancel", "Playback was cancelled", null);
    }
    end();
  }

  public void end() {
    System.out.println("PlaybackAction[" + id + "] end()");
    ended = true;
    if (entry.shouldPlayVideo()) {
      if (textureEntry != null) {
        textureEntry.release();
      } else {
        try {
          throw new RuntimeException("end() was called on a video entry, but textureEntry is null");
        } catch (Exception e) {
          e.printStackTrace();
        }
      }
    }
    listener.onEnd(this);
  }

  private void fail(String name, String message, Object err) {
    if (ended) return;
    if (flutterResult != null) {
      System.out.println("PlaybackAction[" + id + "] fail(" + name + ", " + message + ")");
      flutterResult.error(name, message, err);
      flutterResult = null;
    } else {
      try {
        throw new RuntimeException("fail() was called, but flutterResult has gone away");
      } catch (Exception e) {
        e.printStackTrace();
      }
    }
  }

  private StreamInfo getStreamInfo() {
    System.out.println("PlaybackAction[" + id + "] getStreamInfo()");
    try {
      return StreamInfo.getInfo(
          NewPipe.getService(entry.getNewPipeSourceName()), entry.getNewPipeSourceURL());
    } catch (IOException err) {
      fail("IOException", err.getMessage(), null);
      err.printStackTrace();
    } catch (ExtractionException err) {
      fail("ExtractionException", err.getMessage(), null);
      err.printStackTrace();
    }
    return null;
  }

  public MediaSource getMediaSource() {
    if (streamInfo == null) {
      streamInfo = getStreamInfo();
    }

    if (streamInfo == null) {
      return null;
    }
    return getCombinedMediaSource();
  }

  public int getCurrentSeek() {
    final long mediaStartTime = (startTime.getTime() / 1000) - entry.seek;
    final long now = new Date().getTime() / 1000;

    return (int) (now - mediaStartTime);
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
      if (stream.getResolution().equals(entry.preferredResolution)) {
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

  private MediaSource getCombinedMediaSource() {
    final VideoStream videoStream = getPreferredVideoStream(streamInfo);
    AudioStream audioStream = null;

    if (videoStream == null
        || videoStream.isVideoOnly()
        || entry.playbackType == PlaybackType.AUDIO_ONLY) {
      audioStream = getPreferredAudioStream(streamInfo);
    }

    if (videoStream == null && audioStream == null) {
      return null;
    }

    final MediaSource videoSource =
        videoStream != null ? getMediaSource(Uri.parse(videoStream.getUrl())) : null;
    final MediaSource audioSource =
        audioStream != null ? getMediaSource(Uri.parse(audioStream.getUrl())) : null;

    MediaSource mediaSource = videoSource != null ? videoSource : audioSource;
    if (entry.playbackType == PlaybackType.AUDIO_ONLY) {
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

  /* Player.EventListener */
  @Override
  public void onLoadingChanged(boolean isLoading) {
    if (isLoading) {
      System.out.println("PlaybackAction[" + id + "] onLoadingChanged: loading");
    } else {
      System.out.println("PlaybackAction[" + id + "] onLoadingChanged: not loading");
    }
  }

  @Override
  public void onPlayerStateChanged(boolean playWhenReady, int readyState) {
    System.out.println(
        "PlaybackAction[" + id + "] onPlayerStateChanged playWhenReady="
            + (playWhenReady ? "true" : "false")
            + " readyState="
            + readyState);

    if (readyState == Player.STATE_READY) {
      Map<String, Object> playbackSettings = new HashMap<String, Object>();
      playbackSettings.put("texture", textureEntry != null ? textureEntry.id() : null);
      playbackSettings.put("aspectRatio", (double) videoWidth / (double) videoHeight);

      if (!ended) {
        if (flutterResult != null) {
          System.out.println("PlaybackAction[" + id + "] success()");
          flutterResult.success(playbackSettings);
          flutterResult = null;
        } else {
          try {
            throw new RuntimeException("onPlayerStateChanged was called, but flutterResult has gone away");
          } catch (Exception e) {
            e.printStackTrace();
          }
        }
      }
    }
  }

  @Override
  public void onPositionDiscontinuity(int reason) {
    System.out.println("PlaybackAction[" + id + "] onPositionDiscontinuity reason=" + reason);
  }

  @Override
  public void onPlaybackParametersChanged(PlaybackParameters playbackParameters) {
    System.out.println("PlaybackAction[" + id + "] onPlaybackParametersChanged");
  }

  @Override
  public void onTimelineChanged(Timeline timeline, Object manifest, int reason) {
    System.out.println("PlaybackAction[" + id + "] onTimelineChanged reason=" + reason);
  }

  @Override
  public void onPlayerError(ExoPlaybackException err) {
    fail("ExoPlaybackException", err.getMessage(), null);
    err.printStackTrace();
  }

  @Override
  public void onTracksChanged(TrackGroupArray ignored, TrackSelectionArray trackSelections) {}

  @Override
  public void onSeekProcessed() {
    System.out.println("PlaybackAction[" + id + "] onSeekProcessed");
  }

  @Override
  public void onRepeatModeChanged(int mode) {
    System.out.println("PlaybackAction[" + id + "] onRepeatModeChanged enabled=" + mode);
  }

  @Override
  public void onShuffleModeEnabledChanged(boolean enabled) {
    System.out.println("PlaybackAction[" + id + "] onShuffleModeEnabledChanged enabled=" + (enabled ? "true" : "false"));
  }

  /* Player.VideoListener */
  @Override
  public void onRenderedFirstFrame() {}

  @Override
  public void onVideoSizeChanged(int width, int height, int rotation, float pixelRatio) {
    videoWidth = width;
    videoHeight = height;
  }

  public static class Entry {
    public final String sourceType;
    public final String sourceID;
    public final int seek;
    public byte playbackType;
    public final String preferredResolution = "360p";

    Entry(String sourceType, String sourceID, int seek, byte playbackType) {
      this.sourceType = sourceType;
      this.sourceID = sourceID;
      this.seek = seek;
      this.playbackType = playbackType;
    }

    public boolean shouldPlayVideo() {
      return playbackType == PlaybackType.BOTH;
    }

    public void setPlaybackType(byte newPlaybackType) {
      playbackType = newPlaybackType;
    }

    public String getNewPipeSourceName() {
      if (sourceType.equals("youtube")) return "YouTube";
      if (sourceType.equals("soundcloud")) return "SoundCloud";
      return null;
    }

    public String getNewPipeSourceURL() {
      if (sourceType.equals("youtube")) {
        return "https://youtube.com/watch?v=" + sourceID;
      }
      if (sourceType.equals("soundcloud")) {
        return "https://api.soundcloud.com/tracks/" + sourceID;
      }
      return null;
    }
  }

  public static class PlaybackType {
    public static final byte DISABLED = 0;
    public static final byte AUDIO_ONLY = 1;
    public static final byte BOTH = 2;
  }

  public static interface Listener {
    public void onEnd(PlaybackAction self);
  }
}
