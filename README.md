# Addis Surfers · አዲስ ሰርፈርስ

An endless runner set on the rail lines of Addis Ababa, for **Android and iOS**,
built with Flutter + [Flame](https://flame-engine.org/) and monetised with
**Google AdMob**.

Run with Meaza, Tadesse and Yoseph along three tracks. Dodge Addis light-rail
trains (some come straight at you), jump barriers, roll under "ቁም / STOP" boards,
run up ramps onto the train roofs, and collect birr coins and power-ups.

## Features

- Pseudo-3D track drawn with a perspective camera (no heavy 3D engine), so it
  runs smoothly on low-end Android phones.
- 3 playable characters based on the key art, animated from behind. Their
  portraits from the art appear on the Crew screen. Tadesse and Yoseph are
  unlocked with coins.
- Trains in orange, white and the Ethiopian flag colours, with "ADDIS / አዲስ አበባ /
  ETHIOPIA" graffiti livery, plus ramps and oncoming trains.
- Power-ups: **Magnet**, **x2 Score**, **Super Jump** (high enough to jump onto
  train roofs).
- Difficulty and speed rise over time. The track generator always leaves at
  least one lane free of trains, and a unit test checks this.
- Swipe controls (arrow keys / WASD also work when debugging).
- Coins, best score, unlocked characters and the selected character are saved
  on the device.
- Bundled Noto Sans Ethiopic font, so Amharic looks the same on every device.

## Ad strategy (AdMob)

| Format | Where | Rules |
|---|---|---|
| **Banner** (anchored adaptive "small bar") | Main menu, pause screen, game-over screen | Never during gameplay by default, because swipes near a banner cause accidental clicks, which AdMob penalises. You can turn it on with `AdConfig.bannerDuringGameplay`. |
| **Interstitial** (full screen) | When the player leaves the game-over screen (Run again / Home) | Not in a new player's first 2 runs, at most once every 3 runs, at least 150 s apart, and not within 60 s of a rewarded ad. |
| **Rewarded** (full screen, opt-in) | "Watch ad to continue" after a crash (once per run), "Double coins" on game over, "+150 free coins" on the menu | Always the player's choice. Usually the best earner. |

All of these rules are in `lib/ads/ad_config.dart`. Consent is collected with
Google's **UMP SDK** (GDPR/EEA) before any ad is requested. When the user's
region requires it, a privacy-settings button appears on the menu.

> **Test ads by default.** Every ad unit id defaults to Google's public test
> ids, so you can develop without putting your AdMob account at risk.

### Going live with your AdMob account

1. In AdMob, create two apps (Android and iOS). For each app create a
   **Banner**, an **Interstitial** and a **Rewarded** ad unit.
2. **Android app id:** add this line to `android/gradle.properties`:
   `admobAppId=ca-app-pub-XXXXXXXX~YYYYYYYY`
3. **iOS app id:** replace `GADApplicationIdentifier` in `ios/Runner/Info.plist`.
4. Build with your ad unit ids:

```bash
flutter build appbundle --release \
  --dart-define=ADMOB_ANDROID_BANNER=ca-app-pub-XXX/111 \
  --dart-define=ADMOB_ANDROID_INTERSTITIAL=ca-app-pub-XXX/222 \
  --dart-define=ADMOB_ANDROID_REWARDED=ca-app-pub-XXX/333

flutter build ipa --release \
  --dart-define=ADMOB_IOS_BANNER=ca-app-pub-XXX/444 \
  --dart-define=ADMOB_IOS_INTERSTITIAL=ca-app-pub-XXX/555 \
  --dart-define=ADMOB_IOS_REWARDED=ca-app-pub-XXX/666
```

5. In AdMob, go to **Privacy & messaging** and publish a GDPR message (and an
   IDFA explainer for iOS) so that the UMP consent form shows.
6. Add an `app-ads.txt` file to your website (AdMob shows you the exact line to
   put in it).

## Running locally

Requirements: Flutter 3.47+ (Dart 3.13), Android Studio / Android SDK,
and Xcode for iOS.

```bash
flutter pub get
flutter run            # on a connected phone or emulator
flutter test           # track-fairness test
```

## Releasing

**Android (Google Play)**
1. Create an upload keystore and add a `signingConfig` in
   `android/app/build.gradle.kts`. It currently signs release builds with the
   debug key.
2. Change `applicationId` (`com.addissurfers.addis_surfers`) if you want a
   different package name. You can't change it after you publish.
3. `flutter build appbundle --release ...` (see above), then upload the `.aab`.
4. In the Play Console, declare in the Data safety form that the app uses the
   advertising ID.

**iOS (App Store)**
1. Open `ios/Runner.xcworkspace` in Xcode, set your Team and Bundle Identifier.
2. `flutter build ipa --release ...`, then upload with Xcode or Transporter.
3. Fill in App Privacy, including the tracking and identifier use by AdMob.

## Project layout

```
lib/
  main.dart                 app entry (portrait, immersive, ads init)
  characters.dart           Meaza / Tadesse / Yoseph data & prices
  progress.dart             saved coins, best score, unlocks
  ads/
    ad_config.dart          ad unit ids + placement rules
    ad_manager.dart         UMP consent, interstitial & rewarded logic
    banner_ad.dart          adaptive banner widget
  game/
    addis_game.dart         simulation: physics, collisions, power-ups
    track_generator.dart    procedural, fair obstacle layout
    renderer.dart           perspective renderer (track, trains, city)
    character_painter.dart  animated characters
    textures.dart           pre-rendered train / barrier textures
    entities.dart           world constants & entity types
  ui/
    game_screen.dart        menu, HUD, pause, continue, game over
    character_select.dart   Crew screen
    widgets.dart            logo, buttons, badges
assets/images/              character portraits from the key art
assets/fonts/               Noto Sans Ethiopic (SIL OFL 1.1)
```

## Ideas for the next updates

- Sound effects and music (add `flame_audio`).
- A "Remove ads" in-app purchase (`in_app_purchase`), and coin packs.
- Daily missions and login rewards, which help retention.
- Firebase Analytics + Crashlytics, and Remote Config so you can tune ad
  frequency without shipping an update.
- More characters, outfits and boards to buy with coins.
- Leaderboards (Google Play Games / Game Center).
