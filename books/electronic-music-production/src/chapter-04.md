# Chapter 4: Music Theory: The Minimum Viable Version

Music theory has a reputation problem. It gets taught like math class: abstract rules disconnected from the sounds they describe. Producers hear "learn theory" and picture dusty textbooks about counterpoint and figured bass. Then they either avoid it entirely or try to learn everything at once and retain nothing.

The truth: you need about 10% of formal music theory to write electronic music effectively. This chapter covers that 10%. It is not comprehensive. It deliberately leaves out things you do not need yet. What it gives you is enough harmonic and melodic vocabulary to write chord progressions, bass lines, and melodies that work -- and enough understanding to know why they work, so you can break the rules intentionally rather than accidentally.

Do not try to absorb this chapter in one sitting. Read it through once, do the exercises, then come back to specific sections when you are working on a track and need a particular tool.

---

## Notes and the Piano Roll

Open a MIDI track in Ableton and load any instrument (Drift, Analog, even a simple piano from the browser). Double-click a clip slot to create a MIDI clip. You are looking at the piano roll: a grid where the vertical axis is pitch and the horizontal axis is time. The keyboard on the left shows you note names.

There are 12 unique notes in Western music, repeating across octaves: C, C#, D, D#, E, F, F#, G, G#, A, A#, B. Then it starts over at C again. The distance between any two adjacent notes is called a **half step** (or semitone). Two half steps make a **whole step** (or tone). That is it. Every scale, chord, and melody is built from combinations of these 12 notes.

In the piano roll, half steps are adjacent rows. Whole steps skip one row. If you click on C3 and then the note directly above it, that is C#3, one half step. Skip C#3 and click D3, and you have moved a whole step from C.

The **chromatic scale** is all 12 notes played in sequence. It sounds like a siren. No character, no emotion, just raw pitch material. Scales carve subsets from these 12 notes to create specific moods.

---

## Major and Minor Scales

A scale is a recipe: a specific pattern of whole steps (W) and half steps (H) that selects 7 notes from the 12 available.

**Major scale pattern:** W-W-H-W-W-W-H

Start on C and follow the pattern: C (W) D (W) E (H) F (W) G (W) A (W) B (H) C. That is C major. No sharps or flats. In the piano roll, these are all the white keys.

**Minor scale pattern (natural minor):** W-H-W-W-H-W-W

Start on A: A (W) B (H) C (W) D (W) E (H) F (W) G (W) A. That is A natural minor. Also no sharps or flats. Same notes as C major, but starting on A. This is not a coincidence. Every major scale has a **relative minor** that shares the same notes but starts on the 6th degree. C major and A minor are relatives.

You do not need to memorize all 12 major and 12 minor scales right now. You need to understand the pattern and know how to apply it. Ableton helps with this.

**Ableton's Scale Mode.** In the MIDI clip editor, click the "Scale" button (or press the Scale toggle in the clip's toolbar). A dropdown lets you choose a root note and scale type. When Scale mode is active, the piano roll highlights only the notes in your chosen scale, and the "Fold" button can collapse the piano roll to show only scale tones. This means you literally cannot play a wrong note.

Set it to C minor (C, Eb, F, G, Ab, Bb, the sadder, more tension-filled sibling of C major). With Fold enabled, your piano roll becomes a 7-row grid. This is incredibly freeing when you are starting out. Use it without shame. Professional producers use Scale mode constantly.

---

## Chords: Triads and Sevenths

A chord is three or more notes played simultaneously. The most basic chord is a **triad**, three notes stacked in thirds.

To build a triad, pick a root note from your scale, skip one scale note, add the next, skip one more, add the next. In C minor:

- Start on C, skip D, add Eb, skip F, add G. That is **C minor** (Cm): C-Eb-G.
- Start on D, skip Eb, add F, skip G, add Ab. That is **D diminished** (Ddim): D-F-Ab.
- Start on Eb, skip F, add G, skip Ab, add Bb. That is **Eb major** (Eb): Eb-G-Bb.

Each scale degree produces a chord with a specific quality. In any minor key, the pattern is:

| Degree | Numeral | Quality |
|--------|---------|---------|
| 1 | i | minor |
| 2 | ii-dim | diminished |
| 3 | III | major |
| 4 | iv | minor |
| 5 | v (or V) | minor (or major) |
| 6 | VI | major |
| 7 | VII | major |

Lowercase numerals = minor chords. Uppercase = major. This is the harmonic palette of every minor key. You can build progressions by picking from this table.

**Seventh chords** add one more third on top of the triad. In C minor, a Cm7 chord is C-Eb-G-Bb. The extra note adds richness and sophistication. Seventh chords are everywhere in R&B, jazz-influenced house, lo-fi, and anything that wants to sound "smooth." In the piano roll, just stack one more scale tone above your triad.

Program each of these chords as whole notes in a MIDI clip. Listen to each one. Notice how the minor chords sound darker and the major chords sound brighter. The diminished chord (ii) sounds tense and unstable -- it wants to resolve somewhere. These qualities are the raw material of harmony.

