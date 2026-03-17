# Chapter 5: Sound Design Fundamentals: The Signal Path

Every sound you hear from a synthesizer -- every bass, every pad, every screaming lead -- follows the same path. Once you understand that path, synthesis stops being mysterious. You stop scrolling through presets hoping to stumble on something usable. Instead, you hear a sound in your head and know how to build it.

This chapter teaches you the universal signal path that underlies every synthesizer ever made, from a 1960s Moog to Ableton's Wavetable. Then we will work through four synthesis methods in the order you should learn them, with hands-on exercises for each. By the end, you will have built four sounds from scratch and understood why each decision shaped the result.

---

## The Universal Signal Path

Every synthesizer, regardless of type, follows this chain:

**Oscillator -> Filter -> Amplifier -> Effects**

That is it. Four stages. Everything else is modulation of those four stages. Let's take them one at a time.

**Oscillator.** This generates the raw waveform, the fundamental tone. Think of it as the raw ingredient. Common waveforms: sine (pure, no harmonics), saw (bright, buzzy, rich in harmonics), square (hollow, clarinet-like, odd harmonics only), triangle (mellow, like a quiet saw). The oscillator determines the harmonic content you start with. You can always remove harmonics later with a filter. You cannot add what is not there (unless you use distortion or FM, which we will get to).

**Filter.** This sculpts the raw sound by removing frequencies. A **low-pass filter** (the most common type) lets everything below a cutoff frequency through and attenuates everything above it. Turn the cutoff down on a saw wave and it goes from bright and buzzy to dark and muffled. A **high-pass filter** does the opposite -- removes low frequencies. **Band-pass** lets through only a narrow band. **Resonance** boosts frequencies right at the cutoff point, creating a sharp peak that gives the filter its own character. High resonance on a low-pass filter creates that classic acid squelch.

**Amplifier.** This controls the volume of the sound over time. Without an amplifier envelope, the sound would be a constant drone. The amplifier shapes whether the sound is a short pluck, a sustained pad, or something that fades in slowly. This is where ADSR envelopes live (more on those in a moment).

**Effects.** Reverb, delay, chorus, distortion, EQ. Anything that processes the sound after the core synthesis. Effects are not part of synthesis per se, but they are inseparable from sound design. A dry pluck becomes a shimmering pad with enough reverb. A clean bass becomes a growling monster with distortion.

Open Ableton's **Analog** synthesizer (Instruments > Analog). You can see this signal path laid out visually: two oscillators on the left, two filters in the middle, two amplifiers, and a global section with effects. Every parameter maps to one of the four stages. This is true for every synth you will ever use.

---

## ADSR Envelopes

An envelope is a shape that changes a parameter over time, triggered by a note. ADSR stands for:

- **Attack:** How long it takes to reach full level after a note starts. 0ms = instant. 500ms = slow fade in.
- **Decay:** How long it takes to drop from the peak to the sustain level.
- **Sustain:** The level the sound holds at while you keep the note pressed. This is a level, not a time.
- **Release:** How long the sound takes to fade out after you let go of the note.

These four parameters shape the character of a sound more than almost anything else.

**Fast attack, short decay, no sustain, short release:** A pluck. The sound hits immediately, drops quickly, and is gone. Think pizzicato strings or a marimba. In Analog, set Amp Envelope Attack to 0ms, Decay to 200ms, Sustain to 0, Release to 100ms.

**Fast attack, no decay, full sustain, medium release:** An organ. The sound is on when you hold the key and off when you release, with a brief tail. Attack 0ms, Decay 0ms, Sustain 100%, Release 200ms.

**Slow attack, no decay, full sustain, long release:** A pad. The sound fades in slowly, sustains as long as you hold, and fades out gently. Attack 800ms-2s, Decay 0ms, Sustain 100%, Release 1-3s.

**Fast attack, medium decay, medium sustain, short release:** A bass. Punchy transient that settles into a sustained tone. Attack 0ms, Decay 300ms, Sustain 60%, Release 50ms.

Envelopes are not just for volume. You can route an envelope to the filter cutoff, and the filter will open and close over the life of each note. This is how you create sounds that start bright and get darker (high initial cutoff, envelope with fast decay closing the filter down). Route an envelope to pitch and you get sounds that swoop from one pitch to another. Every modulatable parameter can have its own envelope.

---

## LFOs: Low Frequency Oscillators

An LFO is an oscillator that runs too slowly to hear. Instead of generating audio, it generates a repeating shape (sine, triangle, saw, square, random) that modulates other parameters.

**LFO routed to filter cutoff = wobble.** The filter opens and closes rhythmically. This is the foundation of dubstep bass. Set an LFO to a sine wave at 1/4 note rate, route it to the filter cutoff with moderate depth, and your sound pulses in time with the music.

