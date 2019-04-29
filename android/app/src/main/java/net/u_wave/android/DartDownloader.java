package net.u_wave.android;

import android.util.Log;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import org.schabi.newpipe.extractor.Downloader;
import org.schabi.newpipe.extractor.DownloadRequest;
import org.schabi.newpipe.extractor.DownloadResponse;
import org.schabi.newpipe.extractor.utils.Localization;

/**
 * Call into Dart to do the download, because it already has an HTTP library.
 *
 * <p>This way I don't have to pick one in Java!
 */
class DartDownloader implements Downloader {
  private static final String TAG = "DartDownloader";
  private MethodChannel channel;

  DartDownloader(MethodChannel methodChannel) {
    channel = methodChannel;
  }

  @Override
  public String download(String siteUrl) {
    return download(siteUrl, new Localization("en", "GB"));
  }

  @Override
  public String download(String siteUrl, Localization locale) {
    Map<String, String> headers = new HashMap<>();
    if (locale != null) {
      headers.put("Accept-Language", locale.getLanguage());
    }
    return download(siteUrl, headers);
  }

  @Override
  public String download(String siteUrl, Map<String, String> headers) {
    Log.d(TAG, String.format("Downloading %s", siteUrl));
    Object lock = new Object();
    DownloadResult result = new DownloadResult(lock);
    if (headers == null) {
      headers = new HashMap<>();
    }
    headers.put("_url", siteUrl);
    channel.invokeMethod("download", headers, result);
    headers.remove("_url");

    synchronized (lock) {
      while (!result.isDone()) {
        try {
          lock.wait();
        } catch (InterruptedException e) {
          return null;
        }
      }
    }

    return result.getResponse();
  }

  @Override
  public DownloadResponse get(String url, DownloadRequest r) throws IOException {
    throw new IOException("unimplemented");
  }

  @Override
  public DownloadResponse get(String url) throws IOException {
    throw new IOException("unimplemented");
  }

  @Override
  public DownloadResponse post(String url, DownloadRequest r) throws IOException {
    throw new IOException("unimplemented");
  }

  class DownloadResult implements Result {
    private Object lock;
    private String response;
    private boolean done;

    DownloadResult(Object lock) {
      this.lock = lock;
    }

    public String getResponse() {
      return response;
    }

    public boolean isDone() {
      return done;
    }

    @Override
    public void success(Object result) {
      synchronized (lock) {
        done = true;
        response = (String) result;
        lock.notify();
      }
    }

    @Override
    public void notImplemented() {
      synchronized (lock) {
        done = true;
        try {
          throw new RuntimeException("not implemented");
        } finally {
          lock.notify();
        }
      }
    }

    @Override
    public void error(String errorCode, String errorMessage, Object details) {
      synchronized (lock) {
        done = true;
        try {
          throw new RuntimeException(errorMessage);
        } finally {
          lock.notify();
        }
      }
    }
  }
}
