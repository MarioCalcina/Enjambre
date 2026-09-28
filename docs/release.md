# Release

1. Increase version field in `app/pubspec.yaml`. Increase build number by `+1`.
   Bump at least the patch number too: the Microsoft Store derives the MSIX version
   from `major.minor.patch` and rejects a submission that is not strictly greater.
1. Add the release notes as
   `app/android/fastlane/metadata/android/en-US/changelogs/<buildNumber>.txt`.
   The file is named after the build number (Android `versionCode`) and is used for
   both the Play Store "what's new" and the GitHub release body.
1. Update `app/linux/packaging/com.enjambre.Enjambre.metainfo.xml` to add a
   release note entry.
1. Create commit & tag with format `vx.y.z`.
1. `git push && git push origin tag vx.y.z`

CI then builds every enabled platform and publishes the GitHub release with the
changelog as its body.

Linux and Windows always build. macOS, iOS and Android need signing secrets, so their
jobs are skipped until the `BUILD_MACOS`, `BUILD_IOS` and `BUILD_ANDROID` repository
variables are set to `true` (Settings → Secrets and variables → Actions → Variables).

When the `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_SERVICE_ACCOUNT` repository
variables are set, CI also uploads the bundle to the Play Store production track along
with the whole listing from `app/android/fastlane/metadata/` (descriptions, icon and
screenshots).

1. Check the published release binaries.
1. Submit the `.msix` from the `enjambre-windows` artifact to the Microsoft Store.

## Store listing

The Play Store listing (descriptions, icon, screenshots) lives in
`app/android/fastlane/metadata/` and is pushed on every release, so keep it up to date
there rather than editing it in the Play Console — the repository always wins.
