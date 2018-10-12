package net.u_wave.android;

import com.bugsnag.android.Bugsnag;
import io.flutter.app.FlutterApplication;

public class Application extends FlutterApplication {
  @Override
  public void onCreate() {
    super.onCreate();
    Bugsnag.init(this);
  }
}
