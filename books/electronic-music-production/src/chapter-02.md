# Chapter 2: Your First Instruments: Drum Rack and Drift

In the last chapter, you used Drum Rack and Drift to make a loop. You loaded presets, played notes, and recorded clips. That was about getting sound out of the speakers as fast as possible. Now we slow down and actually learn these instruments -- not by reading about them, but by building sounds with them from scratch.

By the end of this chapter, you will understand how Drum Rack works at the pad level and how to shape each drum sound independently. You will understand Drift's architecture well enough to create bass, pluck, pad, and lead sounds starting from an initialized patch. And you will understand all of this because you turned the knobs yourself and heard what happened, not because I told you what they do in the abstract.

---

## Drum Rack: Your Drum Machine

Drum Rack is Ableton's sample-based drum instrument. It looks like a grid of 16 pads (you can scroll to see more), and each pad holds a sound. When you trigger a pad via MIDI, it plays that sound. Simple concept, deep instrument.

Load a Drum Rack onto a new MIDI track. Use any preset kit for now -- "Kit-606 Core" is a good one because the sounds are clean and unprocessed, which makes it easier to hear what you are doing when you start shaping them.

### Understanding the Pad Layout

Click on any pad in the Drum Rack. Look at the bottom of the device. You will see the chain list and the devices loaded on that pad. Each pad is essentially its own little instrument chain. It holds a Simpler instrument (Ableton's basic sampler) loaded with a drum sample, and optionally some audio effects after it.

The pads are laid out chromatically -- each pad corresponds to a MIDI note. The standard mapping puts kick drums on C1, snares and claps around D1-E1, hi-hats around F#1-G#1, and so on. But this mapping is just convention. You can put any sound on any pad.

### Swapping Samples

This is where Drum Rack becomes your instrument rather than a preset. Click on a pad. In the Simpler device that appears below, you can see the sample waveform. To swap this sample for a different one, go to the Browser, navigate to Samples > Drums, and drag a new sample directly onto the pad. The old sample is replaced.

Do this now. Find a kick drum you like better than the one loaded. Then swap out the snare. Then the hi-hats. Within a few minutes, you have a custom kit assembled from pieces you chose. This is how most electronic producers build drum kits -- they do not use full presets. They build kits pad by pad from sounds they like.

A practical workflow: open the Browser to Samples > Drums > Kick. Click on samples to preview them (make sure the Preview button -- the small headphone icon at the bottom of the Browser -- is enabled). When you find one you like, drag it to a pad. Move on to snares. Then hi-hats. Then look through percussion, claps, toms, whatever catches your ear. Build a kit of 8-12 sounds. This is your palette for this session.

### Basic Processing Per Pad

Each pad in Drum Rack can have its own effects chain. This is powerful. You can EQ, compress, saturate, and shape each drum sound independently before it reaches the main mix.

Click on a kick drum pad. In the chain at the bottom, you see the Simpler. To the right of it, you can drag in audio effects. Let us add some processing to the kick.

From the Browser, go to Audio Effects > EQ Eight. Drag it onto the chain after the Simpler on your kick pad. EQ Eight opens. For now, just know that you can use it to boost or cut certain frequencies of the kick. Click on the low-frequency band (the leftmost point on the EQ curve) and drag it up slightly. The low end gets louder. Drag it down. The low end gets quieter. You are shaping the kick's tone without affecting any other sound in the kit.

Now try adding a Saturator after the EQ. Find it in Audio Effects > Saturator. Saturator adds harmonic distortion -- it makes things sound grittier, warmer, or more aggressive depending on how hard you push it. Turn up the Drive knob. Hear how the kick changes character. Subtle amounts add warmth. Heavy amounts add aggression. Find a setting you like.

This per-pad processing is one of Drum Rack's greatest strengths. Each drum sound gets its own treatment. Compress the snare to make it punchier without compressing the hi-hats. Saturate the kick without saturating anything else. We will go much deeper into effects processing in later chapters. For now, just know that the capability exists and experiment with adding one or two effects to individual pads.

### Layering Sounds

You can stack multiple samples on a single pad. Click on the Show/Hide Chains List button (the small icon on the left side of the Drum Rack that looks like three horizontal lines). This reveals the chain list for the selected pad. You can drag additional samples onto the same pad to layer them.

This is how producers create thick, complex drum sounds. A kick drum might be two samples layered -- one with a strong transient click and one with a deep sub-bass body. A snare might be a crisp snare sample layered with a clap for width.

Try it: find two kick drum samples. Load one on a pad. Then drag the second one onto the same pad's chain list. Play the pad. You hear both samples at once. Adjust the volume of each layer in the chain list to blend them. This is basic drum layering, and it is how professionals build drums that sound full and unique.

---

## Building a Kick Pattern

Before we move to Drift, let us make a complete drum pattern using what you just learned. This is not just a technical exercise; it is practice in making musical decisions.

Create a 2-bar MIDI clip on your Drum Rack track. Switch to Draw Mode (press B) so you can click to place notes.

Start with the kick. Place kicks on beat 1 of each bar. Listen. Now add kicks on beat 3. You have the most basic four-on-the-floor pattern. For a straighter feel, add kicks on every beat -- 1, 2, 3, 4. For something with more bounce, try beats 1, the "and" of 2, and 3.

Add snare or clap on beats 2 and 4. This is the backbeat and it is the rhythmic anchor of most Western popular music, including most electronic genres. Play your pattern. It should already sound like something.

Add hi-hats. Eighth notes (every half-beat) give you a driving, energetic feel. Sixteenth notes (every quarter of a beat) give you a busier, more detailed texture. Place some hi-hats and listen. If it feels too busy, remove some. If it feels too sparse, add some.

Now the important part: adjust the velocity of your hi-hat notes. Select hi-hat notes in the piano roll and look at the velocity lane at the bottom of the clip view. Drag individual velocity bars up and down. Alternate between loud and soft hi-hats. This creates a human feel and a sense of groove that perfectly uniform velocities cannot achieve. Try making every other hi-hat quieter. Or make the ones on the beats louder and the ones between beats softer. Listen to how this changes the feel of the pattern without changing the notes themselves.

Velocity is the difference between a drum pattern that sounds programmed and one that sounds musical. Spend time with it.

---

## Drift: A Subtractive Synth You Can Actually Understand

Drift is the synth I wish I had when I started producing. It has the core elements of subtractive synthesis -- oscillators, a filter, envelopes, and an LFO -- without the complexity of more full-featured synths. Everything is on a single panel. There are no hidden menus. If you understand Drift, you understand the fundamentals of synthesis that apply to virtually every synthesizer ever made.

Load Drift onto a new MIDI track. Now, critically, do not load a preset. We want the default initialized sound. If you loaded a preset from the Browser, click the "Hot-Swap Presets" button (the small icon next to the preset name at the top of the device) and look for something labeled "Init" or "Default." Alternatively, right-click the Drift title bar and look for an option to initialize the device, or simply drag a fresh Drift from the Instruments section of the Browser (not from a preset subfolder -- drag the instrument itself).

You should hear a plain, boring tone when you play a note. Good. That is our starting point.

### Oscillators: The Raw Material

The oscillator section is on the left side of Drift. This is where the raw sound is generated. Drift has two oscillators.

**Oscillator 1** has a waveform selector. You will see options for different waveshapes. Click through them and play a note after each change:

- **Sine** -- a pure, smooth tone. No harmonics. Good for sub-bass.
- **Triangle** -- slightly brighter than a sine. A bit more character but still smooth.
- **Sawtooth** -- bright and buzzy, full of harmonics. The workhorse of subtractive synthesis. If you want a big, rich sound that you carve with a filter, start with a saw wave.
- **Square/Pulse** -- hollow-sounding, like a clarinet. The pulse width parameter changes its character dramatically.

The oscillator also has an octave control and fine-tuning. Try shifting the octave down. Play a note. That is now a bass register. Shift it up. That is a lead register. The same waveshape sounds completely different depending on the octave because the harmonic content interacts differently with our perception at different pitch ranges.

If you turn on the second oscillator and detune it slightly from the first (a few cents using the fine-tune control), you get a thicker, chorused sound. Two slightly detuned sawtooth waves is one of the most fundamental sounds in electronic music. Try it now.

### The Filter: Sculpting the Sound

The filter is the centerpiece of subtractive synthesis. The entire paradigm is: start with a harmonically rich waveform (like a sawtooth), then subtract frequencies with a filter to shape the sound you want. Hence the name.

Drift's filter section is in the middle of the interface. The two most important controls are **Cutoff** and **Resonance**.

**Cutoff** (often labeled Frequency or Freq) determines which frequencies pass through the filter. With a low-pass filter (the default and most common type), turning the cutoff down removes high frequencies. The sound gets darker and more muffled. Turning it up lets more high frequencies through, making the sound brighter.

Play a sustained note with a sawtooth oscillator. Now slowly turn the cutoff knob down. Listen to the brightness disappear. Turn it back up. This single gesture, sweeping a filter cutoff, is one of the most recognizable sounds in electronic music. Every filter sweep in every dance track is doing exactly this.

**Resonance** boosts the frequencies right around the cutoff point. At low settings, it is subtle. At medium settings, it gives the filter a nasal, vocal quality. At high settings, it creates a sharp, whistling peak. Turn up the resonance and sweep the cutoff again. Hear how the sweep now has a pronounced, singing quality. That is resonance.

Drift also lets you choose filter types. Low-pass is the default and the most broadly useful. High-pass does the opposite -- it removes low frequencies and lets highs through. Band-pass removes both high and low frequencies, leaving only a narrow band in the middle. Experiment with each, but know that low-pass will be your go-to for most sounds.

### ADSR Envelope: Shaping Sound Over Time

An envelope controls how a parameter changes over time when you press and release a key. Drift has two main envelopes: one for amplitude (volume) and one for the filter. Both use the ADSR model.

**A -- Attack.** How long it takes for the sound to reach full level after you press a key. Short attack = immediate, percussive sound. Long attack = slow fade-in.

**D -- Decay.** How long it takes to drop from the peak level to the sustain level. Short decay with low sustain = plucky, percussive sounds. Long decay = gradual settling.

**S -- Sustain.** The level the sound holds at while you keep the key pressed. Full sustain = the sound stays at maximum as long as you hold the key. Zero sustain = the sound dies away even while you hold the key.

**R -- Release.** How long the sound takes to fade out after you release the key. Short release = sound stops immediately. Long release = sound trails off gradually.

Let us hear what this means in practice. Find the amplitude envelope on Drift (it is usually labeled "Amp" or associated with the VCA section). With your initialized sound:

- Set Attack to minimum, Decay to minimum, Sustain to maximum, Release to minimum. Play a note. The sound starts instantly, stays at full volume while you hold, and stops instantly when you release. This is the default organ-like behavior.

- Now increase Attack to about 500ms. Play a note. The sound fades in. This is how you make pads -- sounds that swell in slowly.

- Set Attack back to minimum. Set Decay to about 300ms and Sustain to zero. Play a note. You get a short pluck -- the sound appears and immediately dies away, even if you hold the key. This is how you make plucks, stabs, and percussive synth sounds.

- Set everything moderate except Release, which you push to 2-3 seconds. Play short notes. They trail off into a long tail. This is good for atmospheric, spacious sounds.

The filter envelope works the same way, but instead of controlling volume, it controls the filter cutoff over time. Set the filter cutoff fairly low, then increase the filter envelope amount. Now when you play a note, the filter opens up and closes again according to the ADSR shape. Short attack and decay on the filter envelope with low sustain gives you that classic "wah" or "boing" sound at the start of each note -- bright attack that quickly settles into a darker tone.

### LFO: Adding Movement

LFO stands for Low Frequency Oscillator. It is an oscillator that is too slow to hear as a pitch -- instead, it creates a repeating modulation pattern that you route to other parameters.

Drift has an LFO section with a rate control and a shape selector (sine, triangle, square, etc.). The key is the modulation destination -- where you send the LFO's output.

Route the LFO to filter cutoff. Set the LFO rate to something moderate -- around 2-4 Hz. Play a sustained note. The filter opens and closes rhythmically, creating a wobbling, pulsing effect. This is the basis of wobble bass, auto-filter effects, and countless other electronic music textures.

Route the LFO to pitch instead. You get vibrato -- a subtle wavering of pitch. A small amount at a moderate rate is musical. A large amount is chaos (which can also be musical, depending on your intentions).

Route the LFO to amplitude. You get tremolo -- the volume goes up and down rhythmically.

The LFO is what makes a static synth sound come alive. Almost every synth sound you hear in professional productions has some form of LFO modulation running. Even subtle amounts add organic movement that makes the difference between a sound that feels alive and one that feels static.

---

## Exercise: Four Sounds from Initialized Drift

This is the core exercise of this chapter. You are going to create four distinct sounds starting from an initialized Drift patch each time. No presets. Every sound built from scratch using only what you have learned above.

### Sound 1: A Bass

Initialize Drift. Set Oscillator 1 to a sawtooth wave. Drop the octave down two octaves (to put you in bass territory). Turn the filter cutoff about halfway down -- you want warmth, not brightness. Set resonance to a low-moderate value for a slight bit of character. On the amplitude envelope, keep the attack short, sustain high, and release short -- bass notes should start and stop cleanly. Optionally, add a touch of filter envelope to give each note a subtle bright attack that settles into darkness. Detune Oscillator 2 slightly from Oscillator 1 for thickness.

Play low notes. Adjust the filter cutoff until the bass feels warm and full without being muddy. This is your bass sound.

### Sound 2: A Pluck

Initialize Drift. Sawtooth wave again (or try a square wave for a different character). Keep the octave in the middle range. Here is where the amplitude envelope does the heavy lifting: set Attack to zero, Decay to about 200-400ms, Sustain to zero, Release to about 100-200ms. Play a note. It should be a short, percussive "pluck" that dies away quickly.

Now add the filter. Set the cutoff fairly low. Add a significant amount of filter envelope with a short attack, moderate decay, zero sustain. The filter should open quickly and close quickly on each note, giving the pluck a bright "ping" at the start that fades to darkness. Increase resonance slightly to make that filter movement more pronounced.

Play a melody with this sound. It should sound like a synthetic plucked string or a marimba-like tone.

### Sound 3: A Pad

Initialize Drift. Use a sawtooth wave. Middle octave. Now the amplitude envelope: set Attack to 1-3 seconds. Set Decay to a moderate value, Sustain to about 70-80%, and Release to 2-4 seconds. Play a note and hold it. The sound should slowly swell in and slowly fade out when you release.

Turn on the second oscillator. Detune it from the first by a few cents. This creates a natural chorus effect that makes pads sound wide and lush. Set the filter cutoff to about 60-70% -- bright enough to be present but not so bright that it is harsh.

Now add the LFO. Route it to filter cutoff. Set a slow rate -- maybe 0.5-1 Hz. Set the amount to something subtle. Play a long chord. The filter gently opens and closes, creating a breathing, living quality. This is a pad.

### Sound 4: A Lead

Initialize Drift. Sawtooth wave, middle to upper octave range. Filter cutoff fairly open -- lead sounds need brightness to cut through a mix. Moderate resonance to give it some edge. Amplitude envelope: very short attack, moderate sustain (around 60-70%), moderate release (200-500ms).

Turn on both oscillators. Detune Oscillator 2 a few cents for thickness. Add a small amount of LFO to pitch (vibrato) -- very small amount, moderate rate. This makes the lead sound more expressive and human.

Play a melody. The sound should be bright, present, and cut through clearly even if drums and bass are playing. If it sounds thin, add more detuning between the oscillators. If it sounds harsh, pull the filter cutoff down slightly.

---

## What You Just Learned (And Why It Matters)

You now understand the four fundamental building blocks of subtractive synthesis: oscillators generate raw sound, filters shape the frequency content, envelopes control change over time, and LFOs add repeating modulation. This is not just how Drift works. This is how the vast majority of synthesizers work, from vintage Moog hardware to modern soft synths.

When you encounter a new synth -- and you will encounter many -- look for these four components. They will be there, possibly with different names, more options, and more complex routing, but the core architecture is the same. Oscillator into filter, shaped by envelopes, modulated by LFOs. You learned it on Drift, and it transfers everywhere.

You also learned that Drum Rack is not just a preset delivery system. It is a modular drum machine where every pad is its own instrument chain. Swapping samples, layering, and per-pad processing give you complete control over your drum sounds. The distance between a generic preset kit and a custom, polished drum palette is time spent choosing sounds and shaping them on individual pads.

---

## Case Study: Burial -- "Archangel"

Listen to the opening of "Archangel" by Burial. The drum sounds are heavily processed -- crackly, lo-fi, layered with vinyl noise and artifacts. But if you strip away the texture, the fundamental drum programming is simple. A kick, a snare with a long, reverberant tail, and skittering hi-hats with varied velocity.

The synth elements are also straightforward in architecture: filtered, detuned waveforms with slow envelopes. The pads swell in with long attack times. The melodic fragments have short, plucky envelopes. What makes the track extraordinary is not complexity of synthesis. It is the choices: which samples, what processing, how the envelopes are shaped, and where the sounds sit in the stereo field.

This is why learning the fundamentals matters more than learning complex techniques. The same four building blocks -- oscillator, filter, envelope, LFO -- can produce the crystalline pads of Burial, the aggressive basses of Noisia, the warm leads of Tycho, and the minimal textures of Aphex Twin. The difference is always in the specific values and combinations, not in the architecture.

---

## Before You Move On

Make sure you have done the four-sound exercise. Not read it. Done it. Loaded an initialized Drift, turned the knobs, listened, adjusted, and arrived at something that sounds like a bass, a pluck, a pad, and a lead. If any of them sound terrible, good -- that means you are learning where the boundaries of each parameter are. Terrible sounds teach you as much as good ones.

Then take those four sounds, combine them with a Drum Rack kit you built from swapped samples, and make a loop. It does not need to be long. It does not need to be brilliant. It needs to exist, and it needs to use sounds you shaped yourself rather than sounds you loaded from presets.

In the next chapter, we dive into rhythm -- not just where to put kicks and snares, but how rhythm works, what groove means, and why some patterns make you want to move while others leave you cold.
