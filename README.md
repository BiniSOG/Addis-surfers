# Addis Surfers · አዲስ ሰርፈርስ

_Developed by **Binyam Bayu**._

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

**Engagement features**
- **Goat chaser**: a street goat with a bell chases you off the platform at the
  start of every run and after you stumble. Stumble again while it's on your
  heels and it catches you.
- **Lucky Spin**: one free spin a day, plus 3 extra spins for watching an ad.
  Prizes include coins, gems, boosts and Mesob Surprises.
- **Mesob Surprise**: a mystery basket (750 coins, or from spins and events)
  with coins, gems, boosts, or a rare new crew member.
- **Weekly event "Meskel Daisies"**: pick yellow *adey abeba* flowers on the
  track to unlock 7 reward tiers, up to a free character. Progress resets every
  Monday.
- **Trophies**: 15 achievements (runs, coins, scores, jetpacks, roof running,
  words, flowers, crew, missions...), each with a reward to claim.
- A **"NEW BEST SCORE!"** moment the instant you beat your record mid-run.

**Marketplace (Shop)**
- Upgrades: 5 levels for each power-up, so they last longer.
- Boosts: shields, head starts and Mesob Surprise baskets.
- Bank: trade gems for coins, or watch a short video for free coins.
- Crew: unlock and select characters.

**Settings**
- Music and sound effect volume, vibration on/off and strength, battery-saver graphics,
  show the tutorial again, ad privacy choices, reset progress.

**Adaptive soundtrack**
- The background music is your track (`tools/source/addis_groove_source.mp3`,
  ~126 bpm, G major), cut into a seamless loop on a bar line.
- The music reacts to what you do. Every version shares one timeline, and the
  game crossfades between them in time with the beat:
  - **Menu**: muffled, like music from the next room. It opens up into the full
    track when you start running.
  - **Magnet**: a shimmering phaser sweep.
  - **Super-jump shoes**: heavy, punchy bass.
  - **Jetpack / Head Start**: airy and echoing, "up in the clouds".
  - **Roll**: the music dips briefly as you tumble.
  - **Crash**: the song grinds to a halt like a turntable losing power ("tape
    stop"), then the results screen carries on with the muffled mix.
- Jump, super-jump, roll, magnet, takeoff and landing sounds are tuned to G
  major so they sit inside the song.
- To use a different song: replace the source file and run
  `pip install numpy librosa`, then `python3 tools/process_music.py`.
  `tools/generate_audio.py` makes the sound effects (and, with `--themes`, the
  original Tezeta / Merkato Run qenet themes).

**Vibration**
- Each action has its own pattern, with strength control where the phone
  supports it (Android 8+, iPhone 8+ through Core Haptics):
  - a light tick for coins and lane changes
  - a crisp tap for a jump
  - a squash-and-release spring for a super jump
  - two soft bumps for a roll
  - rising "zzzing" pulses for the magnet
  - a building engine rumble at jetpack takeoff
  - a heavy thump on landing
  - a hard double hit for a crash
  - celebration pulses for rewards
- Settings has a vibration toggle and a **strength** slider. Older phones fall
  back to the system's standard haptic clicks.

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

**Test APKs (sideloading).** GitHub Actions builds two APKs on every push
and publishes them on the `apk-latest` release:
- `addis-surfers-arm64.apk`: smaller, works on almost all modern phones.
- `addis-surfers.apk`: universal.

Both are signed with `android/app/sideload.jks`. This is a fixed **test** key,
committed on purpose so that every build has the same signature and installs
as an update over the previous one. The build fails if that ever changes.
Don't use this key for the Play Store.

**Android (Google Play)**
1. Create your private upload key (keep it safe and never commit it):
   `keytool -genkey -v -keystore ~/addis-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Create `android/key.properties` (it is git-ignored):
   ```
   storeFile=/home/you/addis-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```
   Release builds use it automatically when the file exists.
3. Change `applicationId` (`com.addissurfers.addis_surfers`) if you want a
   different package name. You can't change it after you publish.
4. `flutter build appbundle --release ...` (see above), then upload the `.aab`.
5. In the Play Console, declare in the Data safety form that the app uses the
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
  audio/audio_manager.dart  adaptive music + sound effects
  audio/haptics.dart        vibration patterns
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
    lucky_spin.dart         daily prize wheel
    mesob_dialog.dart       mystery basket reveal
    event_screen.dart       weekly Meskel Daisies event
    trophies_screen.dart    achievements
    widgets.dart            logo, buttons, badges
assets/images/              character portraits from the key art
assets/fonts/               Noto Sans Ethiopic (SIL OFL 1.1)
assets/audio/               generated music & sound effects
tools/process_music.py      turns the source song into the adaptive music
tools/generate_audio.py     sound effect synthesiser
```

## Ideas for the next updates

- A "Remove ads" in-app purchase (`in_app_purchase`), and coin packs.
- Firebase Analytics + Crashlytics, and Remote Config so you can tune ad
  frequency without shipping an update.
- More characters, outfits and boards to buy with coins.
- Leaderboards (Google Play Games / Game Center).
