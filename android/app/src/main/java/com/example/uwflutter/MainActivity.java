package com.example.uwflutter;

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
import org.schabi.newpipe.extractor.stream.StreamInfo;
import org.schabi.newpipe.extractor.stream.AudioStream;
import org.schabi.newpipe.extractor.exceptions.ExtractionException;

public class MainActivity extends FlutterActivity {
  private static final String PLAYER_CHANNEL = "u-wave.net/player";
  private DefaultHttpDataSourceFactory dataSourceFactory;
  private SimpleExoPlayer player;
  private Surface surface;
  private SurfaceTextureEntry textureEntry;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);

    dataSourceFactory = new DefaultHttpDataSourceFactory(Util.getUserAgent(this, "u-wave"));

    MethodChannel playerChannel = new MethodChannel(getFlutterView(), PLAYER_CHANNEL);

    BandwidthMeter bandwidthMeter = new DefaultBandwidthMeter();
    player = ExoPlayerFactory.newSimpleInstance(
      new DefaultRenderersFactory(this),
      new DefaultTrackSelector(
        new AdaptiveTrackSelection.Factory(bandwidthMeter)),
      new DefaultLoadControl()
    );

    NewPipe.init(new DartDownloader(playerChannel));

    playerChannel.setMethodCallHandler(new MethodCallHandler() {
      @Override
      public void onMethodCall(MethodCall call, Result result) {
        if (call.method.equals("init")) {
          onInit(result);
        } else if (call.method.equals("play")) {
          onPlay((Map<String, String>) call.arguments, result);
        } else {
          result.notImplemented();
        }
      }
    });
  }

  void onInit(final Result result) {
    Registrar registrar = registrarFor("u-wave.net/player");
    TextureRegistry textures = registrar.textures();
    SurfaceTextureEntry textureEntry = textures.createSurfaceTexture();;
    surface = new Surface(textureEntry.surfaceTexture());
    player.setVideoSurface(surface);
    player.setPlayWhenReady(true);
    result.success(textureEntry.id());
  }

  void onPlay(Map<String, String> data, final Result result) {
    final String sourceType = data.get("sourceType");
    final String sourceID = data.get("sourceID");
    if (sourceType == null) {
      result.error("MissingParameter", "Missing parameter \"sourceType\"", null);
      return;
    }
    if (sourceID == null) {
      result.error("MissingParameter", "Missing parameter \"sourceID\"", null);
      return;
    }

    new Thread(new Runnable() {
      public void run() {
        try {
          String sourceName = getSourceNameFor(sourceType);
          String sourceURL = getSourceURLFor(sourceType, sourceID);

          StreamInfo info = StreamInfo.getInfo(NewPipe.getService(sourceName), sourceURL);
          AudioStream bestStream = getBestAudioStream(info);

          final Uri uri = Uri.parse(bestStream.getUrl());
          MediaSource mediaSource = getMediaSource(uri);
          player.prepare(mediaSource);

          result.success(uri.toString());
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
