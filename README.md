# üWave for Android

A [Flutter](https://flutter.io) and [NewPipe](https://newpipe.schabi.org) based client for [üWave](https://u-wave.net)!

Note that while it uses Flutter, it's not cross platform. Only Android is supported.

At some point this will be posted to the F-Droid app store. Because we're using NewPipe, the Play Store is not an option :)

## Status

You can:

 - View public servers
 - Join public servers
 - Listen while the app is foregrounded
 - Change playback type (with or without video) and configure a different type for WiFi/data connections
 - Read chat
 - Sign in to public servers and send chat

You can't:

 - Listen while the app is backgrounded
 - Configure video resolution preference and limits
 - View online users
 - Moderate chat
 - Join the waitlist yourself
 - Playlist management etc
 - Most other things

The above is also more or less in order of implementation priority, aiming for the top things first and working our way down.

## Screenshots

[<img src="./assets/screenshots/servers.png" alt="Server List" width=320>](./assets/screenshots/servers.png)
[<img src="./assets/screenshots/listen.png" alt="Listening" width=320>](./assets/screenshots/listen.png)

## Getting Started

First [install Flutter](https://flutter.io/get-started/install/).

Then, clone the repository:

```bash
git clone https://github.com/u-wave/flutter.git u-wave-flutter
cd u-wave-flutter
```

Connect your phone using USB debugging. Then you can run the app:

```bash
flutter run
```

## License

[GPL-3.0](./LICENSE.md)
