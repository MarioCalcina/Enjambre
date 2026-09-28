# Development

You will need the flutter SDK to be installed on your platform.
Follow the guide at https://docs.flutter.dev/get-started/install.

## Linux

You might need to install `cmake`, `openssl`, `ninja`, `curl`.

```sh
git clone --recurse-submodules <your repository url>
cd <repository>/app
flutter run # start the app in development mode
flutter build linux # release
```

## MacOS

```sh
git clone --recurse-submodules <your repository url>
cd <repository>/app
export VCPKG_ROOT="$(pwd)/vcpkg"
export VCPKG_MANIFEST_DIR=$(pwd)
# Should be same as defined in /app/macos/Runner.xcodeproj
export MACOSX_DEPLOYMENT_TARGET=10.14
./vcpkg/bootstrap-vcpkg.sh
flutter run -d macos # start the app in development mode
```

## Windows:

```powershell
git clone --recurse-submodules <your repository url>
cd <repository>/app
$Env:VCPKG_ROOT="$(pwd)/vcpkg"
$Env:VCPKG_MANIFEST_DIR="$(pwd)"
# Workaround for https://gitlab.kitware.com/cmake/cmake/-/issues/25936
$Env:TRANSMISSION_PREFIX="C:\Users\[YOUR_USER]\transmission-prefix"
.\vcpkg\bootstrap-vcpkg.bat
flutter run
```


## Android (Linux host)

Install & configure Android SDK/NDK first.

```sh
git clone --recurse-submodules <your repository url>
cd <repository>/app
export VCPKG_ROOT="$(pwd)/vcpkg"
export VCPKG_MANIFEST_DIR=$(pwd)
# vcpkg needs it to build curl & openssl, use the ndkVersion of android/app/build.gradle
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/<version>"
./vcpkg/bootstrap-vcpkg.sh
flutter devices # List available devices
flutter run -d {device} # start the app in development mode
```

## Android (Windows host)

Same as above, plus a short path for the Transmission sources (Windows limits paths
to 260 characters) and `ninja` on the `PATH` for the nested Transmission builds. The
Android SDK ships one next to its CMake.

```powershell
git clone --recurse-submodules <your repository url>
cd <repository>/app
$Env:VCPKG_ROOT="$(pwd)/vcpkg"
$Env:VCPKG_MANIFEST_DIR="$(pwd)"
# Use the ndkVersion of android/app/build.gradle
$Env:ANDROID_NDK_HOME="$Env:LOCALAPPDATA\Android\Sdk\ndk\<version>"
$Env:TRANSMISSION_PREFIX="C:\Users\[YOUR_USER]\transmission-prefix"
$Env:PATH="$Env:LOCALAPPDATA\Android\Sdk\cmake\3.22.1\bin;$Env:PATH"
.\vcpkg\bootstrap-vcpkg.bat
flutter build apk --release --target-platform android-arm64
```

Without `android/key.properties` the release APK is signed with the debug key: it
installs fine, but has to be uninstalled before installing one signed with the real
key.

### iOS (From a MacOS host)

```sh
git clone --recurse-submodules <your repository url>
cd <repository>/app
export VCPKG_ROOT="$(pwd)/vcpkg"
export VCPKG_MANIFEST_DIR=$(pwd)
export TARGET_IOS_DEVICE=false # false to target emulator, true to target real device
export IPHONEOS_DEPLOYMENT_TARGET=12 # Should be same as defined in /app/ios/Runner.
./vcpkg/bootstrap-vcpkg.sh
flutter devices # List available devices
flutter run -d {device_id} # start the app in development mode
```
