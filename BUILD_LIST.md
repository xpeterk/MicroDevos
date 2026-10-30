# Micro Devos — Build List & Feature Backlog

## Active / Queued Items

### 1. Custom Devo Creation Progress & Status Animation
- **Area**: `lib/features/personalize/personalize_run.dart` (`PersonalizeWriting`)
- **Status**: `Queued` (Ready for implementation)
- **Problem**: 
  - When creating a personalized devo, the writing screen currently displays a static circle icon and a hardcoded, frozen progress bar (`value: 0.62`).
  - While waiting for Gemini generation (typically 10–20 seconds), the screen exhibits zero motion, making it appear as if the app is hung or frozen.
- **Proposed Solution**:
  1. **Animated Central Badge**: A smooth breathing pulse and rotating/glowing halo effect on the `auto_awesome` icon so motion is immediately obvious.
  2. **Progressive Status Messages**: Stepped status text that cycles every 3–4 seconds to show intentional activity:
     - *"Reflecting on your prompt & tone..."*
     - *"Finding scripture passages..."*
     - *"Drafting the 3 sections & reflection..."*
     - *"Crafting your closing prayer..."*
  3. **Smooth Animated Progress Bar**: Replace the static `0.62` bar with an indeterminate shimmer or a smoothly interpolating progress animation that paces gracefully toward completion.

---

## Completed Items (v0.1.1)
- [x] **Saved Screen for Personalized Devotions**: Added `mineProvider` integration into `FavoritesScreen` and `devoByIdProvider` so personalized devos display and open properly.
- [x] **Devotion-Level Save Button**: Added heart save button to section header and devotion detail screen for saving whole devotions.
- [x] **Unified Saved View Toggle**: Unified regular devotions, personalized devotions, and saved sections into `SavedItem` so all items switch cleanly between Grid (Cards) and List views.
- [x] **Saved Card & List View Redesign**: Polished Fraunces typography, gradient cards, tag pills, and metadata.
- [x] **1-Tap Unsave**: Interactive red heart icon on every saved item in both Grid and List modes to unsave directly from the home screen.
- [x] **Simplified App Navigation**: Removed the redundant "For You" tab from the bottom navigation bar.
