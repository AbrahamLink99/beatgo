# BeatGo

Bygg house-loops i mobilen, exportera MIDI rakt in i Ableton.

Flutter-app, Android först (Honor Magic V5), iOS senare från samma kod.

## Status

**Steg 1 – ljudmotor och sequencer-grid.** Appen öppnar med ett demo-groove
(F# moll, 124 BPM, 2 takter) och inbyggda placeholder-ljud. Syftet är att
känna om timing och latens håller på telefonen innan vi bygger vidare.

Planerade steg:

1. ✅ Ljudmotor (flutter_soloud) + sequencer-UI efter designreferensen
2. Sample-browser: Download/Splice och egen synkad mapp, förhandslyssning
3. Melodispår med riktig piano roll, ackordrad per takt
4. Export: MIDI + manifest.json (+ använda wavs) via dela-menyn
5. PC-script som bygger en `.als` av exporten
6. Arrangemang (drop / breakdown / build) och automation

## Få en APK

Varje push till `main` bygger en APK och publicerar den som release
**latest**. Direktlänk från telefonen:

https://github.com/AbrahamLink99/beatgo/releases/latest/download/beatgo.apk

Tillåt installation från okänd källa när Android frågar.

## Bygga lokalt

```
flutter pub get
flutter run
```

Placeholder-ljuden genereras med `python3 tools/gen_samples.py`.

## Hur appen används

- Tryck i en rad för att lägga/ta bort ett slag.
- Håll inne på ett slag: trummor växlar accent/normal/mjuk, melodispår
  stegar tonen uppåt i skalan.
- Tryck på spårnamnet för volym, tysta, rensa, ta bort.
- BPM, swing och tonart i headern är klickbara.
- Swing visas MPC-style: 50 % = rakt, 58 % = typisk house.

## Designreferens

`design/refs/` – grid-estetiken: nästan svart bakgrund, en limegrön accent,
pills vars bredd är notlängd, vit playhead.
