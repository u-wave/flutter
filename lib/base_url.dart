import 'package:flutter/widgets.dart';

class BaseUrl extends InheritedWidget {
  final Uri url;

  const BaseUrl({Key key, this.url, Widget child}) : super(key: key, child: child);

  static BaseUrl of(BuildContext context) {
    return context.inheritFromWidgetOfExactType(BaseUrl);
  }

  @override
  bool updateShouldNotify(BaseUrl old) => url != old.url;

  Uri resolve(Uri other) =>
    url != null ? url.resolveUri(other) : other;
}
