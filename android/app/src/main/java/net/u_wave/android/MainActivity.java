package net.u_wave.android;

import java.util.Map;
import java.io.IOException;

import android.net.Uri;
import android.os.Bundle;
import android.view.Surface;

import io.flutter.app.FlutterActivity;
import io.flutter.view.TextureRegistry;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.TextureRegistry.SurfaceTextureEntry;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;

import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.Timeline;
import com.google.android.exoplayer2.PlaybackParameters;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.ExoPlaybackException;
import com.google.android.exoplayer2.source.TrackGroupArray;
import com.google.android.exoplayer2.trackselection.TrackSelectionArray;
import com.google.android.exoplayer2.util.Util;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.ExoPlayerFactory;
import com.google.android.exoplayer2.DefaultLoadControl;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.DefaultRenderersFactory;
import com.google.android.exoplayer2.upstream.BandwidthMeter;
import com.google.android.exoplayer2.source.ExtractorMediaSource;
import com.google.android.exoplayer2.source.dash.DashMediaSource;
import com.google.android.exoplayer2.upstream.DefaultBandwidthMeter;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSourceFactory;
import com.google.android.exoplayer2.source.dash.DefaultDashChunkSource;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import com.google.android.exoplayer2.trackselection.AdaptiveTrackSelection;

import org.schabi.newpipe.extractor.NewPipe;
import org.schabi.newpipe.extractor.stream.Stream;
import org.schabi.newpipe.extractor.stream.StreamInfo;
import org.schabi.newpipe.extractor.stream.AudioStream;
import org.schabi.newpipe.extractor.stream.VideoStream;
import org.schabi.newpipe.extractor.exceptions.ExtractionException;

public class MainActivity extends FlutterActivity {
  private static final String PLAYER_CHANNEL = "u-wave.net/player";
  private DefaultHttpDataSourceFactory dataSourceFactory;
  private Registrar playerPluginRegistrar;
  private SimpleExoPlayer player;
  private Surface surface;
  private SurfaceTextureEntry textureEntry;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);

    playerPluginRegistrar = registrarFor("u-wave.net/player");

    dataSourceFactory = new DefaultHttpDataSourceFactory(Util.getUserAgent(this, "u-wave"));

    MethodChannel playerChannel = new MethodChannel(getFlutterView(), PLAYER_CHANNEL);

    BandwidthMeter bandwidthMeter = new DefaultBandwidthMeter();
    player = ExoPlayerFactory.newSimpleInstance(
      new DefaultRenderersFactory(this),
      new DefaultTrackSelector(
        new AdaptiveTrackSelection.Factory(bandwidthMeter)),
      new DefaultLoadControl()
    );
    player.addListener(new Player.EventListener() {
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
        System.out.println("onPlayerStateChanged playWhenReady=" + (playWhenReady ? "true" : "false") + " readyState=" + readyState);
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
        err.printStackTrace();
      }

      @Override
      public void onTracksChanged(TrackGroupArray ignored, TrackSelectionArray trackSelections) {
      }

      @Override
      public void onSeekProcessed() {}

      @Override
      public void onRepeatModeChanged(int mode) {
        System.out.println("onRepeatModeChanged enabled=" + mode);
      }

      @Override
      public void onShuffleModeEnabledChanged(boolean enabled) {
        System.out.println("onShuffleModeEnabledChanged enabled=" + (enabled ? "true" : "false"));
      }
    });

    NewPipe.init(new DartDownloader(playerChannel));

    playerChannel.setMethodCallHandler(new MethodCallHandler() {
      @Override
      public void onMethodCall(MethodCall call, Result result) {
        if (call.method.equals("play")) {
          onPlay((Map<String, String>) call.arguments, result);
        } else {
          result.notImplemented();
        }
      }
    });
  }

  void onPlay(Map<String, String> data, final Result result) {
    if (textureEntry != null) {
      textureEntry.release();
    }
    if (data == null) {
      player.stop();
      player.setVideoSurface(null);
      result.success(null);
      return;
    }

    final String sourceType = data.get("sourceType");
    final String sourceID = data.get("sourceID");
    final boolean audioOnly = data.get("audioOnly") != null && data.get("audioOnly").equals("true");

    if (sourceType == null) {
      result.error("MissingParameter", "Missing parameter \"sourceType\"", null);
      return;
    }
    if (sourceID == null) {
      result.error("MissingParameter", "Missing parameter \"sourceID\"", null);
      return;
    }

    final TextureRegistry textures = playerPluginRegistrar.textures();
    textureEntry = textures.createSurfaceTexture();
    surface = new Surface(textureEntry.surfaceTexture());
    player.setVideoSurface(surface);

    new Thread(new Runnable() {
      public void run() {
        try {
          String sourceName = getSourceNameFor(sourceType);
          String sourceURL = getSourceURLFor(sourceType, sourceID);

          StreamInfo info = StreamInfo.getInfo(NewPipe.getService(sourceName), sourceURL);

          Stream bestStream = audioOnly
            ? getBestAudioStream(info)
            : getVideoStream(info);

          final Uri uri = Uri.parse(bestStream.getUrl());
          MediaSource mediaSource = getMediaSource(uri);
          player.prepare(mediaSource);
          result.success(textureEntry.id());
          player.setPlayWhenReady(true);
        } catch (IOException err) {
          result.error("IOException", err.getMessage(), null);
          err.printStackTrace();
        } catch (ExtractionException err) {
          result.error("ExtractionException", err.getMessage(), null);
          err.printStackTrace();
        }
      }
    }).start();
  }

  private AudioStream getBestAudioStream(StreamInfo info) {
    AudioStream bestStream = null;
    for (AudioStream stream : info.getAudioStreams()) {
      if (bestStream == null) {
        bestStream = stream;
      } else if (stream.getAverageBitrate() > bestStream.getAverageBitrate()) {
        bestStream = stream;
      }
    }
    return bestStream;
  }

  private VideoStream getVideoStream(StreamInfo info) {
    VideoStream bestStream = null;
    for (VideoStream stream : info.getVideoStreams()) {
      if (stream.isVideoOnly()) continue;

      if (bestStream == null) {
        bestStream = stream;
      }
    }

    System.out.println("bestStream: " + bestStream.getResolution() + " at " + bestStream.getUrl());

    return bestStream;
  }

  private MediaSource getMediaSource(Uri uri) {
    switch (Util.inferContentType(uri)) {
      case C.TYPE_DASH:
        return new DashMediaSource.Factory(
          new DefaultDashChunkSource.Factory(dataSourceFactory),
          dataSourceFactory
        ).createMediaSource(uri);
      case C.TYPE_OTHER:
        return new ExtractorMediaSource.Factory(dataSourceFactory)
          .createMediaSource(uri);
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
}
