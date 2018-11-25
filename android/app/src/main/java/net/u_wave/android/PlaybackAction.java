package net.u_wave.android;

import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.util.Log;
import android.view.Surface;
import com.google.android.exoplayer2.C;
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
import com.google.android.exoplayer2.trackselection.TrackSelectionArray;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.util.Util;
import com.google.android.exoplayer2.video.VideoListener;
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

class PlaybackAction implements Player.EventListener, VideoListener {
  private boolean ended = false;
  private Result flutterResult;
  private final Entry entry;
  private final Surface surface;
  private final SurfaceTextureEntry textureEntry;
  private final DataSource.Factory dataSourceFactory;
  private final Context context;
  private SimpleExoPlayer player;
  private int videoWidth;
  private int videoHeight;
  private final String id;
  private final String logTag;
  private final Date startTime = new Date();
  private final Handler mainThread;

  private StreamInfo streamInfo;

  PlaybackAction(
      final Registrar registrar,
      final Result result,
      final DataSource.Factory dataSourceFactory,
      final Entry entry) {
    flutterResult = result;
    this.dataSourceFactory = dataSourceFactory;
    this.entry = entry;
    context = registrar.context();
    id = entry.sourceUrl;
    logTag = String.format("PlaybackAction[%s]", id);

    mainThread = new Handler(context.getMainLooper());

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

  private void create() {
    player = ExoPlayerFactory.newSimpleInstance(context);
    player.addVideoListener(this);
    player.addListener(this);
  }

  public void start() {
    final MediaSource mediaSource = getMediaSource();
    mainThread.post(
        () -> {
          create();

          player.prepare(mediaSource);
          player.seekTo(getCurrentSeek());
          player.setPlayWhenReady(true);
          player.setVideoSurface(surface);
        });
  }

  public void cancel() {
    Log.d(logTag, "cancel()");
    if (streamInfo == null) {
      fail("Cancel", "Playback was cancelled", null);
    }
    end();
  }

  public void end() {
    Log.d(logTag, "end()");
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

    if (player == null) {
      return;
    }

    mainThread.post(
        () -> {
          player.stop();
          player.clearVideoSurface();
          player.removeListener(this);
          player.removeVideoListener(this);
          player.release();
        });
  }

  private void fail(String name, String message, Object err) {
    if (ended) return;
    if (flutterResult != null) {
      Log.d(logTag, String.format("fail(%s, %s)", name, message));
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
    Log.d(logTag, "getStreamInfo()");
    try {
      return StreamInfo.getInfo(NewPipe.getService(entry.sourceName), entry.sourceUrl);
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
    final long mediaStartTime = startTime.getTime() - entry.seek;
    final long now = new Date().getTime();

    return (int) (now - mediaStartTime);
  }

  private AudioStream getPreferredAudioStream(StreamInfo info) {
    AudioStream bestStream = null;
    for (AudioStream stream : info.getAudioStreams()) {
      Log.d(
          logTag,
          String.format(
              "  audio: %s %s - %d",
              stream.getFormat().getName(),
              stream.getFormat().getMimeType(),
              stream.getAverageBitrate()));

      if (bestStream == null) {
        bestStream = stream;
      } else if (stream.getAverageBitrate() > bestStream.getAverageBitrate()) {
        bestStream = stream;
      }
    }

    if (bestStream != null) {
      Log.d(
          logTag,
          String.format("best: %s at %s", bestStream.getFormat().getName(), bestStream.getUrl()));
    } else {
      Log.d(logTag, "!! no audio streams");
    }

    return bestStream;
  }

  private VideoStream getPreferredVideoStream(StreamInfo info) {
    VideoStream bestStream = null;
    for (VideoStream stream : info.getVideoStreams()) {
      Log.d(
          logTag,
          String.format(
              "  video: %s %s - %s",
              stream.getFormat().getName(),
              stream.getFormat().getMimeType(),
              stream.getResolution()));

      if (bestStream == null) {
        bestStream = stream;
      }
      if (stream.getResolution().equals(entry.preferredResolution)) {
        bestStream = stream;
      }
    }

    if (bestStream != null) {
      Log.d(
          logTag,
          String.format("best: %s at %s", bestStream.getFormat().getName(), bestStream.getUrl()));
    } else {
      Log.d(logTag, "!! no video streams");
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
      Log.d(logTag, "onLoadingChanged: loading");
    } else {
      Log.d(logTag, "onLoadingChanged: not loading");
    }
  }

  @Override
  public void onPlayerStateChanged(boolean playWhenReady, int readyState) {
    Log.d(
        logTag,
        String.format(
            "onPlayerStateChanged playWhenReady=%b readyState=%d", playWhenReady, readyState));

    if (readyState == Player.STATE_READY) {
      PlaybackSettings playbackSettings;
      if (entry.playbackType == PlaybackType.BOTH) {
        playbackSettings =
            new PlaybackSettings(
                textureEntry != null ? textureEntry.id() : null,
                (double) videoWidth / (double) videoHeight);
      } else {
        playbackSettings = new PlaybackSettings();
      }

      if (!ended) {
        if (flutterResult != null) {
          Log.d(logTag, "success()");
          flutterResult.success(playbackSettings.toMap());
          flutterResult = null;
        } else {
          try {
            throw new RuntimeException(
                "onPlayerStateChanged was called, but flutterResult has gone away");
          } catch (Exception e) {
            e.printStackTrace();
          }
        }
      }
    }
  }

  @Override
  public void onPositionDiscontinuity(int reason) {
    Log.d(logTag, String.format("onPositionDiscontinuity reason=%d", reason));
  }

  @Override
  public void onPlaybackParametersChanged(PlaybackParameters playbackParameters) {
    Log.d(logTag, "onPlaybackParametersChanged");
  }

  @Override
  public void onTimelineChanged(Timeline timeline, Object manifest, int reason) {
    Log.d(logTag, String.format("onTimelineChanged reason=%d", reason));
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
    Log.d(logTag, "onSeekProcessed");
  }

  @Override
  public void onRepeatModeChanged(int mode) {
    Log.d(logTag, String.format("onRepeatModeChanged enabled=%d", mode));
  }

  @Override
  public void onShuffleModeEnabledChanged(boolean enabled) {
    Log.d(logTag, String.format("onShuffleModeEnabledChanged enabled=%b", enabled));
  }

  /* VideoListener */
  @Override
  public void onRenderedFirstFrame() {}

  @Override
  public void onVideoSizeChanged(int width, int height, int rotation, float pixelRatio) {
    videoWidth = width;
    videoHeight = height;
  }

  public static class Entry {
    public final String sourceName;
    public final String sourceUrl;
    public final int seek;
    public byte playbackType;
    public final String preferredResolution = "360p";

    Entry(String sourceName, String sourceUrl, int seek, byte playbackType) {
      this.sourceName = sourceName;
      this.sourceUrl = sourceUrl;
      this.seek = seek;
      this.playbackType = playbackType;
    }

    public boolean shouldPlayVideo() {
      return playbackType == PlaybackType.BOTH;
    }

    public void setPlaybackType(byte newPlaybackType) {
      playbackType = newPlaybackType;
    }
  }

  public static class PlaybackType {
    public static final byte DISABLED = 0;
    public static final byte AUDIO_ONLY = 1;
    public static final byte BOTH = 2;
  }

  public static class PlaybackSettings {
    private final Long texture;
    private final Double aspectRatio;

    PlaybackSettings() {
      texture = null;
      aspectRatio = null;
    }

    PlaybackSettings(Long texture, Double aspectRatio) {
      this.texture = texture;
      this.aspectRatio = aspectRatio;
    }

    public Map<String, Object> toMap() {
      final Map<String, Object> map = new HashMap<>();
      if (texture != null && aspectRatio != null) {
        map.put("texture", texture.longValue());
        map.put("aspectRatio", aspectRatio.doubleValue());
      }
      return map;
    }
  }
}