**LFO routed to volume = tremolo.** The volume rises and falls rhythmically. A sine LFO at 4-6Hz creates a classic tremolo effect. Faster rates create a choppy, rhythmic effect.

**LFO routed to pitch = vibrato.** A sine LFO at 5-7Hz with very small depth (a few cents of pitch variation) creates vibrato, the natural wavering of pitch that makes sounds feel alive. Larger depth creates a siren effect. Route an LFO to pitch with a slow rate and you get sci-fi sound effects.

The key LFO parameters are:

- **Rate:** How fast the LFO cycles. Can be free (measured in Hz) or synced to tempo (1/4, 1/8, 1/16 notes).
- **Shape:** Sine (smooth), triangle (smooth with sharper peaks), saw (ramp up then drop), square (on/off), sample & hold/random (stepped random values).
- **Depth/Amount:** How much the LFO affects the target parameter. Start small and increase until you hear the effect you want.
- **Phase:** Where in the cycle the LFO starts. Useful when syncing multiple LFOs.

In Analog, click on the LFO section. You can route it to Oscillator pitch, Filter cutoff, or Amplifier volume using the destination selector. Try each one with a sine LFO at different rates to hear the difference.

---

## Learning Synthesis in Order

There are many synthesis methods. Learn them in this order. Each one builds on concepts from the previous.

### 1. Subtractive Synthesis (Analog / Drift)

This is the oldest and most intuitive method. Start with a harmonically rich waveform (saw or square), then subtract harmonics with a filter. Everything we have discussed so far (oscillator, filter, ADSR, LFO) is the subtractive workflow.

**Ableton's Analog** models a classic analog polysynth. **Drift** is a newer, simpler instrument with a similar signal path and a built-in character that mimics analog hardware imperfections.

Open Analog. Click "Init" or find an initialized patch (no modulation, all defaults). You should hear a simple saw wave. Now:

1. Set the filter type to Low Pass 24dB (steeper = more dramatic filtering).
2. Turn the cutoff down to about 40%. The sound gets darker.
3. Increase resonance to 50%. You hear a peak at the cutoff frequency.
4. Route the filter envelope: set Filter Envelope amount positive, attack 0, decay 500ms, sustain 30%, release 200ms. Now the filter opens on each note and closes during the decay. The sound has shape and movement.

This is the core of subtractive synthesis. Everything else is variation on this process.

### 2. Wavetable Synthesis (Wavetable)

Wavetable synthesis uses a table of waveforms that you can sweep through, creating sounds that evolve over time in ways subtractive synthesis cannot.

Open **Wavetable** (Instruments > Wavetable). You will see a large waveform display. The key concept is the **wavetable position**, a knob that scrolls through different waveforms stored in a table. At position 0 you might have a sine wave. At position 50, something complex and metallic. At position 100, a noisy, gritty texture.

The power is in sweeping through the table over time. Route an LFO or envelope to the wavetable position and the timbre evolves continuously. This is how you create sounds that morph, breathe, and shift. Pads that slowly change character, leads that evolve across a phrase.

Try this: load a wavetable with varied shapes (try the "Algorithm" or "Distortion" category). Set an LFO to modulate the wavetable position at a slow rate (1/2 or 1 bar). Add a low-pass filter with moderate cutoff. You have a sound that is constantly in motion, impossible to achieve with a static saw wave.

Wavetable also has two oscillators that you can blend, a sub oscillator, and a sophisticated modulation matrix. But start with one oscillator and one LFO modulating the position. Get comfortable with that before adding complexity.

### 3. FM Synthesis (Operator)

FM (Frequency Modulation) synthesis uses one oscillator's output to modulate the frequency of another oscillator. This creates complex harmonic spectra from simple waveforms: metallic bells, glassy pads, crunchy basses, and sounds that are difficult or impossible to achieve with subtractive synthesis.

Open **Operator** (Instruments > Operator). It has four oscillators (called operators, labeled A through D). The key concept is **algorithms**, diagrams that show which operators modulate which. Click the algorithm display at the bottom to cycle through them.

