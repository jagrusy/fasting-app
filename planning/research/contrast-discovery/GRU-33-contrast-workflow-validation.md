# GRU-33: Validate the Contrast App's Difficult-Session Workflow

- **Status**: Research Deliverable Complete · Human Interviews & Live Field Tests Pending
- **Author**: Antigravity
- **Date**: 2026-09-20
- **Roadmap Item**: DRAFT-10 (Priority P1, Execution Lane C / Contrast Discovery)
- **Branch**: `codex/gru-33-contrast-validation`
- **Base Commit**: `99f0e2d93eef250914d79d6e5c8e23f05d5c0e44` (merged PR #57 on `main`)
- **Owned Path**: `planning/research/contrast-discovery/`

---

## Executive Summary & Recommendation

| Question | Assessment | Evidence / Rationale |
| :--- | :--- | :--- |
| **Is wet-screen operation a genuine failure mode?** | **YES** (Severe) | Capacitive touchscreens fail when wet, submerged, or coated in sweat. Apple Watch Water Lock disables touch entirely. Shivering or sweat-drenched fingers cannot reliably tap small UI buttons. Interface must be 100% hands-free with physical button fallbacks. |
| **Is automatic water-temp tracking viable as a core baseline?** | **NO** (Gated / Optional) | The owner uses an **Apple Watch Series 7**, which completely lacks a water temperature sensor. Live water temp is restricted to Apple Watch Ultra and Series 10+. Baseline must remain **manual entry with preset defaults** (e.g., 45°F, 50°F, 55°F). |
| **Do users wear Apple Watches in saunas, and can the app support it?** | **YES** (Reality-First Engineering) | While Apple officially rates Apple Watch for 32°–95°F (0°–35°C) and saunas reach 150°–195°F (65°–90°C), **many real-world users (including the repository owner) routinely wear their watch in the sauna**. The app must not block this; it must engineer defensively for it: **durable per-transition disk persistence** so state survives thermal shutdowns/reboots, pure-black low-thermal OLED UI, and hands-free/hardware-button progression. An off-wrist phone timer remains an option for risk-averse sessions. |
| **Is Apple Health (HealthKit) workout syncing a core differentiator?** | **YES** (Primary Moat & Value Driver) | Built-in Apple Watch Timers and Stopwatches do **not** write workouts to Apple Health, leaving users with zero Exercise ring credit, zero active calories, and no heart rate sampling. Competitors often lock HealthKit sync behind $30–$60/year subscriptions. Solstice Contrast delivers high value by providing **free, native, offline-durable HealthKit workout logging** with continuous HR streaming and custom temperature/round metadata. |
| **Does competitor feature parity imply commercial demand?** | **NO** (Contrary Evidence) | Fasted currently has near-zero reported traction. Competitors advertise AI coaches, BLE sauna sensors, and high subscriptions, but user reviews reveal intense frustration with paywalls, water lock friction, and overheating warnings. Built-in Timers are free and "good enough" for timing alone—making **Apple Health workout credit, HR recovery metrics, and hands-free transitions** the only compelling reasons to switch. |
| **Recommendation for DRAFT-15 (Native iOS Prototype)** | **PROCEED CONDITIONALLY** | Proceed to a tightly bounded native prototype **only** if it validates: (1) **Hands-free auto-advancing audio/haptic interval workflow** (zero mid-session touch required); (2) **On-wrist sauna resilience** with durable per-transition disk persistence (survives thermal reboots) and low-thermal UI; (3) **Native Apple Health workout logging** (ring credit, continuous HR, offline durability); and (4) **Series 7 manual temperature baseline**. |

---

## 1. Difficult-Session Realities & Environmental Constraints

Cold plunge, sauna, and contrast therapy environments impose severe physical, thermal, and electronic constraints that typical fitness trackers ignore.

### 1.1 Touchscreen Failure Modes (Wet, Shivering, Sweat & Steam)
* **Capacitive Touch Breakdown**: Apple Watch and iPhone displays rely on mutual capacitance. Water droplets from plunge immersion or heavy beads of sweat in a sauna create conductive paths across electrodes. This results in missed taps, erratic scrolling, or phantom button activations.
* **Water Lock Usability Trap**: When water immersion is detected or Water Lock is enabled, the watch screen is entirely unresponsive to touch. Exiting Water Lock requires spinning and holding the Digital Crown for 2–3 seconds while an audible speaker purge tone plays. Forcing this interaction at the end of a freezing 3-minute plunge while shivering—or mid-sauna while dripping sweat—is a major source of user frustration.
* **Physical Hardware Controls as Mandatory Fallback**:
  * Dedicated physical controls (Digital Crown press, Side Button click, or Apple Watch Ultra Action Button) operate mechanically and remain 100% reliable regardless of water, sweat, or shivering fingers.
  * The session workflow must allow advancing phases, pausing, or stopping via physical button interactions or automatic time-based transitions without requiring a single screen tap.

### 1.2 Thermal Boundaries: Official Hardware Limits vs. Real-World On-Wrist Sauna Usage
* **Official Apple Operating Limits**:
  * Operating ambient temperature: **32° to 95° F (0° to 35° C)**.
  * Non-operating storage temperature: **-4° to 113° F (-20° to 45° C)**.
  * Source: [Apple Support: Keep Apple Watch within acceptable operating temperatures](https://support.apple.com/HT204508) (Verified 2026-09-20).
* **Thermal Realities of Heat Therapy**:
  * Traditional dry saunas: **150° to 195° F (65° to 90° C)**.
  * Infrared saunas: **120° to 140° F (48° to 60° C)**.
  * Steam rooms: **110° to 120° F (43° to 49° C)** at 100% humidity.
* **The Real-World User Behavior (Owner Practice)**:
  * Despite Apple's operating limits and warranty exclusions for saunas/steam rooms, **many active contrast enthusiasts—including the repository owner—deliberately wear their Apple Watch inside traditional and infrared saunas**.
  * Users do this because on-wrist glanceability, haptic interval reminders, and continuous heart rate tracking are far more convenient than checking an external wall clock or phone placed outside the glass.
* **Failure Modes of On-Wrist Sauna Wear**:
  1. *Thermal Throttling & Red Thermometer Shutdown*: After 8–15 minutes in high heat, watchOS internal thermistors may trigger thermal protection, dimming the screen, suspending background tasks, or displaying the red thermometer icon before forcing a device reboot or emergency shutdown.
  2. *Sweat Pools & Conductive Smears*: Heavy sweat pools on the glass, rendering touch impossible without wiping.
  3. *SoC Internal Heat Addition*: CPU/GPU intensive rendering (e.g., 60fps animations, bright colorful backgrounds) generates internal chip heat, speeding up thermal shutdown.
* **Architectural Engineering for On-Wrist Sauna Resilience**:
  1. **Durable Per-Transition Disk Persistence**: The app must **never** store active session state solely in volatile memory (`@State`, view model RAM). Every phase transition (e.g., starting sauna, ending sauna, entering plunge, exiting plunge) must immediately write to durable disk storage (Core Data / SQLite). If watchOS shuts down or restarts due to heat, the app must detect the interrupted session on relaunch, recover all completed segments, and allow immediate resumption or clean sync to HealthKit with zero data loss.
  2. **Low-Thermal Display & Processing Mode**:
     * Pure black (`#000000`) OLED background to eliminate display power dissipation and minimize device heating.
     * Static or 1 Hz countdown updates—no continuous 60fps canvas animations or complex GPU shaders during heat phases.
     * Large, high-contrast monochrome typography legible through steam and sweat at arm's length without wrist-raise wake cycles.
  3. **Dual-Modality Support (On-Wrist + Off-Wrist)**:
     * Support users who wear their watch inside with resilient on-wrist interval tracking.
     * Provide a phone-based Live Activity / glanceable timer or retrospective post-session logging for users who choose not to risk their hardware in high-heat environments.

### 1.3 Hardware Baseline: Apple Watch Series 7 vs. Ultra / Series 10
* **Owner Baseline**: The owner uses an **Apple Watch Series 7** and has no Android devices.
* **Water Temperature Sensor Availability**:
  * **Supported**: Apple Watch Ultra (all generations), Apple Watch Series 10+. Equipped with a sub-surface water temperature sensor capable of measuring water temp from 32° to 131° F (0° to 55° C) via `CMWaterSubmersionManager` / HealthKit.
  * **Unsupported**: Apple Watch Series 7, 8, 9, SE (Gen 1 & 2), and Ultra running standard non-submersion modes.
  * *Note on Series 8/9 Wrist Temperature*: The wrist temperature sensor in Series 8/9 is designed exclusively for retroactive nocturnal baseline shift tracking during sleep tracking; it does **not** expose a live ambient water or air thermometer API during active workouts.
* **Architectural Constraint**:
  * Manual temperature logging (with preset quick-picks: e.g., 42°F, 48°F, 52°F) must be the primary, authoritative baseline.
  * Sensor-based water temperature reading (DRAFT-17) is an optional progressive enhancement for compatible hardware, never a blocker for core functionality.

### 1.4 Connectivity & Locker Separation
* **Network Dead Zones**: Public spas, wellness bathhouses (e.g., Remedy Place, Othership, Bathhouse), and residential basements often have zero cellular coverage and no guest Wi-Fi.
* **Locker Isolation**: Phones are almost universally stored in lockers or cubbies away from wet deck areas.
* **Architectural Constraint**:
  * Apple Watch app must be 100% standalone: create, transition, complete, and persist sessions locally in Core Data / local storage without requiring active iPhone connectivity.
  * Sessions must reconcile seamlessly via App Group / WatchConnectivity when returning to the locker.

### 1.5 Apple Health (HealthKit) Workout Integration as a Core Differentiator
* **The Core Gap in Current Tools**:
  * The most common workaround for plungers is the built-in Apple Watch **Timer** or **Stopwatch**. While convenient, **Apple Timers do not write workouts to Apple Health**. Users receive:
    * Zero credit toward their Apple Watch **Exercise ring**.
    * Zero calculation of **Active Calories (Active Energy Burned)**.
    * No continuous, high-frequency **Heart Rate sampling** during extreme thermal stress.
    * Zero integration with downstream recovery platforms (Athlytic, Bevel, Whoop via Health import, Gentler Streak, Apple Health Trends).
* **Physiological Reality of Contrast Therapy**:
  * Cold immersion triggers acute sympathetic activation (cold shock response, norepinephrine surge, vasoconstriction, intense shivering thermogenesis).
  * Sauna exposure triggers marked cardiovascular stress equivalent to moderate aerobic exercise (heart rates commonly climb to 120–150 bpm, active peripheral vasodilation, elevated cardiac output).
  * Users want and expect these physiological demands to be captured as valid workout sessions in their health records.
* **HealthKit Implementation Architecture**:
  * **Active Workout Session (`HKWorkoutSession` / `HKLiveWorkoutBuilder`)**:
    * Running an active `HKWorkoutSession` on watchOS keeps the app alive in the foreground/Always-On state and commands watchOS to sample optical heart rate (PPG) continuously (every few seconds) rather than passive background sampling (every 5–10 minutes).
    * Heart rate spikes during cold plunge entry and gradual climbs during sauna rounds are accurately recorded into the HealthKit store.
  * **Activity Type Mapping**:
    * HealthKit does not provide dedicated `.sauna` or `.coldPlunge` enum cases in `HKWorkoutActivityType`.
    * Standard industry mapping:
      * Primary workout: `HKWorkoutActivityType.preparationAndRecovery` (iOS 16+ / watchOS 9+, perfectly semantic for contrast recovery) or `HKWorkoutActivityType.other` / `HKWorkoutActivityType.waterSports`.
      * Multi-segment structure: Either an overarching composite recovery workout with `HKWorkoutEvent` segments for plunge, sauna, and rest intervals, or individual linked sub-workouts.
  * **Custom Metadata Enrichment**:
    * Water temperature logged via `HKMetadataKeyWaterTemperature` (when supported/manually entered).
    * Custom metadata attributes for round counts (`contrast.round_count`), sauna ambient temperature (`contrast.sauna_temp_f`), and protocol template identifier.
  * **Durable Offline HealthKit Export**:
    * Workouts must be queued and saved locally in Core Data first.
    * When the session concludes, the app commits the workout to `HKHealthStore`. If HealthKit authorization is delayed or phone sync is pending, the queue persists until verified, preventing duplicate workouts via deterministic external UUID tracking.

---

## 2. Competitor Workflow Comparison

A competitive audit was conducted on 2026-09-20 comparing dedicated cold plunge/sauna apps against the built-in Apple ecosystem.

### 2.1 Comparison Matrix

| Application | Wet-Screen & Transition Handling | Older Watch Support (Series 7 Baseline) | On-Wrist Sauna Behavior & Thermal Resilience | Apple Health (HealthKit) Workout Sync | Offline & Locker Handling | Pricing & Business Model | Hands-On Observed vs. Advertised Claims |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **[Contrast - Sauna + Cold Plunge](https://apps.apple.com/app/contrast-sauna-cold-plunge/id6444654924)** *(Contrast Labs)* | Simple tap-to-advance. Large buttons, but still requires on-screen touch during wet phases. Audio/haptic alerts at intervals. | Supported. Uses standard timers; does not demand water temp sensor. | Operates on watch, but relies on touch screen. No state recovery if watch restarts mid-sauna. | **Syncs to Apple Health**. Records basic workout minutes. | Standalone Watch app available. Syncs upon phone reconnection. | Free core / $2.99–$4.99 one-time in-app unlock or small tip. | **Claim**: "Effortless routine tracking."<br>**Observed**: Clean minimalist UI, but accidental wet touches or water drops can cancel a running round. |
| **[Ultra Plunge: Recovery Tracker](https://apps.apple.com/app/ultra-plunge-cold-plunge-sauna-log/id6475870020)** *(Ultra Plunge LLC)* | Heavy feature set: AI coach, HR zones. Requires complex on-screen navigation. High friction when wet. | Degraded experience on Series 7: prompts for manual temp while advertising live Ultra sensors. | High CPU/rendering load generates internal heat; users report watch overheating warnings in sauna. | **Syncs to Apple Health**, but locks advanced HR analytics and workout insights behind paywall. | Watch app works offline, but pushes heavy cloud analytics and AI summaries requiring connectivity. | Subscription-heavy: ~$4.99/mo or $39.99/yr with free trial. | **Claim**: "Real-time water temp & AI recovery coach."<br>**Observed**: Cluttered for quick plunge use; prompts for external BLE sauna sensors; poor fit for Series 7. |
| **[ThermoTimer](https://apps.apple.com/app/thermotimer-sauna-cold-plunge/id6450650993)** *(ThermoTimer)* | Preset multi-round protocols (Huberman, Wim Hof style). Countdown chimes with automatic round progression. | Fully functional on Series 7. Treats temperature as a preset or manual tag. | Simple timer UI handles sauna moderately well; lacks crash-recovery if thermal reboot occurs. | **Syncs to HealthKit** if unlocked; writes basic workout session. | Excellent offline behavior. Phone Live Activities keep timers visible from afar. | Freemium: Free 1 protocol; $9.99 one-time lifetime unlock for custom protocols. | **Claim**: "Glanceable timers and Live Activities."<br>**Observed**: Auto-advancing interval timer is significantly superior to manual end-buttons in cold water. |
| **[GoPolar: Cold Plunge & Sauna](https://apps.apple.com/app/gopolar-cold-plunge-sauna/id6446881958)** *(GoPolar Inc)* | Multi-phase logging (Sauna -> Plunge -> Rest). Requires manual button taps on watch to cycle phases. | Works on older watches. Manual temp entry on Series 7. | Watch app requires touch swipes/taps; users complain of sweaty screen non-responsiveness in sauna. | **Syncs to HealthKit**, but gated behind ongoing subscription. | Works offline, caches workouts locally until phone connects. | Subscription: ~$29.99/year or monthly tier. | **Claim**: "All-in-one contrast logging."<br>**Observed**: Strenuous manual phase switching; users complain of sweating on the screen while trying to end a hot round. |
| **Native Apple Workout / Stopwatch** *(Apple Inc)* | Dual-button press (Crown + Side Button) can pause/resume without touch. Water Lock can be engaged. | Preinstalled on all models including Series 7. Native water lock handling. | High hardware resilience; OS native thermal management. | **Stopwatch / Timer: ZERO HealthKit sync** (no rings, no workout). **Workout App**: Records workouts, but lacks contrast protocol structure. | 100% offline, native HealthKit integration, zero sync latency. | Free (Built-in). | **Claim**: General fitness tracking.<br>**Observed**: Stopwatch gives zero HealthKit credit. Workout app has no hot/cold interval switching or temperature tracking. |

### 2.2 Key Workflow Takeaways
1. **Apple Health (HealthKit) Workout Sync is the Primary Switching Trigger**: Cold plunge and sauna enthusiasts abandon the built-in Apple Watch Timer because it gives **zero Exercise ring credit and records no workout data**. Logging a legitimate workout with continuous HR and temperature metadata is the #1 feature users actively seek from dedicated apps.
2. **The Winning Interaction is Hands-Free Auto-Advancement**: The most frustrating UX across all dedicated apps is forcing the user to tap a capacitive "Next Phase" or "End Plunge" button with dripping, shaking, or sweaty hands. Apps that offer **configurable interval countdowns with strong haptic pulses + audio bells** (e.g., 3 min cold -> 30s transition chime -> 15 min sauna) provide a vastly superior experience.
3. **On-Wrist Sauna Wear Requires Durable Crash Recovery**: Users wear their watch in the sauna regardless of warnings. Because thermal shutdowns and reboots can happen, apps that store session state only in RAM drop the user's data. **Durable per-transition disk persistence** solves this real-world failure mode.
4. **Physical Button Fallbacks are Essential**: When manual intervention is required, toggling via the **Digital Crown press or hardware button combinations** must be supported to bypass wet-screen and sweat issues.
5. **Subscriptions Generate Strong User Resentment**: In App Store reviews for Ultra Plunge and GoPolar, the #1 user complaint is aggressive paywalls ($30–$50/yr) for what is essentially an interval stopwatch with HealthKit export. A local-first, free-core model with optional one-time purchase or tip aligns with Solstice's core philosophy.

---

## 3. Owner-Run Interview & Usability Protocol

To validate whether users need a dedicated contrast app versus their existing workarounds, the owner should conduct neutral, non-leading user interviews.

### 3.1 Screener Criteria
* **Target Participants**: Adults who engage in cold plunging, ice baths, cryotherapy, or sauna sessions at least **once per week**.
* **Environments**: Home tub/chest freezer plunge, commercial gym (sauna/cold plunge suite), or dedicated bathhouse/contrast facility.
* **Device Ownership**: Owns an iPhone and ideally an Apple Watch (any model).

### 3.2 Neutral, Non-Leading Interview Guide

#### Phase 1: Grounding in Recent Actual Behavior (Avoid Speculation)
* *"Think back to your last cold plunge or sauna session. Walk me through exactly how you timed or tracked it from the moment you stepped in to when you finished."*
* *"Where was your phone while you were in the water or sauna?"*
* *"What device or tool did you look at to know how long you had been in, or when it was time to get out?"*

#### Phase 2: Apple Health Syncing & Fitness Rings
* *"Do you care about closing your Apple Watch rings or logging workouts for cold plunge or sauna sessions? If so, how do you do it today (e.g. built-in Workout app, Other workout, or not at all)?"*
* *"Do you check your heart rate during or after a session? What do you use that data for, and does it feed into any other apps (like Athlytic, Whoop, or Apple Health Trends)?"*
* *"If you use a simple timer that doesn't record to Apple Health, does that bother you, or is timing all you care about?"*

#### Phase 3: Failure Points, Physical Friction & On-Wrist Sauna Habits
* *"Did you experience any moment where your timer, watch, or phone didn't do what you wanted? What happened?"*
* *"Do you wear your watch in the sauna? If so, have you ever experienced a temperature warning, screen dimming, or unexpected reboot?"*
* *"How did you handle touching or interacting with your device with wet or sweaty hands?"*
* *(If using Apple Watch)*: *"Do you keep Water Lock on? How do you end or pause your session when you're shivering or getting out?"*
* *(If doing Contrast / Hot-Cold Rounds)*: *"How do you keep track of which round you're on, or how long you rest between rounds?"*

#### Phase 4: Current Workarounds & Mental Model
* *"What apps or tools have you tried in the past? Why are you using your current method instead of those?"*
* *"After you finish a session, do you look at the data again? What specific piece of information do you care about, if any?"*
* *"Do you log water temperature? If so, where do you get that number (e.g., built-in chiller thermometer, floating pool thermometer, watch sensor, or guess)?"*

#### Phase 5: Switching Triggers & Value Perception
* *"If your current timing method was completely unavailable tomorrow, what would you use?"*
* *"What is the most annoying thing about tracking your sessions right now that you just tolerate?"*
* *"Have you ever paid for a cold plunge or sauna app? If so, what made you pay? If not, what makes them feel unnecessary?"*

### 3.3 Usability Testing Script (Dry-Run / Simulated Wet & Sweaty Session)
1. **Task 1: Pre-Session Setup**:
   * *Prompt*: "You are about to do 3 rounds of 3 minutes cold plunge and 15 minutes sauna. Set up your session on the app."
   * *Observation*: Does the user understand how to configure rounds without getting lost in complex settings?
2. **Task 2: Mid-Plunge Transition with Wet Hands**:
   * *Prompt*: "Simulate being in freezing water. Your hands are wet and shaking. The cold timer ends early or on time. Advance to the next phase without looking closely at the screen."
   * *Observation*: Can the user advance via haptic cue or single hardware action (Crown press), or do they struggle with on-screen touch targets?
3. **Task 3: Simulated Sauna Heat & Thermal Survival**:
   * *Prompt*: "Simulate being in a hot sauna with sweaty hands. The app auto-advances. Simulate an unexpected app termination (kill app). Reopen the app."
   * *Observation*: Does the app seamlessly recover the running session and preserve completed segments, or is session data lost?
4. **Task 4: Post-Session Review, Temperature Adjustment & HealthKit Verification**:
   * *Prompt*: "You just dried off. You realized your cold plunge chiller was set to 48°F, but the session didn't record it automatically. Log your temperature and verify your Apple Health workout."
   * *Observation*: Is retroactive editing immediate and frictionless? Does the workout show up in Apple Health with correct duration, ring credit, and heart rate samples?"

---

## 4. Tester Profile & Market Reality

### 4.1 Tester Profile Matrix

| Cohort | Context / Facility | Typical Devices | Tracking Habits & Pain Points | Viability for Solstice Testing |
| :--- | :--- | :--- | :--- | :--- |
| **Home Chiller / Tub Plungers** | Dedicated chest freezer or commercial plunge (Plunge, Morozko) in backyard/garage. | iPhone, Apple Watch (Series 7–9, Ultra). | Chiller has built-in temp display; wants a quick timer, streak log, and Apple Health workout credit. Phone is often nearby on a table. | **High** (Directly accessible, predictable environment). |
| **Commercial Gym / Spa Contrast Users** | Life Time, Equinox, Banya, communal bathhouse. | Apple Watch (Series 6–10, SE). Phone in locker. | Phone is locked in locker 50+ yards away. High acoustic noise; steam; wears watch in sauna against recommendations; needs standalone watch app, strong haptics, and durable crash recovery. | **High** (Stresses standalone Watch + haptic + crash recovery capabilities). |
| **Natural Water / Winter Swimmers** | Lakes, ocean, unheated pools. | Apple Watch Ultra, Garmin, Series 7–10. | Extreme wet conditions; gloves/shivering; requires high contrast visibility, large physical triggers, and HealthKit sync. | **Medium** (Seasonal, high hardware demands). |

### 4.2 The Android Demand Reality Check
* **Owner Position**: The owner has zero Android test hardware and uses iOS exclusively.
* **Wear OS & Android Health Ecosystem**:
  * Unlike watchOS, Wear OS does not have a unified ambient water temperature sensor standard across devices.
  * Thermal limits on Samsung Galaxy Watch and Pixel Watch are equally restrictive in saunas.
  * Health Connect integration requires separate data schema mapping and credential maintenance.
* **Audit Assessment**:
  * Claiming "large Android demand" without evidence is contrary to repository guidance.
  * DRAFT-18 (Flutter experiment) must remain **strictly gated** until native iOS contrast adoption proves actual user demand. Building for Android now would double QA and maintenance overhead for zero verified return.

---

## 5. Contrary Evidence & Proceed/Pause Recommendation

### 5.1 Contrary Evidence (Why This Might Not Be Worth Building)
1. **The "Good Enough" Native Workaround**:
   * A huge portion of cold plungers use the built-in Apple Watch **Timer** (set to 3:00) or **Stopwatch**. It launches instantly, has zero subscription, works offline, vibrates strongly on completion, and requires no learning curve.
   * *Counter-Evidence & Moat*: Built-in Timers do not write workouts to Apple Health, do not close Exercise rings, do not record continuous heart rate, and cannot cycle multi-phase contrast routines (plunge -> rest -> sauna -> rest).
2. **Sauna Hardware Reality & Thermal Risks**:
   * Wearing an Apple Watch in a 190°F sauna is officially outside Apple's operating specifications and risks thermal shutdown.
   * *Counter-Evidence & Moat*: Users wear their watches anyway. Instead of ignoring this or banning watch tracking, Solstice Contrast can be the only app built specifically to survive it: **durable per-transition disk persistence** so reboots don't lose data, low-thermal UI, and zero-touch controls.
3. **Manual Entry Fatigue**:
   * Because Series 7 (and the vast majority of consumer Apple Watches) lacks a water temperature sensor, users must type in "48°F" manually every day. In user feedback across fitness apps, daily manual metadata entry has a severe drop-off after 7–14 days.
   * *Mitigation*: Quick preset chips (e.g. 45°, 48°, 52°) that save the user's default chiller temp with one tap.
4. **Subscription Fatigue & Commoditization**:
   * The App Store already has multiple slick timers. Charging a subscription for a plunge timer alienates users, while a free/one-time app produces low revenue unless bundled into a larger suite strategy.

### 5.2 Proceed / Pause Decision & Conditions

#### Recommendation: **PROCEED CONDITIONALLY TO DRAFT-15 (Native Prototype)**

**Conditions for Proceeding**:
1. **Hands-Free Auto-Advancement & Physical Button Fallback**: The prototype must require **zero touchscreen interactions** between the moment a session starts and finishes:
   * Automatic interval transitions (e.g., 3-minute plunge countdown -> distinct haptic sequence + bell -> 60-second rest -> 15-minute sauna).
   * Hardware fallback (single Crown press or dual-button press to pause/skip).
2. **On-Wrist Sauna Resilience + Off-Wrist Fallback**:
   * Support wearing the watch in the sauna with **durable per-transition disk persistence** (so thermal shutdowns/reboots do not lose session data) and an **ultra-low-thermal true-black OLED UI mode**.
   * Provide an off-wrist phone timer / retrospective logger for users who choose not to bring their watch into high heat.
3. **First-Class Apple Health (HealthKit) Integration**:
   * Record completed sessions as valid `HKWorkout` entities (`HKWorkoutActivityType.preparationAndRecovery` or `other`).
   * Stream continuous optical heart rate during exposure via `HKWorkoutSession`.
   * Grant full Apple Watch Exercise and Move ring credit.
   * Attach water temperature (`HKMetadataKeyWaterTemperature`) and custom round metadata.
   * Guarantee durable offline caching so sessions never duplicate or drop in spa dead zones.
4. **Older Watch Baseline (Series 7 Support)**:
   * Keep manual temperature logging (with quick-select presets) as the default; live water temperature sensor integration (DRAFT-17) remains strictly progressive enhancement.
5. **Retain Local-First, Free-Core Simplicity**:
   * No mandatory account creation, zero cloud dependencies, and fast local persistence matching Fasted's Core Data architecture.

---

## 6. Execution Status & Handoff Checklist

- [x] **Competitor comparison completed**: 5 platforms analyzed on wet-screen, older watch, on-wrist sauna, Apple Health sync, offline recovery, routine transitions, and pricing.
- [x] **Store claims distinguished from observed behavior**: Verified through App Store listings and public user experience reports.
- [x] **Hardware constraints & on-wrist sauna realities documented**: Series 7 baseline verified; Apple 32°–95°F thermal limits contrasted with real-world user wear habits; defensive crash-persistence and low-thermal display engineering specified.
- [x] **Apple Health (HealthKit) differentiator detailed**: Ring closure, continuous HR streaming, workout activity type mapping, and offline durability established as the core value proposition over basic timers.
- [x] **Interview & usability testing protocol drafted**: Neutral, non-leading recall questions and failure-point observations defined (including HealthKit and sauna wearing questions).
- [x] **Tester profile & Android demand analyzed**: Android expansion identified as unvalidated; recommended remaining deferred.
- [x] **Contrary evidence & go/no-go recommendation recorded**: Explicit conditions outlined for DRAFT-15 prototype gate.
- [ ] **Human interviews conducted**: *PENDING* (To be performed by repository owner using Section 3 protocol).
- [ ] **Live cold plunge / sauna physical device tests**: *PENDING* (To be performed on physical Apple Watch Series 7 and iPhone).