---

## Three Starter Progressions

You could spend years studying chord progressions. Start with three.

**Progression 1: I-V-vi-IV (Major key)**

In C major: C - G - Am - F. This is the most common progression in pop music. It sounds triumphant, uplifting, slightly nostalgic. Hundreds of hits use it. In the piano roll, program 4 bars of whole-note chords: C-E-G, then G-B-D, then A-C-E, then F-A-C.

**Progression 2: i-VI-III-VII (Minor key)**

In A minor: Am - F - C - G. This is the minor-key cousin of Progression 1, and it is everywhere in EDM, trance, and melodic techno. It has an epic, expansive quality. Program it: A-C-E, then F-A-C, then C-E-G, then G-B-D. Notice these are the same four chords as Progression 1, just starting from a different point. This is the relative major/minor relationship in action.

**Progression 3: i-iv-i-iv (Minor key, two-chord vamp)**

In A minor: Am - Dm - Am - Dm. Two chords, back and forth. This sounds simple, and it is. But simplicity is power in electronic music. Deep house, minimal techno, and many Daft Punk tracks use two-chord vamps. The limited harmony keeps the listener locked into the groove rather than following a harmonic narrative. Program it: A-C-E, then D-F-A, and loop.

These three progressions will cover 80% of the harmonic situations you encounter as a beginning producer. Master them before chasing more complex harmony.

---

## Inversions and Voice Leading

Play your i-VI-III-VII progression and listen to the bass note jump around. A-C-E leaps up to F-A-C, then down to C-E-G, then up to G-B-D. The chord changes sound abrupt because the notes are moving large distances between chords.

**Inversions** fix this. An inversion rearranges the notes of a chord so that a different note is on the bottom. C-E-G is "root position." E-G-C is "first inversion." G-C-E is "second inversion." Same chord, same harmonic function, different voicing.

The principle of **voice leading** is: move each note to the nearest available note in the next chord. Instead of leaping, the notes step smoothly.

Try this in A minor. Start with Am root position: A3-C4-E4. For the next chord (F major), instead of jumping to F3-A3-C4, use first inversion: A3-C4-F4. Only one note moved (E4 to F4), and it only moved one half step. Then for C major: G3-C4-E4 (second inversion). Then G major: G3-B3-D4.

Play both versions back to back -- the block chord version with big jumps, then the voice-led version with smooth motion. The difference is dramatic. The voice-led version sounds professional and cohesive. The block chord version sounds like a MIDI demo.

Good voice leading is the single fastest way to make your chord progressions sound polished. The rule is simple: when moving between chords, keep common tones in place and move other notes by the smallest possible interval.

---

## Intervals and Melody

A melody is a sequence of single notes over time. Writing melodies is harder than writing chords because they need to be memorable, singable, and rhythmically interesting simultaneously. But there are starting principles.

**Intervals** are the distances between notes. Each interval has a character:

- **Minor 2nd (1 semitone):** Tense, dissonant. Think horror movie.
- **Major 2nd (2 semitones):** Stepping motion. Neutral, smooth.
- **Minor 3rd (3 semitones):** Sad, sweet. The sound of a minor chord.
- **Major 3rd (4 semitones):** Bright, happy.
- **Perfect 4th (5 semitones):** Open, strong. "Here Comes the Bride."
- **Perfect 5th (7 semitones):** Powerful, hollow. Power chords.
- **Octave (12 semitones):** Same note, different register. Expansive.

Melodies in electronic music tend to use small intervals (2nds and 3rds) for most of their movement, with occasional larger leaps (4ths, 5ths, octaves) for emphasis. A melody that only steps is boring. A melody that only leaps is exhausting. Mix them.

**Chord tones vs. scale tones.** Notes that belong to the current chord (chord tones) sound stable and resolved. Notes that are in the scale but not in the chord (passing tones) create tension that wants to resolve to a chord tone. A melody that only uses chord tones sounds like an arpeggio. A melody that uses passing tones and resolves them sounds intentional and expressive.

Try this: over your i-iv-i-iv progression in A minor, write a melody using only chord tones first (A, C, E over Am; D, F, A over Dm). Then add passing tones between them (B between A and C, E between D and F). Hear how the passing tones add color and movement.

---

## Bass Line Writing

A bass line is not just the root note of each chord played on every beat. That is a starting point, but it is a boring one. Bass lines in electronic music are rhythmic and melodic instruments.

**Beyond root notes.** Instead of playing A for four beats over Am, try: A on beat 1, E on the "and" of 2, A on beat 3, C on the "and" of 3. You are still outlining the Am chord, but the rhythm and the use of the 5th (E) and minor 3rd (C) make it melodically interesting.

**Passing tones.** Walk between chord roots using scale tones. Going from Am to Dm? Instead of A then D, try A-B-C-D over two beats. This creates a smooth bass line that connects the harmony.

