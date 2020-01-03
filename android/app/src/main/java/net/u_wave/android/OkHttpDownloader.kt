package net.u_wave.android

import java.io.IOException
import java.util.List
import java.util.Map
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.localization.Localization
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import okhttp3.OkHttpClient

/**
 */
class OkHttpDownloader(val client: OkHttpClient): Downloader() {
  @Throws(IOException::class, ReCaptchaException::class)
  override public fun execute(descr: Request): Response {
    var body: okhttp3.RequestBody? = descr.dataToSend()?.let {
      val contentType = descr.headers().get("Content-Type")?.get(0)
      val mediaType = okhttp3.MediaType.parse(contentType)
      okhttp3.RequestBody.create(mediaType, descr.dataToSend())
    }
    var builder = okhttp3.Request.Builder()
      .method(descr.httpMethod(), null)
      .url(descr.url())

    descr.headers().putAll(Request.headersFromLocalization(descr.localization()))
    for (pair in descr.headers()) {
      for (value in pair.value) {
        builder.addHeader(pair.key, value)
      }
    }

    val request = builder.build()
    val response = this.client.newCall(request).execute()

    if (response.code() == 429) {
      throw ReCaptchaException("reCaptcha Challenge requested", descr.url())
    }

    return Response(response.code(), response.message(), response.headers().toMultimap(), response.body()?.string())
  }
}
