# Whack A Braille

## Overview

Whack A Braille is an accessibility-first arcade braille and typing game for iPhone and iPad. Players listen for targets, enter the correct character, contraction, or word, and bonk the moles before they escape.

The game is designed for blind players, braille learners, teachers, and anyone who wants a playful way to practice accuracy and speed.

## Supported Input Methods

The app supports five input modes:

1. Standard Keyboard or 8-Dot Braille
2. Perkins Home Row
3. Braille Screen Input
4. Braille Display Input
5. One-Handed Braille Input

The Mole Chooser adapts to the selected input mode. Typing modes appear only for Standard Keyboard, while Grade 2 choices that cannot be entered accurately in a particular braille mode are hidden.

## Gameplay Modes

The Mole Chooser is organized into five groups:

1. Grade 1
   - Letters A-J
   - Letters A-T
   - Letters Only
   - Numbers Only
   - Letters and Numbers
   - Grade 1 Mole Invasion
2. Grade 2
   - Symbol Contractions
   - Whole Word Contractions
   - Short-form Words
   - Suffixes
   - Dot 5 Initials
   - Dots 4 5 Initials
   - Dots 4 5 6 Initials
   - Grade 2 Mole Invasion
3. Mole Battles
   - 3-Letter Words
   - 4-Letter Words
   - Grade 1 Mole Battle
   - Wordy Mole Mayhem
4. Typing
   - Simple Home Row
   - QWERTY Home Row
   - QWERTY Home Row + Top Row
   - QWERTY Home Row + Bottom Row
5. Custom
   - Custom Moles

Grade 1 Mole Battles present several letter-bearing moles at once. Wordy Mole Mayhem presents one word-bearing mole and accepts accurate text, uncontracted Perkins braille, or contracted Perkins braille.

## Training and Mole Recon

Every gameplay family supports untimed Training.

After a round, Mole Recon collects missed and escaped targets. Recon can replay the complete set, while Grudge Match lets the player select particular targets for another training round. Word-mode Recon preserves whole words rather than reducing them to individual letters.

## Accessibility

Key accessibility behaviors include:

1. VoiceOver support throughout the main game flow
2. Native controls and semantic headings
3. Source-order-based VoiceOver navigation without traversal overrides
4. Focus restoration after sheets, pickers, purchases, and changing word targets
5. Dynamic Type support across major screens
6. Input-mode-specific instructions and Mole Chooser filtering
7. A focusable current-word element above buffered braille entry
8. Stereo and spatial mole audio with a mono-compatible center

## Audio

The app provides Original, Silly, Goofy, and Retro sound modes. Grade 1 Mole Battles use spatially distributed letter hits and one multi-mole completion sound. Buffered braille modes use one completion sound rather than replaying every letter hit at submission.

Round scheduling reserves time for completion audio before the next target is announced. Headphone testing remains necessary because a successful build cannot establish perceived balance, stereo placement, or freedom from static.

## Word Catalogs

Battle and Mayhem words come only from the English word list in the WordBop iOS project. Android word-list sources are not part of this workflow.

Wordy Mole Mayhem generation also applies the checked-in common-word allowlist and exact family-safety exclusions:

1. `scripts/wordy-mole-mayhem-common-en.txt`
2. `scripts/wordy-mole-mayhem-excluded-en.txt`
3. `scripts/generate-wordy-mole-mayhem-catalog.sh`

The generator expects the WordBop iOS repository as a sibling checkout by default:

```bash
./scripts/generate-wordy-mole-mayhem-catalog.sh
```

An explicit iOS source path may be supplied as the first argument:

```bash
./scripts/generate-wordy-mole-mayhem-catalog.sh '/path/to/wordBop-iOS/WordBop/WordBop/words-en.txt'
```

Generation uses Liblouis only as a development-time tool to produce the checked-in UEB data. The app does not use Liblouis at runtime.

## Automated Testing

The shared Xcode scheme includes the `Whack A BrailleTests` unit-test target. It checks:

1. Battle and Mayhem catalog structure
2. Common-word and family-safety filtering
3. Coverage across supported word lengths
4. Battle stereo positions
5. Contracted and uncontracted Mayhem Perkins input
6. Mole Chooser grouping and input-dependent visibility
7. Legacy mode-name migration
8. Mode-specific Round Results terminology

Run the tests with:

```bash
xcodebuild -project 'Whack A Braille.xcodeproj' -scheme 'Whack A Braille' -destination 'platform=iOS Simulator,name=iPhone 16' test
```

The provenance test uses the sibling WordBop iOS checkout. Set `WORDBOP_IOS_WORDLIST_PATH` when the source is stored elsewhere. If the separate iOS checkout is unavailable, that external provenance assertion is skipped while all self-contained tests still run.

## Prize System

Tickets are saved locally and can be spent from the Home screen or after a round. The prize system includes persistent tickets, randomized prize counters, tier-based fanfares, a shared prize catalog, duplicate ownership counts, claim dates, and prize detail sheets.

The web prize catalog remains the shared source of truth:

1. `/Users/pallas/Documents/marconius.com/fun/whackABraille/scripts/prizeCatalog.js`
2. `Whack A Braille/GameCore/PrizeCatalog.swift`

Update the shared web catalog first, then run the project’s prize synchronization flow.

## Project Structure

1. `Whack A Braille/Game/`
   App screens and view models
2. `Whack A Braille/GameCore/`
   Gameplay models, catalogs, registry data, and scoring
3. `Whack A Braille/Input/`
   Keyboard and braille input bridges
4. `Whack A Braille/Audio/`
   Generated sound effects, fanfares, and round audio
5. `Whack A Braille/Speech/`
   Speech configuration and playback
6. `Whack A BrailleTests/`
   Xcode unit tests
7. `scripts/`
   Catalog generation and project support scripts

## Build Notes

The project targets iOS 17.0 and later.

```bash
xcodebuild -project 'Whack A Braille.xcodeproj' -scheme 'Whack A Braille' -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## Physical-Device Release Checklist

Before shipping, verify on physical iPhone or iPad hardware:

1. VoiceOver remains on the current word when a focused Mayhem target escapes and changes.
2. Players can move from the current word back into Braille Screen Input, Braille Display Input, and One-Handed Braille Input.
3. Perkins accepts both contracted and uncontracted Mayhem submissions.
4. Standard Keyboard and 8-Dot entry produce one result for each character.
5. Buffered input produces one completion hit rather than an overlapping series of letter hits.
6. Keyboard and Perkins retain individual Battle hits followed by one completion sound.
7. Every sound mode is balanced with speech using headphones.
8. Stereo and spatial audio work both enabled and disabled.
9. Round start and generated sounds remain free of static.
10. Completion audio finishes before the next target is spoken.
11. Training, Mole Recon, and Grudge Match work for both word-mode families.
12. A human sample of every supported Mayhem word length remains recognizable and family-friendly.
13. StoreKit support products load and complete correctly.
14. VoiceOver focus remains correct on Home, How to Play, Round Results, Cash In, and Prize Shelf.

Prefer untethered device launches for final accessibility and audio validation. Build and simulator success are not substitutes for physical VoiceOver, braille hardware, audio, or StoreKit testing.
