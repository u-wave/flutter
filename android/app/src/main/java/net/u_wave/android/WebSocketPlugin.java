package net.u_wave.android;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.LinkedList;
import org.java_websocket.client.WebSocketClient;
import org.java_websocket.drafts.Draft_6455;
import org.java_websocket.framing.CloseFrame;
import org.java_websocket.handshake.ServerHandshake;

public class WebSocketPlugin implements StreamHandler, MethodCallHandler {
  private static final String METHOD_CHANNEL_NAME = "u-wave.net/websocket";
  private static final String EVENT_CHANNEL_NAME = "u-wave.net/websocket-events";

  private static final String KEEPALIVE = "-";
  private static final String OPEN_MESSAGE = "+open";
  private static final String CLOSE_MESSAGE = "+close";

  /** Plugin registration. */
  public static void registerWith(Registrar registrar) {
    final MethodChannel methodChannel = new MethodChannel(registrar.messenger(), METHOD_CHANNEL_NAME);
    final EventChannel eventChannel = new EventChannel(registrar.messenger(), EVENT_CHANNEL_NAME);
    final WebSocketPlugin plugin = new WebSocketPlugin();
    methodChannel.setMethodCallHandler(plugin);
    eventChannel.setStreamHandler(plugin);
  }

  private WebSocketClient client;
  private EventSink sink;
  private final LinkedList<String> queuedMessages = new LinkedList<>();

  private void pushMessage(String message) {
    if (sink != null) {
      sink.success(message);
    } else {
      queuedMessages.add(message);
    }
  }

  public void onOpen(ServerHandshake handshake) {
    System.out.println("[WebSocketPlugin] onOpen()");
    if (sink == null) {
      // Shouldn't happen but don't crash if it does I guess
      return;
    }

    sink.success(OPEN_MESSAGE);
  }

  public void onMessage(String message) {
    System.out.println("[WebSocketPlugin] onMessage(" + message + ")");
    if (message.equals("-")) {
      return;
    }

    pushMessage(message);
  }

  public void onClose(int code, String reason, boolean remote) {
    System.out.println("[WebSocketPlugin] onClose(" + reason + ")");
    if (sink == null) {
      // Closed by the Dart code calling onCancel(), nothing to do here
      return;
    }

    sink.success(CLOSE_MESSAGE);

    // TODO auto reconnect if necessary
    sink.endOfStream();
    sink = null;
  }

  public void onError(Exception err) {
    System.out.println("[WebSocketPlugin] onError(" + err.getMessage() + ")");
    sink.error(err.getClass().getName(), err.getMessage(), null);
  }

  private void onConnect(URI url) {
    if (client != null) {
      client.close(CloseFrame.GOING_AWAY);
      client = null;
    }

    while (queuedMessages.size() > 0) {
      pushMessage(queuedMessages.pop());
    }

    client =
        new WebSocketClient(url, new Draft_6455()) {
          @Override
          public void onOpen(ServerHandshake handshake) {
            WebSocketPlugin.this.onOpen(handshake);
          }

          @Override
          public void onMessage(String message) {
            WebSocketPlugin.this.onMessage(message);
          }

          @Override
          public void onClose(int code, String reason, boolean remote) {
            WebSocketPlugin.this.onClose(code, reason, remote);
          }

          @Override
          public void onError(Exception err) {
            WebSocketPlugin.this.onError(err);
          }
        };

    client.connect();
  }

  private void onSend(String message) {
    client.send(message);
  }

  private void onClose() {
    client.close();
  }

  /* MethodCallHandler */
  @Override
  @SuppressWarnings("unchecked")
  public void onMethodCall(MethodCall call, Result result) {
    switch (call.method) {
      case "send":
        if (call.arguments instanceof String) {
          onSend((String) call.arguments);
          result.success(null);
        } else {
          throw new IllegalArgumentException("Expected a String");
        }
        break;
      case "close":
        onClose();
        result.success(null);
        break;
      default:
        result.notImplemented();
    }
  }

  /* StreamHandler */
  @Override
  @SuppressWarnings("unchecked")
  public void onListen(Object arguments, EventSink events) {
    System.out.println("[WebSocketPlugin] onConnect(" + arguments + ")");
    if (arguments instanceof String) {
      sink = events;

      URI url;
      try {
        url = new URI((String) arguments);
      } catch (URISyntaxException err) {
        throw new IllegalArgumentException("Expected a URI", err);
      }

      onConnect(url);
    } else {
      throw new IllegalArgumentException("Expected a String");
    }
  }

  @Override
  public void onCancel(Object arguments) {
    client.close();
    client = null;
    sink = null;
    queuedMessages.clear();
  }
}
