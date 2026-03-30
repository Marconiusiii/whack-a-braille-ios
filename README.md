# Whack A Braille

## Overview

Whack A Braille is an accessible arcade-style braille typing game for iPhone and iPad. Players listen for moles, enter the matching braille character, symbol, number, or contraction, and whack the current mole before it ducks away.

The game is designed for blind players, braille learners, teachers, and anyone who wants a playful way to practice braille speed and confidence.

## Supported Input Methods

The app supports three main input styles:

1. Standard Keyboard or 8-Dot Braille
2. Perkins Home Row
3. Braille Screen Input

The available mole sets adapt to the selected input mode so the game only offers modes that make sense for that input method.

## Current Gameplay Features

The current iOS build includes:

1. Grade 1 letter, number, and symbol practice
2. Grade 2 whole-word contraction and word-sign modes
3. Grade 1 Mole Invasion and Grade 2 Mole Invasion
4. Training mode
5. Adjustable difficulty and round length
6. Timer music, speech controls, and system voice selection
7. Cash In prize flow with persistent saved tickets
8. Prize Shelf with individual deletion and prize detail sheets

## Accessibility Notes

This project is accessibility-first.

Key accessibility behaviors include:

1. VoiceOver support across the main game flow
2. Native SwiftUI controls where possible
3. Accessible focus return for modal screens such as How to Play and Prize details
4. VoiceOver Z-scrub escape support on supported sheets
5. Dynamic type support across the major custom screens
6. Input-mode-specific filtering so unsupported mole sets are not surfaced for Braille Screen Input or Perkins modes

## Prize System

Tickets are saved locally on device and can be spent later from the Home screen or after a round.

The prize system currently includes:

1. persistent total tickets
2. randomized prize counter choices based on the player’s available tickets
3. tier-based prize fanfares
4. a shared prize catalog source of truth with flavor text
5. prize detail sheets showing:
   1. prize name
   2. latest claim date
   3. tier and ticket cost
   4. flavor text
   5. total owned for duplicates

## Project Structure

Important project areas:

1. `Whack A Braille/Game/`
   Main app screens and view models
2. `Whack A Braille/GameCore/`
   Core gameplay types, registry data, and prize catalog
3. `Whack A Braille/Audio/`
   Generated sound effects, fanfares, and round audio
4. `Whack A Braille/Speech/`
   Central speech engine configuration and playback
5. `scripts/`
   Project support scripts, including prize catalog syncing

## Shared Prize Data

Prize data is intentionally kept in sync with the web version of the game.

The web prize catalog is the shared source of truth:

1. `/Users/pallas/Documents/marconius.com/fun/whackABraille/scripts/prizeCatalog.js`

The iOS project syncs that source into:

1. `Whack A Braille/GameCore/PrizeCatalog.swift`

If new prizes or prize flavor text are added, update the shared web catalog first and then rerun the sync flow for the iOS app.

## Build Notes

This project is built with Xcode and currently targets iOS 17.0 and later.

A typical device build command is:

```bash
xcodebuild -project 'Whack A Braille.xcodeproj' -scheme 'Whack A Braille' -destination 'platform=iOS,id=DEVICE_ID' build
```

For real accessibility validation, prefer untethered on-device testing over debugger-attached launches when possible. VoiceOver behavior can differ slightly when the app is launched directly from Xcode.

## Release Prep Notes

Before archiving or shipping a build, it is worth checking:

1. first cold-launch round startup
2. VoiceOver focus on Home, How to Play, Results, Cash In, and Prize Shelf
3. Braille Screen Input, braille display, and external keyboard behavior
4. Cash In and prize claiming flow
5. app icon and App Store metadata

## Development Priority

When making changes to this app:

1. do not regress accessible workflows
2. avoid sight-centric assumptions
3. keep input-mode behavior accurate to the selected braille entry method
4. preserve parity with the web prize catalog wherever possible