In the simplest algorithm, Operator B modulates Operator A. A is the "carrier" (you hear it). B is the "modulator" (you do not hear it directly, but it shapes A's tone). The frequency ratio between them determines the harmonic content. A 1:1 ratio creates subtle harmonic enrichment. A 1:2 ratio creates even harmonics. Odd ratios and non-integer ratios create increasingly metallic, inharmonic, and bell-like tones.

Try this: set Algorithm to the one where B feeds into A (the simplest carrier-modulator setup). Set both oscillators to sine waves. Play a note -- it sounds like a pure sine. Now slowly increase Oscillator B's level (its output). The sound becomes increasingly complex and bright. At high levels it becomes harsh and metallic. This is FM synthesis in action -- you are generating harmonics through modulation rather than starting with a harmonically rich wave.

FM synthesis has a reputation for being difficult, and it is less intuitive than subtractive. But you do not need to understand the math. You need to understand that: modulator output level = brightness/complexity, frequency ratio = harmonic character, and the envelope on the modulator shapes how the brightness changes over the note's lifetime. A modulator with a fast decay creates a bright attack that fades to a pure tone -- the classic electric piano or bell sound.

### 4. Sampling (Simpler / Sampler)

Sampling is not synthesis in the traditional sense. You start with a recorded sound rather than a generated waveform. But the signal path is the same: source (the sample) -> filter -> amplifier -> effects.

**Simpler** (Instruments > Simpler) is Ableton's streamlined sampler. Drag any audio file onto it. You can play the sample across the keyboard (it pitches up and down), loop a section, and apply the full filter/envelope/LFO chain.

The most powerful mode is **Slice mode.** Drop a drum loop or melodic phrase into Simpler, switch to Slice mode, and Ableton automatically chops the sample into segments and maps each slice to a MIDI note. Now you can rearrange, skip, and shuffle the slices to create new patterns from existing material. This is the foundation of sample-based production: jungle, hip-hop, and a large portion of electronic music.

**Sampler** is the full-featured version with multi-sample support, zones, and deeper modulation. You do not need it yet. Start with Simpler.

Try this: find a vocal sample in Ableton's library. Drag it into Simpler in Classic mode. Set the filter to low-pass, cutoff around 60%, resonance 40%. Set a long attack (1s) and long release (2s) on the amp envelope. Play sustained chords with this instrument. You have turned a vocal snippet into a pad. This is the essence of sampling as sound design -- recontextualizing sounds by processing them beyond recognition.

---

## Practice Exercise: Four Sounds From an Initialized Patch

Open Analog and initialize it (right-click the title bar and select "Init Preset" or find an init patch). Build each of these sounds from scratch. Save each one as a preset (right-click the title bar > "Save Preset").

**1. Bass.** Oscillator 1: saw wave. Oscillator 2: saw wave, detuned -7 cents (creates width). Filter: low-pass 24dB, cutoff at 35%, resonance 20%. Filter envelope: amount positive, attack 0, decay 250ms, sustain 20%, release 50ms. Amp envelope: attack 0, decay 0, sustain 100%, release 50ms. The result: a punchy, rounded bass with a percussive filter pop on each note.

**2. Pluck.** Oscillator 1: square wave. Filter: low-pass 12dB, cutoff at 70%, resonance 40%. Filter envelope: amount positive, attack 0, decay 150ms, sustain 0, release 100ms. Amp envelope: attack 0, decay 300ms, sustain 0, release 100ms. Add a short reverb (Reverb device after Analog, decay 1.2s, dry/wet 25%). The result: a short, woody pluck that sits well over a pad.

**3. Pad.** Oscillator 1: saw wave. Oscillator 2: saw wave, detuned +9 cents, one octave lower. Filter: low-pass 12dB, cutoff at 50%, resonance 15%. LFO: sine, rate 0.3Hz, routed to filter cutoff, depth 20%. Amp envelope: attack 1.5s, decay 0, sustain 100%, release 2s. Add chorus (Chorus-Ensemble device, rate slow, depth moderate) and reverb (decay 3s, dry/wet 40%). The result: a warm, evolving pad with slow movement.

**4. Lead.** Oscillator 1: saw wave. Oscillator 2: square wave, same pitch. Filter: low-pass 24dB, cutoff at 65%, resonance 55%. Filter envelope: amount positive, attack 0, decay 400ms, sustain 40%, release 200ms. LFO: triangle, rate 5.5Hz, routed to pitch, depth very small (2-3 cents). Amp envelope: attack 5ms, decay 0, sustain 100%, release 150ms. The slight pitch LFO adds vibrato. The result: a thick, slightly nasal lead that cuts through a mix.

After building all four, play them together. You have a complete instrument palette built from one synthesizer with four different configurations of the same signal path. This is the power of understanding the architecture. You did not need four different instruments or four different presets. You needed to understand oscillator, filter, amplifier, and modulation.

---

## Case Study: Boards of Canada -- "Roygbiv"

> "Roygbiv" (1998, *Music Has the Right to Children*) is a track built almost entirely from simple subtractive synthesis, processed to sound like it was recorded to a degraded cassette tape in 1978.
>
> The main melody is a detuned saw lead -- two saw oscillators slightly detuned from each other, creating a chorus-like width. The filter is set relatively open (the sound is bright), but there is a gentle filter envelope that gives each note a subtle attack shape. The vibrato is the defining characteristic: an LFO modulating pitch at a slow rate (around 3-4Hz) with enough depth to be clearly audible. This is not subtle vibrato -- it is exaggerated, wobbly, deliberately imperfect. It sounds like a VHS tape struggling to maintain pitch. That imperfection is the entire aesthetic.
>
> The bass is a simple sine or triangle wave with almost no filtering -- just a low oscillator with a short amp envelope. It does not need complexity because the melody carries all the harmonic interest. The bass provides a warm, round foundation.
>
> The drums are sampled and processed through what sounds like tape saturation and bit reduction. They are lo-fi not because the original samples were low quality, but because they were deliberately degraded. You can achieve this in Ableton with Redux (Bit Depth to 10-12, Downsample to 8-15) followed by Saturator (set to a warm curve with moderate drive).
>
> The lo-fi quality of the entire track comes from several layers of degradation. There is a gentle high-frequency roll-off (low-pass filter around 8-10kHz on the master or bus) that removes digital clarity. There is subtle pitch instability on everything, as if the whole track is on warped vinyl. There is also noise: tape hiss as a deliberate textural element, not an artifact to be removed.
>
> The lesson from "Roygbiv" is that sound design is not about complexity. The synthesis is elementary: saw waves, basic filtering, LFO vibrato. The artistry is in the processing decisions. Boards of Canada chose to make their sounds imperfect, and that imperfection became their signature. In your own work, consider what you are adding to your sounds versus what you are degrading. Sometimes the most powerful sound design is about making things worse in the right way.
>
> To approximate the "Roygbiv" lead: initialize Analog, select two saw oscillators detuned by 8-12 cents, set the filter to low-pass 12dB with cutoff around 75%, add an LFO routed to oscillator pitch at 3Hz with noticeable depth (5-8 cents of pitch wobble), then run the output through Redux (Bit Depth 12, Downsample 5) and a gentle low-pass EQ rolling off above 9kHz. Add a small room reverb. Play a simple, nostalgic melody in a major key. You will be in the neighborhood.

---

## The Synthesis Learning Path

Do not try to master all four synthesis methods simultaneously. Follow this sequence:

**Month 1: Subtractive only.** Use Analog or Drift exclusively. Build every sound from an initialized patch. Get fluent with the signal path, ADSR envelopes, and LFO routing. You should be able to create a bass, pad, pluck, and lead from scratch without thinking about it.

**Month 2: Add wavetable.** Start using Wavetable alongside your subtractive work. Focus on what wavetable can do that subtractive cannot: evolving timbres, morphing textures, sounds that change character over time.

**Month 3: Experiment with FM.** Open Operator and explore carrier-modulator relationships. Focus on bell sounds, metallic textures, and electric piano tones. FM excels at sounds in the "glassy to metallic" spectrum.

**Month 4: Integrate sampling.** Use Simpler to incorporate real-world sounds into your palette. Slice loops, process vocals into pads, layer samples with synthesized sounds.

This timeline is approximate. The goal is not speed but fluency. You want each method to feel natural before adding the next. A producer who deeply understands subtractive synthesis will make better music than one who superficially knows five methods.

---

## Common Sound Design Mistakes

**Starting from complex presets and tweaking.** This teaches you nothing about why a sound works. Always start from init patches when learning. Use presets for inspiration, not as starting points.

**Too many oscillators.** Two oscillators slightly detuned give you width. Three or four start competing and create a mushy, undefined sound. Start with one. Add a second only if you need detuning, a sub layer, or a different waveform blend.

**Forgetting the amp envelope.** Many beginners focus on filter and oscillator but leave the amp envelope at its default. The amp envelope is the most important shaping tool. It determines whether your sound is a pluck, a pad, or a bass. Set it first.

**Over-processing.** Three reverbs, two delays, chorus, and distortion on a single sound is not sound design. It is noise. Apply one effect at a time, listen to what it adds, and stop when the sound is right. The best sounds are often the simplest.

---

## What You Should Have Now

After this chapter, you should have:

1. A clear mental model of the Oscillator -> Filter -> Amplifier -> Effects signal path.
2. Understanding of ADSR envelopes and how attack/decay/sustain/release shape a sound's character.
3. Experience routing LFOs to filter, volume, and pitch.
4. Four sounds built from scratch in Analog (bass, pluck, pad, lead), saved as presets.
5. Familiarity with Wavetable, Operator, and Simpler at a foundational level.
6. A realistic learning timeline for deepening your synthesis knowledge.

Next, we are going to develop the most underrated skill in production: learning how to listen.
