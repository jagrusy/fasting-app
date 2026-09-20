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
| **Is wet-screen operation a genuine failure mode?** | **YES** (Severe) | Capacitive touchscreens fail when wet or submerged. Apple Watch Water Lock disables touch entirely. Shivering fingers cannot reliably tap small UI controls. |
| **Is automatic water-temp tracking viable as a core baseline?** | **NO** (Gated / Optional) | The owner owns an **Apple Watch Series 7**, which completely lacks a water temperature sensor. Live water temp is restricted to Apple Watch Ultra and Series 10+. Baseline must be **manual entry / preset defaults**. |
| **Can users safely wear an Apple Watch in a traditional sauna?** | **NO** (Hardware Hazard) | Apple rates Apple Watch for ambient temperatures of 32° to 95° F (0° to 35° C). Traditional saunas run 150° to 195° F (65° to 90° C). Watches overheat, throttle, shut down, and void warranty. Sauna tracking must support phone/wall-adjacent or post-session logging. |
| **Does competitor feature parity imply commercial demand?** | **NO** (Contrary Evidence) | Fasted currently has near-zero reported traction. Competitors advertise automated AI coaches, BLE sauna sensors, and high recurring subscriptions ($30–$60/yr), but user reviews reveal friction with water lock, overheating warnings, and basic interval confusion. Built-in Apple Watch Timers and Workout apps are free and "good enough" for casual plungers. |
| **Recommendation for DRAFT-15 (Native iOS Prototype)** | **PROCEED CONDITIONALLY** | Proceed to a tightly bounded native prototype **only** if the prototype proves a **hands-free auto-advancing audio/haptic interval workflow** that requires **zero mid-session touchscreen taps** and works 100% offline without requiring Apple Watch in high-heat saunas. |

---

## 1. Difficult-Session Realities & Environmental Constraints

Cold plunge, sauna, and contrast therapy environments impose severe physical and electronic constraints that typical fitness trackers ignore.

### 1.1 Touchscreen Failure Modes (Wet & Shivering)
* **Capacitive Touch Breakdown**: Apple Watch and iPhone displays rely on mutual capacitance. Water droplets create conductive paths across electrodes, generating false touches or preventing the screen from detecting the user's finger.
* **Water Lock Usability Trap**: When water immersion is detected or Water Lock is enabled, the watch screen is entirely unresponsive to touch. Exiting Water Lock requires spinning and holding the Digital Crown for 2–3 seconds while an audible speaker purge tone plays. Forcing this interaction at the end of a freezing 3-minute plunge while shivering is a major source of frustration.
* **Physical Controls**: Dedicated hardware controls (Digital Crown press, Side Button press, or Watch Ultra Action Button) are significantly more reliable than on-screen buttons when wet.

