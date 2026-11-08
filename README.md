# Addis Surfers · አዲስ ሰርፈርስ

An endless runner set on the rail lines of Addis Ababa, for **Android and iOS**,
built with Flutter + [Flame](https://flame-engine.org/) and monetised with
**Google AdMob**.

Run with Meaza, Tadesse and Yoseph along three tracks. Dodge Addis light-rail
trains (some come straight at you), jump barriers, roll under "ቁም / STOP" boards,
run up ramps onto the train roofs, and collect birr coins and power-ups.

## Features

**Gameplay**
- Pseudo-3D track drawn with a perspective camera (no heavy 3D engine), so it
  runs smoothly on low-end Android phones.
- 3 playable characters based on the key art (Meaza, Tadesse, Yoseph).
- Trains in orange, white and the Ethiopian flag colours, plus ramps onto the
  roofs, oncoming trains and barriers to jump or roll under.
- Power-ups on the track: **Coin Magnet**, **x2 Score**, **Super Jump** and
  **Jetpack** (fly over everything along a trail of coins in the sky).
- **Boosts** from the shop: **Gasha Shield** (absorbs one crash; tap the button
  or double-tap the screen) and **Head Start** (a jetpack dash at the start of a
  run).
- **Gems** (rare on the track) revive you after a crash. Each revive in a run
  costs double: 1, 2, 4... A rewarded ad also revives you, once per run.
- Pause screen with your missions and a 3-2-1 countdown when you resume.

**Progression**
- **Missions**: 3 at a time. Finishing a set raises your permanent **score
  multiplier** (up to x30) and gives you a gem. You can skip a mission for 3
  gems.
- **Daily Word**: letter tiles appear on the track. Spell today's Addis word
  (BUNNA, INJERA, MESKEL, MERKATO...) for 1500 coins + 2 gems.
- **Daily rewards**: a 7-day streak calendar (coins, shields, head starts, gems).

**Marketplace (Shop)**
- Upgrades: 5 levels for each power-up, so they last longer.
- Boosts: shields and head starts.
- Bank: trade gems for coins, or watch a short video for free coins.
- Crew: unlock and select characters.

**Settings**
- Music and sound effect volume, vibration, battery-saver graphics,
  show the tutorial again, ad privacy choices, reset progress.

**Ethiopian soundtrack**
- "Tezeta" (menu) uses the Tezeta minor *qenet*: slow krar arpeggios and a
  washint flute melody.
- "Merkato Run" (gameplay) uses the Ambassel *qenet*: a 6/8 eskista groove on
  kebero drums, a krar ostinato and masenqo (fiddle) and washint melodies, with
  hand claps.
- All music and sound effects are original and synthesised by
  `tools/generate_audio.py`, so you own them outright. To regenerate them:
  `pip install numpy scipy`, then `python3 tools/generate_audio.py` (needs
  ffmpeg).

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
  settings.dart             player settings (volume, vibration, graphics)
  audio/audio_manager.dart  music + sound effects
  meta/                     economy, missions, daily rewards & daily word
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
    shop_screen.dart        marketplace
    missions_screen.dart    missions + daily word
    settings_screen.dart    settings
    daily_reward_dialog.dart 7-day rewards
    widgets.dart            logo, buttons, badges
assets/images/              character portraits from the key art
assets/fonts/               Noto Sans Ethiopic (SIL OFL 1.1)
assets/audio/               generated music & sound effects
tools/generate_audio.py     soundtrack synthesiser
```

## Ideas for the next updates

- A "Remove ads" in-app purchase (`in_app_purchase`), and coin packs.
- Daily missions and login rewards, which help retention.
- Firebase Analytics + Crashlytics, and Remote Config so you can tune ad
  frequency without shipping an update.
- More characters, outfits and boards to buy with coins.
- Leaderboards (Google Play Games / Game Center).
