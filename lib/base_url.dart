import 'package:flutter/widgets.dart';

class BaseUrl extends InheritedWidget {
  final Uri url;
  final Widget child;

  const BaseUrl({Key key, this.url, this.child}) : assert(child != null), super(key: key);

  static BaseUrl of(BuildContext context) {
    return context.inheritFromWidgetOfExactType(BaseUrl);
  }

  @override
  bool updateShouldNotify(BaseUrl old) => url != old.url;

  Uri resolve(Uri other) =>
    url != null ? url.resolveUri(other) : other;
}
