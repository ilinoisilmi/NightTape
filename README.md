# NightTape 🌙🎙️

An iPhone sleep recorder for people who want to **wake up and listen to their night**.

Press one button, lock your phone, and go to bed. Overnight, NightTape listens with the
microphone, figures out when you actually fell asleep, and saves clips of everything
interesting — snoring, sleep talking, coughing, laughing, yes even farts. In the morning
the alarm rings, you hit stop, and the app greets you with *"Last night, in your own
voice"* — a playable timeline of your night.

Built to be **sideloaded** — no Mac, no App Store, no developer account needed beyond a
free Apple ID.

---

## Features

| Feature | How it works |
|---|---|
| 🎙️ Overnight recording | Mic runs in true background with the screen off (background-audio entitlement). Only *events* are saved — not 8 hours of silence. |
| 🧠 Sleep detection | ~10 min of silence (configurable) = you're asleep. Events are only recorded *after* sleep onset, so pre-sleep TV/scrolling noise doesn't spam your tape. |
| 🏷️ On-device sound classification | Apple's SoundAnalysis framework (300+ classes, fully offline): snoring, speech, laughter, coughing, farting, and more. Every clip gets a label and confidence. |
| 🔒 Lock screen Live Activity | Elapsed timer + live audio waveform bars + clip count, above the clock on your lock screen (and in the Dynamic Island). Timer ticks in real time; bars refresh every ~3 s. |
| ⏰ Alarm that beats silent mode | Playback-category audio rings even with the ring/silent switch on, with a gentle 8 s fade-in. Snooze 5 min. |
| 🌅 Smart wake window | Up to 30 min before the alarm, if you're stirring (noise detected), it wakes you at the light-sleep moment instead of deep sleep. |
| 📼 Morning report | Sleep score, time asleep, time-to-fall-asleep, per-minute activity chart, and every clip with play + share. **Play your night** = all clips back to back. |
| 📜 History | Every night saved with its clips. Swipe to delete, auto-cleanup after N days. |
| 🔋 Battery guard | At 20 % battery (and not charging) the session is saved cleanly and recording stops. Crash-safe: the session file is re-written every 5 minutes, so even a force-quit or a crash loses at most a few minutes. |
| 🕶️ OLED dark UI | Pure black, purple→cyan gradient. Easy on 3 AM eyes. |
| 🔐 Private by architecture | All classification is on-device, all audio stays in the app's sandbox. Nothing is uploaded — there's no server code at all. |

---

## What you need

- iPhone on **iOS 18 or newer** (Live Activities need it)
- A **Windows PC** (only used to put the app on the phone the first time)
- A **GitHub account** (free) — that's your "Mac in the cloud" for building
- A **free Apple ID** (the app refreshes every 7 days with it; or sign with a paid
  account for a full year)
- **SideStore** on the iPhone (or AltStore / Sideloadly — pick one, guide below)

---

## Build the IPA (Windows, ~10 minutes, no Mac)

1. **Create a GitHub repository** — log in at github.com, click **New repository**,
   name it anything (e.g. `nighttape`), keep it **Private** (free accounts include
   private repos with Actions minutes), don't add a README.

2. **Upload this folder's contents** — on the empty repo page click
   *"uploading an existing file"* and drag **everything in this folder** (keep the
   folder structure: `.github/`, `App/`, `Widget/`, `project.yml`, …). Commit.

   *(Git-savvy alternative: clone the repo, copy these files in, push.)*

3. **Run the build** — go to the **Actions** tab, click **I understand my workflows,
   go ahead and enable them**, select **Build IPA** on the left, click **Run workflow**
   → **Run workflow** (branch `main`).

4. **Download the IPA** — the run takes ~5–10 min. When the green check appears, open
   the run, scroll to **Artifacts**, download **NightTape-IPA**, unzip it →
   `NightTape.ipa`.

   *(Tip: tag a release like `v1.0.0` instead, and the IPA gets attached to a proper
   GitHub Release.)*

## Install on your iPhone

Pick one route:

### Route A — SideStore (recommended: refreshes on-device, no weekly PC ritual)

1. Set up SideStore once by following the official guide:
   **https://docs.sidestore.io** (it walks you through pairing your iPhone and
   installing SideStore — this is the only time you need the Windows PC).
2. Open SideStore → **+** → pick `NightTape.ipa` → it signs it with your Apple ID and
   installs.
3. Every 7 days: open SideStore and tap **Refresh all** — done on the phone, no PC.

### Route B — Sideloadly (simplest start, but needs the PC weekly)

