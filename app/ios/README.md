# Habitat Journey for iOS

Open `HabitatJourney.xcodeproj` in Xcode 26 or later and run the `HabitatJourney` scheme on iOS 17+.

The app is local-first: nutrition logs are encoded on device immediately. Cloud sessions use the iOS Keychain. Debug builds target `http://127.0.0.1:8000/`; configure `HJBackendBaseURL` to an HTTPS API URL for release distribution.

Primary implemented flows:

- dashboard calorie and macro tracking
- meal selection, food search, food details, serving adjustment, and logging
- persistent entries, goals, weight history, streak, XP, and habitat unlock state
- progress dashboard and habitat reward journey
- optional account registration/sign-in and secure token storage

Release verification:

```bash
xcodebuild -project HabitatJourney.xcodeproj -scheme HabitatJourney \
  -configuration Release -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```
# Hero animation verification

The native layered hero supports deterministic launch frames for screenshot regression checks:

```bash
xcrun simctl launch --terminate-running-process <device-id> com.habitatjourney.app --hero-reaction logged --hero-frame 0.675
xcrun simctl io <device-id> screenshot /tmp/habitat-hero-logged.png
```

Supported reactions are `opening`, `logged`, `goalReached`, and `supportive`. The frame value is elapsed seconds. Use Accessibility Inspector's Reduce Motion setting to verify the static final pose.
