package net.u_wave.android;

import android.app.Service;
import android.content.Context;
import android.content.ComponentName;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.IBinder;
import android.util.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

class ListenController implements ServiceConnection {
  private static final String TAG = "ListenController";
  public static final String NAME = "u-wave.net/background";
  private final Context context;
  private ListenService.ListenBinder serviceBinder;

  public ListenController(Context context) {
    this.context = context;
  }

  public void registerWith(Registrar registrar) {
    final Intent intent = new Intent(context, ListenService.class);
    final MethodChannel channel = new MethodChannel(registrar.messenger(), NAME);

    context.bindService(intent, this, Context.BIND_AUTO_CREATE);

    channel.setMethodCallHandler((call, result) -> {
      switch (call.method) {
        case "foreground":
          foreground();
          result.success(null);
          return;
        case "background":
          background();
          result.success(null);
          return;
        case "exit":
          context.unbindService(this);
          result.success(null);
          return;
        default:
          result.notImplemented();
      }
    });
  }

  private void foreground() {
    if (serviceBinder != null) {
      serviceBinder.foreground();
    } else {
      Log.wtf(TAG, "Tried to foreground service but the binder is gone");
    }
  }

  private void background() {
    if (serviceBinder != null) {
      serviceBinder.background();
    } else {
      Log.wtf(TAG, "Tried to background service but the binder is gone");
    }
  }

  /* ServiceConnection */
  @Override
  public void onServiceConnected(ComponentName component, IBinder binder) {
    if (binder instanceof ListenService.ListenBinder) {
      serviceBinder = (ListenService.ListenBinder) binder;
    } else {
      Log.wtf(TAG, "Service binder is not an instance of ListenBinder");
    }
  }

  @Override
  public void onServiceDisconnected(ComponentName component) {
    serviceBinder = null;
  }
}