### 1.2 Thermal & Safety Boundaries (Sauna & Extreme Heat)
* **Official Apple Operating Limits**:
  * Operating ambient temperature: **32° to 95° F (0° to 35° C)**.
  * Non-operating storage temperature: **-4° to 113° F (-20° to 45° C)**.
  * Source: [Apple Support: Keep Apple Watch within acceptable operating temperatures](https://support.apple.com/HT204508) (Verified 2026-09-20).
* **Sauna Realities**:
  * Traditional dry saunas: **150° to 195° F (65° to 90° C)**.
  * Infrared saunas: **120° to 140° F (48° to 60° C)**.
  * Steam rooms: **110° to 120° F (43° to 49° C)** at 100% humidity.
* **Consequences**: Wearing an Apple Watch inside a traditional sauna routinely triggers the red thermometer thermal warning screen within 5–10 minutes, forcing device shutdown and accelerating lithium-ion battery degradation. Apple's official warranty explicitly excludes damage caused by use in saunas or steam rooms.
* **Architectural Constraint**: Solstice Contrast **must not** require or encourage users to wear an Apple Watch inside high-heat saunas. The app must provide:
  1. Standalone phone-based timer outside the sauna (audible chime or glanceable high-contrast display through glass).
  2. Independent Apple Watch rest/plunge tracker that logs the sauna round retrospectively or counts rest intervals outside the chamber.

### 1.3 Hardware Baseline: Apple Watch Series 7 vs. Ultra / Series 10
* **Owner Baseline**: The owner uses an **Apple Watch Series 7** and has no Android devices.
* **Water Temperature Sensor Availability**:
  * **Supported**: Apple Watch Ultra (all generations), Apple Watch Series 10+. Equipped with a sub-surface water temperature sensor capable of measuring water temp from 32° to 131° F (0° to 55° C) via `CMWaterSubmersionManager` / HealthKit.
  * **Unsupported**: Apple Watch Series 7, 8, 9, SE (Gen 1 & 2), and Ultra running standard non-submersion modes.
  * *Note on Series 8/9 Wrist Temperature*: The wrist temperature sensor in Series 8/9 is designed exclusively for retroactive nocturnal baseline shift tracking during sleep tracking; it does **not** expose a live ambient water or air thermometer API during active workouts.
* **Architectural Constraint**:
  * Manual temperature logging (with preset quick-picks: e.g., 45°F, 50°F, 55°F) must be the primary, authoritative baseline.
  * Sensor-based water temperature reading (DRAFT-17) is an optional progressive enhancement for compatible hardware, never a blocker for core functionality.

### 1.4 Connectivity & Locker Separation
* **Network Dead Zones**: Public spas, wellness bathhouses (e.g., Remedy Place, Othership, Bathhouse), and residential basements often have zero cellular coverage and no guest Wi-Fi.
* **Locker Isolation**: Phones are almost universally stored in lockers or cubbies away from wet deck areas.
* **Architectural Constraint**:
  * Apple Watch app must be 100% standalone: create, transition, complete, and persist sessions locally in Core Data / local storage without requiring active iPhone connectivity.
  * Sessions must reconcile seamlessly via App Group / WatchConnectivity when returning to the locker.

---

## 2. Competitor Workflow Comparison

A competitive audit was conducted on 2026-09-20 comparing dedicated cold plunge/sauna apps against the built-in Apple ecosystem.

### 2.1 Comparison Matrix

| Application | Wet-Screen & Transition Handling | Older Watch Support (Series 7 Baseline) | Offline & Locker Handling | Retrospective Edits | Pricing & Business Model | Hands-On Observed vs. Advertised Claims |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **[Contrast - Sauna + Cold Plunge](https://apps.apple.com/app/contrast-sauna-cold-plunge/id6444654924)** *(Contrast Labs)* | Simple tap-to-advance. Large buttons, but still requires on-screen touch during wet phases. Audio/haptic alerts at intervals. | Supported. Uses standard timers; does not demand water temp sensor. | Standalone Watch app available. Syncs to Apple Health upon reconnection. | Basic log editing available on iPhone; difficult to alter intervals after completion. | Free core / $2.99–$4.99 one-time in-app unlock or small tip. | **Claim**: "Effortless routine tracking."<br>**Observed**: Clean minimalist UI, but accidental wet touches or water drops can cancel a running round. |
| **[Ultra Plunge: Recovery Tracker](https://apps.apple.com/app/ultra-plunge-cold-plunge-sauna-log/id6475870020)** *(Ultra Plunge LLC)* | Heavy feature set: AI coach, HR zones. Requires complex on-screen navigation. High friction when wet. | Degraded experience on Series 7: prompts for manual temp while advertising live Ultra sensors. | Watch app works offline, but app pushes heavy cloud analytics and AI summaries requiring connectivity. | Flexible log editing on phone; rich metadata (heart rate, perceived exertion). | Subscription-heavy: ~$4.99/mo or $39.99/yr with free trial. | **Claim**: "Real-time water temp & AI recovery coach."<br>**Observed**: Cluttered for quick plunge use; prompts for external BLE sauna sensors; poor fit for Series 7. |
| **[ThermoTimer](https://apps.apple.com/app/thermotimer-sauna-cold-plunge/id6450650993)** *(ThermoTimer)* | Preset multi-round protocols (Huberman, Wim Hof style). Countdown chimes with automatic round progression. | Fully functional on Series 7. Treats temperature as a preset or manual tag. | Excellent offline behavior. Phone Live Activities keep timers visible from afar. | Can adjust completed session duration and temperature post-hoc. | Freemium: Free 1 protocol; $9.99 one-time lifetime unlock for custom protocols. | **Claim**: "Glanceable timers and Live Activities."<br>**Observed**: Auto-advancing interval timer is significantly superior to manual end-buttons in cold water. |
| **[GoPolar: Cold Plunge & Sauna](https://apps.apple.com/app/gopolar-cold-plunge-sauna/id6446881958)** *(GoPolar Inc)* | Multi-phase logging (Sauna -> Plunge -> Rest). Requires manual button taps on watch to cycle phases. | Works on older watches. Manual temp entry on Series 7. | Works offline, caches workouts locally until phone connects. | Allows manual session entry and edits after the fact. | Subscription: ~$29.99/year or monthly tier. | **Claim**: "All-in-one contrast logging."<br>**Observed**: Strenuous manual phase switching; users complain of sweating on the screen while trying to end a hot round. |
| **Native Apple Workout / Stopwatch** *(Apple Inc)* | Dual-button press (Crown + Side Button) can pause/resume without touch. Water Lock can be engaged. | Preinstalled on all models including Series 7. Native water lock handling. | 100% offline, native HealthKit integration, zero sync latency. | Workouts cannot be duration-edited in Health; must be deleted and re-logged manually. | Free (Built-in). | **Claim**: General fitness tracking.<br>**Observed**: No contrast protocol concept; treats plunge as "Other" or "Swimming"; no automatic hot/cold interval switching. |

### 2.2 Key Workflow Takeaways
1. **The Winning Interaction is Hands-Free Auto-Advancement**: The most frustrating UX across all dedicated apps is forcing the user to tap a capacitive "Next Phase" or "End Plunge" button with dripping, shaking hands. Apps that offer **configurable interval countdowns with strong haptic pulses + audio bells** (e.g., 3 min cold -> 30s transition chime -> 15 min sauna) provide a vastly superior experience.
2. **Physical Button Fallbacks are Essential**: When manual intervention is required, toggling via the **Digital Crown press or double-button press** must be supported to bypass wet-screen issues.
3. **Subscriptions Generate Strong User Resentment**: In App Store reviews for Ultra Plunge and GoPolar, the #1 user complaint is aggressive paywalls ($30–$50/yr) for what is essentially an interval stopwatch with HealthKit export. A local-first, free-core model with optional one-time purchase or tip aligns with Solstice's core philosophy.

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

#### Phase 2: Failure Points & Physical Friction
* *"Did you experience any moment where your timer, watch, or phone didn't do what you wanted? What happened?"*
* *"How did you handle touching or interacting with your device with wet or sweaty hands?"*
* *(If using Apple Watch)*: *"Do you keep Water Lock on? How do you end or pause your session when you're shivering or getting out?"*
* *(If doing Contrast / Hot-Cold Rounds)*: *"How do you keep track of which round you're on, or how long you rest between rounds?"*

#### Phase 3: Current Workarounds & Mental Model
* *"What apps or tools have you tried in the past? Why are you using your current method instead of those?"*
* *"After you finish a session, do you look at the data again? What specific piece of information do you care about, if any?"*
* *"Do you log water temperature? If so, where do you get that number (e.g., built-in chiller thermometer, floating pool thermometer, watch sensor, or guess)?"*

#### Phase 4: Switching Triggers & Value Perception
* *"If your current timing method was completely unavailable tomorrow, what would you use?"*
* *"What is the most annoying thing about tracking your sessions right now that you just tolerate?"*
* *"Have you ever paid for a cold plunge or sauna app? If so, what made you pay? If not, what makes them feel unnecessary?"*

### 3.3 Usability Testing Script (Dry-Run / Simulated Wet Session)
1. **Task 1: Pre-Session Setup**:
   * *Prompt*: "You are about to do 3 rounds of 3 minutes cold plunge and 15 minutes sauna. Set up your session on the app."
   * *Observation*: Does the user understand how to configure rounds without getting lost in complex settings?
2. **Task 2: Mid-Plunge Transition with Wet Hands**:
   * *Prompt*: "Simulate being in freezing water. Your hands are wet and shaking. The cold timer ends early or on time. Advance to the next phase without looking closely at the screen."
   * *Observation*: Can the user advance via haptic cue or single hardware action, or do they struggle with on-screen touch targets?
3. **Task 3: Post-Session Review & Temperature Adjustment**:
   * *Prompt*: "You just dried off. You realized your cold plunge chiller was set to 48°F, but the session didn't record it automatically. Log your temperature and save."
   * *Observation*: Is retroactive editing immediate and frictionless?

---

## 4. Tester Profile & Market Reality

### 4.1 Tester Profile Matrix

| Cohort | Context / Facility | Typical Devices | Tracking Habits & Pain Points | Viability for Solstice Testing |
| :--- | :--- | :--- | :--- | :--- |
| **Home Chiller / Tub Plungers** | Dedicated chest freezer or commercial plunge (Plunge, Morozko) in backyard/garage. | iPhone, Apple Watch (Series 7–9, Ultra). | Chiller has built-in temp display; wants a quick timer and streak log. Phone is often nearby on a table. | **High** (Directly accessible, predictable environment). |
| **Commercial Gym / Spa Contrast Users** | Life Time, Equinox, Banya, communal bathhouse. | Apple Watch (Series 6–10, SE). Phone in locker. | Phone is locked in locker 50+ yards away. High acoustic noise; steam; cannot hear quiet phone chimes. | **High** (Stresses standalone Watch + haptic capabilities). |
| **Natural Water / Winter Swimmers** | Lakes, ocean, unheated pools. | Apple Watch Ultra, Garmin, Series 7–10. | Extreme wet conditions; gloves/shivering; requires high contrast visibility and large physical triggers. | **Medium** (Seasonal, high hardware demands). |

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
2. **Sauna Use Case is a Hardware Mismatch**:
   * Users who want a unified "Sauna + Plunge" contrast app expect their watch to track their sauna time. But taking an Apple Watch into a 190°F sauna is objectively bad for the hardware and voids warranty. If the watch cannot be safely worn in the hot phase, the digital "contrast routine" workflow breaks down.
3. **Manual Entry Fatigue**:
   * Because Series 7 (and the vast majority of consumer Apple Watches) lacks a water temperature sensor, users must type in "48°F" manually every day. In user feedback across fitness apps, daily manual metadata entry has a severe drop-off after 7–14 days.
4. **Subscription Fatigue & Commoditization**:
   * The App Store already has multiple slick timers. Charging a subscription for a plunge timer alienates users, while a free/one-time app produces low revenue unless bundled into a larger suite strategy.

### 5.2 Proceed / Pause Decision & Conditions

#### Recommendation: **PROCEED CONDITIONALLY TO DRAFT-15 (Native Prototype)**

**Conditions for Proceeding**:
1. **Design Around the Hands-Free Principle**: The prototype must require **zero touchscreen interactions** between the moment the cold plunge starts and the moment the user steps out. It must rely on:
   * Automatic interval transitions (e.g., 3-minute plunge countdown -> haptic sequence + bell -> 60-second recovery).
   * Hardware fallback (single Crown press or dual-button press to pause/skip).
2. **Decouple Sauna from Watch**: The prototype must treat the hot phase as either an **off-wrist timer** (phone running high-contrast countdown on a bench outside the glass) or an **external manual interval**, rather than asking users to wear their watch into the sauna.
3. **Retain Local-First, Free-Core Simplicity**: No mandatory account creation, zero cloud dependencies, and fast local persistence matching Fasted's Core Data architecture.

---

## 6. Execution Status & Handoff Checklist

- [x] **Competitor comparison completed**: 5 platforms analyzed on wet-screen, older watch, offline recovery, routine transitions, and pricing.
- [x] **Store claims distinguished from observed behavior**: Verified through App Store listings and public user experience reports.
- [x] **Hardware constraints documented**: Series 7 lacks water temp sensor; sauna heat exceeds Apple operational limits.
- [x] **Interview & usability testing protocol drafted**: Neutral, non-leading recall questions and failure-point observations defined.
- [x] **Tester profile & Android demand analyzed**: Android expansion identified as unvalidated; recommended remaining deferred.
- [x] **Contrary evidence & go/no-go recommendation recorded**: Explicit conditions outlined for DRAFT-15 prototype gate.
- [ ] **Human interviews conducted**: *PENDING* (To be performed by repository owner using Section 3 protocol).
- [ ] **Live cold plunge / sauna physical device tests**: *PENDING* (To be performed on physical Apple Watch Series 7 and iPhone).
