package net.u_wave.android;

import android.util.Log;
import java.io.IOException;
import java.util.List;
import java.util.Map;
import org.schabi.newpipe.extractor.downloader.Request;
import org.schabi.newpipe.extractor.downloader.Response;
import org.schabi.newpipe.extractor.downloader.Downloader;
import org.schabi.newpipe.extractor.localization.Localization;
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException;
import okhttp3.OkHttpClient;

/**
 */
class OkHttpDownloader extends Downloader {
  private OkHttpClient client;

  OkHttpDownloader(OkHttpClient client) {
    this.client = client;
  }

  @Override
  public Response execute(Request descr) throws IOException, ReCaptchaException {
    okhttp3.RequestBody body = null;
    if (descr.dataToSend() != null) {
      final String contentType = descr.headers().get("Content-Type").get(0);
      final okhttp3.MediaType mediaType = okhttp3.MediaType.parse(contentType);
      body = okhttp3.RequestBody.create(mediaType, descr.dataToSend());
    }
    okhttp3.Request.Builder builder = new okhttp3.Request.Builder()
      .method(descr.httpMethod(), null)
      .url(descr.url());

    descr.headers().putAll(Request.headersFromLocalization(descr.localization()));
    for (Map.Entry<String, List<String>> pair : descr.headers().entrySet()) {
      final String key = pair.getKey();
      for (String value : pair.getValue()) {
        builder.addHeader(key, value);
      }
    }

    final okhttp3.Request request = builder.build();
    final okhttp3.Response response = this.client.newCall(request).execute();

    if (response.code() == 429) {
      throw new ReCaptchaException("reCaptcha Challenge requested", descr.url());
    }

    return new Response(response.code(), response.message(), response.headers().toMultimap(), response.body().string());
  }
}
