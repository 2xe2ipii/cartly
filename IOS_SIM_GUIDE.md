# Run Cartly in the iOS Simulator

The app opens a shopping list with loading, empty, and error states. You can add
items, mark them bought or unbought, delete one item, and clear all bought items.

## 1. Check the local tools

On this Mac, Flutter 3.47.6 and Xcode 27 are installed, and an iOS 27 simulator
runtime is available. The current app built for iOS Simulator successfully with
`flutter build ios --simulator`. CocoaPods is not installed; this app currently
has no native plugin that requires it. Check the setup before running:

```sh
flutter doctor -v
xcrun simctl list devices available
```

If a later dependency requires CocoaPods, install it using the
[Flutter iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup)
and confirm that `pod --version` works.

## 2. Start the backend in Terminal A

Make sure `backend/.env` points to your Firebase project and an absolute
service-account key path outside this repository. See the root `README.md` for
the clean-machine Firebase and index setup. Then run:

```sh
cd /Users/drexlerreyes/Professional/Cartly/backend
npm ci
npm run build
npm run start
```

Leave this terminal open. In another terminal, verify the API:

```sh
curl -i -H 'X-User-Id: demo_user' http://127.0.0.1:3000/items
```

A working empty list returns `200` with `{"items":[]}`. The app and this curl
command must use the same user ID to see the same items.

## 3. Start an iOS Simulator

Pick an available iPhone from `xcrun simctl list devices available`. For the
installed iPhone 18 Pro on this Mac, run:

```sh
xcrun simctl boot 'iPhone 18 Pro'
open /Applications/Xcode.app/Contents/Applications/DeviceHub.app
xcrun simctl bootstatus 'iPhone 18 Pro' -b
flutter devices
```

Xcode 27 uses **Device Hub** on this Mac; `open -a Simulator` fails because the
old `Simulator.app` is absent. Select the iPhone 18 Pro in Device Hub to see its
screen. Run `simctl boot` only while that device is `Shutdown`. The first boot may
take time for Apple's data migration. Wait for `bootstatus` to finish and for
the iPhone to appear in `flutter devices` before running the app.

## 4. Run Flutter in Terminal B

Once `flutter devices` shows the iPhone 18 Pro, run:

```sh
cd /Users/drexlerreyes/Professional/Cartly/app
flutter pub get
flutter run -d 'iPhone 18 Pro' --dart-define=API_BASE_URL=http://127.0.0.1:3000 --dart-define=USER_ID=demo_user
```

The app loads the list automatically. An empty `demo_user` list shows **Your
list is empty**. Tap **Add item** to enter a name and quantity. On the list,
use the checkbox to change bought state, the trash icon to delete one item, or
**Clear bought** to remove bought items together. Use the refresh button after
changing data outside the app. The iOS app permits local HTTP using
[`NSAllowsLocalNetworking`](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking)
in `ios/Runner/Info.plist`.

The first debug build and simulator install may take several minutes while the
terminal shows only `Launching...`. If Cartly appears on the simulator home screen
but does not come to the foreground, run this in another terminal:

```sh
xcrun simctl launch booted com.example.cartly
```

If the app cannot connect, verify that Terminal A is still running, the curl
check succeeds, and the backend's `PORT` is 3000. If iOS asks for local network
access during debugging, allow it so Flutter hot reload can connect; see
[Flutter's iOS debugging guide](https://docs.flutter.dev/platform-integration/ios/ios-debugging).

## 5. Show the latest code

`flutter build ios --simulator` creates a new app bundle on the Mac. It does not
replace the version already installed on the simulated iPhone. To install and
launch the current code, run the `flutter run` command from step 4 again.

While `flutter run` remains active, press `r` in that terminal for hot reload or
`R` for a full hot restart after startup changes. Press `q` to end the session.
If the terminal session is closed, rerun `flutter run` to build, install, and
launch the latest app.