**Octave jumps.** One of the most effective bass techniques in electronic music. Play A2 on beat 1, A3 on beat 2 (same note, one octave higher), then back to A2. This creates energy and bounce without adding harmonic complexity. Octave bass lines are fundamental to house, disco, and synth-pop.

**Syncopation.** Place bass notes on upbeats or between beats. An eighth note before beat 1 (anticipating the chord change) creates forward momentum. A bass note on the "and" of 2 interlocks with a kick on beat 2. Syncopated bass against a straight kick is one of the most reliable groove generators in dance music.

Program a bass line over your i-iv-i-iv progression that uses all four techniques: root notes as anchors, a passing tone walk between Am and Dm, an octave jump in bar 2, and syncopation in bar 4. You will hear the difference immediately compared to a "root note on beat 1" approach.

---

## MIDI Effects as Theory Tools

Ableton includes MIDI effects that automate aspects of music theory. These are not cheats. They are tools that let you explore harmonic ideas faster than you can think them through manually.

**Scale** (MIDI Effects > Scale). This forces any MIDI input to the nearest note in a chosen scale. Put it before your instrument on a MIDI track. Set it to A minor. Now you can mash random keys and everything will be in key. This is excellent for improvisation. Record yourself playing freely, then edit the results.

**Chord** (MIDI Effects > Chord). This adds intervals above every note you play. Set Shift 1 to +3 semitones and Shift 2 to +7 semitones, and every single note becomes a minor triad. Set them to +4 and +7 for major triads. Now you can play chords with one finger. Combine with the Scale device to guarantee every chord is diatonic.

**Arpeggiator** (MIDI Effects > Arpeggiator). Hold a chord and the Arpeggiator plays its notes one at a time in sequence. Set the rate to 1/8 or 1/16, choose an order (Up, Down, Up-Down, Random), and a static chord becomes a moving pattern. This is how many classic synth lines are created. Try holding a Cm7 chord (C-Eb-G-Bb) with the Arpeggiator set to 1/16 Up-Down at your track's tempo.

**Random** (MIDI Effects > Random). This adds a random pitch offset to incoming notes. Set the Range to a small value (2-4 semitones) and place a Scale device after it to quantize the randomness to your key. The result is generative melody -- let the machine surprise you, then edit what it produces.

Chain these effects. A powerful setup: Scale (set to your key) > Chord (adding a 5th and octave) > Arpeggiator (1/16 Up-Down). Hold a single note and you get a full arpeggiated pattern that is harmonically correct. This is a legitimate production technique, not a shortcut.

---

## Where Books Fall Short on Theory

Most music theory resources teach you the concepts but never connect them to production decisions. They will explain what a Dorian mode is but not tell you that Dorian is the go-to scale for deep house because its raised 6th degree creates a bittersweet quality that sits between major and minor. They will define a suspended chord but not tell you that a sus2 pad with long reverb is a reliable way to create atmosphere in ambient breakdowns.

Theory is only useful when it becomes intuitive -- when you hear a chord in your head and your fingers know where to put it. That translation happens through practice, not reading. Every time you learn a concept in this chapter, immediately program it into a MIDI clip and listen. Your ears learn faster than your brain.

The other gap in traditional theory education is rhythm. Theory books treat rhythm as an afterthought -- time signatures and note values, as if rhythm is just about counting. In electronic music, rhythm is inseparable from harmony. A chord that changes on beat 1 feels completely different from the same chord arriving on the "and" of 4. The syncopation of your bass line is a harmonic choice as much as a rhythmic one. As you learn theory, always think about when notes happen, not just which notes they are.

---

## Pacing Yourself

This chapter covered a lot. A realistic timeline for internalizing it:

**Week 1:** Learn the C minor scale. Program it ascending and descending. Build triads on each degree. Listen to each one. Use Scale mode constantly.

**Week 2:** Program the three starter progressions. Apply inversions and voice leading. Write a simple melody over each one using mostly chord tones.

**Week 3:** Write bass lines. Practice root notes, then passing tones, then octave jumps. Make the bass rhythmically interesting.

**Week 4:** Experiment with MIDI effects. Build arpeggiator chains. Try the Random device. Improvise and edit.

**Ongoing:** Every time you start a new track, pick a key and a progression from this chapter. Use Scale mode. Write chords, bass, and melody. Over time, you will start hearing these patterns without needing to count intervals. That is when theory becomes a creative tool rather than a set of rules.

Do not wait until you have "mastered" theory to start making tracks. You will never master it -- even professional composers are still learning. Use what you know now, learn more as you need it, and let your ears guide you when the rules run out.

---

## What You Should Have Now

After working through this chapter, you should have:

1. The ability to build major and minor scales in the piano roll.
2. Three chord progressions you can deploy in any key.
3. An understanding of inversions and why voice leading matters.
4. A bass line that does more than play root notes.
5. Familiarity with Ableton's MIDI effects as creative tools.
6. Realistic expectations about how long theory takes to internalize.

Next, we are going to open up the synthesizer and learn how sound is actually made.
