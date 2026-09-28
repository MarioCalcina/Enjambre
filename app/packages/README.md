# Local packages

Plugins kept in the repository instead of being fetched from elsewhere.

## flutter_libtransmission

Dart FFI binding to libtransmission, the BitTorrent engine of the app.

The native build (`src/CMakeLists.txt`) clones the official
[Transmission](https://github.com/transmission/transmission) sources at a pinned
commit and applies `src/patches/transmission-streaming.patch`, which tunes the piece
picker for streaming: smaller requests and a shorter timeout in sequential mode, and
slow peers served last. To move to a newer Transmission, update `GIT_TAG` and check
that the patch still applies.

## app_links

[app_links](https://pub.dev/packages/app_links) 6.4.0, with one change in
`windows/app_links_plugin.cpp`: every command line argument is forwarded to the app
without checking that it is a registered URL scheme, so that a `.torrent` file opened
from the Explorer reaches the app as a file path.
