# BeatGo

Bygg house-loops i mobilen, exportera MIDI rakt in i Ableton.

Flutter-app, Android först (Honor Magic V5), iOS senare från samma kod.

## Status

**Steg 1 – ljudmotor och sequencer-grid.** Appen öppnar med ett demo-groove
(F# moll, 124 BPM, 2 takter) och inbyggda placeholder-ljud. Syftet är att
känna om timing och latens håller på telefonen innan vi bygger vidare.

Planerade steg:

1. ✅ Ljudmotor (flutter_soloud) + sequencer-UI efter designreferensen
2. ✅ Sample-browser: Download/Splice, Music och egna mappar, förhandslyssning
3. ✅ Piano roll för melodispår, tonartsskärm med ackordknappar → Chords-kanal
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

- Trumrader: tryck = slag på/av, dra = måla flera, håll = accent/normal/mjuk.
- Melodirader (pianoikon): tryck öppnar piano roll-editorn. Där: tryck =
  lägg ton (vald längd), tryck på markerad ton = ta bort, dra = flytta,
  dra högerkanten = längd, pil upp/ner = tonhöjd i skalan, velocity-slider.
- "Takt 1 / Takt 2 / Alla" väljer vad översikten visar; på en smal skärm
  visas en takt i taget så cellerna går att träffa.
- Tryck på spårnamnet för att byta ljud, välja trumma/melodisk, sätta
  grundton, volym, tysta, rensa, ta bort.
- "Lägg till spår → Från telefonen…" bläddrar i Download/Splice, Music
  och mappar du lagt till. Tryck på en rad för att lyssna, Välj för att använda.
- BPM, swing och tonart i headern är klickbara.
- Swing visas MPC-style: 50 % = rakt, 58 % = typisk house.

## Designreferens

`design/refs/` – grid-estetiken: nästan svart bakgrund, en limegrön accent,
pills vars bredd är notlängd, vit playhead.