1. Install Sideloadly on Windows: **https://sideloadly.io**
2. Plug the iPhone in, open Sideloadly, drag `NightTape.ipa` in, enter your Apple ID,
   it installs directly.
3. On the iPhone: Settings → General → VPN & Device Management → trust your Apple ID.
4. Every 7 days: repeat with the PC plugged in.

### Route C — AltStore

Same idea as SideStore; see **https://altstore.io**. Needs AltServer running on the
PC for each refresh.

---

## First night — 5 minute setup (once)

1. **Open the app** → allow microphone access, allow notifications.
2. If the lock screen waveform doesn't show later:
   Settings → Apps → NightTape → **Live Activities** → ON.
3. **Mute everything else**: the in-app guide (Home screen → *"Mute notifications all
   night"*) walks you through a one-time **Sleep Focus schedule** (Settings → Focus →
   Sleep → add schedule). iOS never lets an app flip Do Not Disturb itself — a Focus
   schedule is the supported way, and it repeats nightly on its own.
4. **Set the alarm time** on the home screen and toggle it on.
5. Place the phone on the nightstand, **mic side (bottom edge) toward you**, ideally
   **plugged in**.
6. Press **Start Sleep**, lock the phone, done.

Overnight you'll see the Live Activity on the lock screen: timer + waveform. When the
alarm rings, tap **Stop & hear my night**.

---

## How it works (for the curious / for tweaking)

```
mic (48 kHz) ──► RMS level (0…1)          ──► sleep detector (silence ⇒ asleep)
            └─► SoundAnalysis classifier  ──► labels (snoring, speech, fart…)
            └─► downsample to 16 kHz ──► ring buffer (pre-roll)
                                     └► EventRecorder: level spike or interesting
                                        label while asleep ⇒ save .m4a clip with
                                        pre-roll, close after 6 s of quiet
```

- **Sensitivity** (Settings): maps to the level threshold that opens a clip.
- **Silence minutes** (Settings): how long quiet must last before you're "asleep".
- Smart wake looks for *recent noise* in the window before the alarm — noise while
  asleep usually means light sleep / stirring.
- Sleep score is a fun heuristic (duration vs 7.5 h, snoring, events per hour) —
  **not** medical-grade. Mic-only sleep staging is an approximation and is labeled as
  such in the app.

## Project layout

```
project.yml            XcodeGen spec (generates the .xcodeproj)
.github/workflows/     GitHub Actions: unsigned Release IPA for sideloading
App/Sources/           App target — audio engine, alarm, Live Activity, SwiftUI UI
App/Shared/            Live Activity attributes (compiled into app + widget)
App/Resources/         alarm.wav, silence.wav (keep-alive loop)
App/Assets.xcassets    Icon + accent color
Widget/                Widget extension — the lock screen Live Activity
```

The Xcode project is **generated** by XcodeGen (`xcodegen generate`) — the CI does it
automatically. If you ever get a Mac: `brew install xcodegen`, generate, open, flip
code signing back on in Signing & Capabilities.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Recording stops mid-night | Don't swipe the app away in the app switcher — that kills it by design. Just press Start and lock the phone. Also check Settings → Apps → NightTape → Background App Refresh is ON. |
| No lock screen waveform | Settings → Apps → NightTape → Live Activities ON. Note: it updates every ~3 s, not 60 fps — iOS caps Live Activity updates. |
| Alarm didn't ring | The alarm only runs while a session is recording — start the night in the app. Check the toggle + time on the home screen. |
| Almost no clips | Raise **Mic sensitivity** in Settings; move the phone closer, bottom edge toward you. |
| Millions of snore clips | Lower sensitivity. Consecutive events also have an 8 s cooldown. |
| Clips sound far away | Disconnect AirPods/earbuds — the app already forces the built-in mic, but Bluetooth can still steal the route on reconnect. |
| Battery died | Plug in overnight. If you can't, the 20 % guard saves everything so far. |

## Honest limitations

- No true 60 fps lock screen visualizer — impossible for third-party apps; the Live
  Activity refreshes every ~3 s (the timer ticks live, the bars are the recent level
  history).
- The app cannot toggle Do Not Disturb itself (iOS sandbox rule) — that's why the
  Sleep Focus one-time setup exists.
- Free Apple ID signing = refresh every 7 days (SideStore can do it on-device).
- Sleep phases from a mic are an estimate, not a polysomnograph.

---

*NightTape is for personal use. All processing is on-device; there is no network code
in the app target at all.*
