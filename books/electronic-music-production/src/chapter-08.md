# Chapter 8: Working with Audio and Sampling

Electronic music was built on sampling. House music was born from Chicago producers looping disco records. Hip-hop was built on breakbeats pulled from funk and soul. Jungle and drum & bass exist because someone decided to time-stretch the Amen break until it shattered into something new. The entire history of this genre is a history of taking existing sounds and transforming them into something unrecognizable.

This chapter covers the technical and creative sides of working with audio in Ableton Live. You will learn how warping works and when to use each warp mode, how to edit and manipulate audio clips, how to resample your own output, and how to chop and rearrange samples using Simpler. By the end, you should be able to take any piece of audio (a vinyl record, a field recording, a YouTube rip, your own synth noodling) and turn it into raw material for a track.

---

## Audio Warping

Warping is Ableton's system for time-stretching audio. When you drag an audio file into a project, Ableton analyzes it and places warp markers at detected transients. These markers tell Ableton how to stretch or compress the audio to match your project tempo without changing its pitch.

To enable or disable warping, double-click an audio clip to open the Clip View, then toggle the Warp button in the Sample section. When Warp is on, the clip will play at the project tempo regardless of its original tempo. When Warp is off, the clip plays at its original speed and pitch.

The key decision you need to make is which Warp Mode to use. Each mode uses a different algorithm, and choosing the wrong one produces artifacts: clicks, smearing, metallic tones, or rhythmic glitches. When to use each:

**Beats Mode:** Use this for anything rhythmic and percussive — drum loops, percussion, chopped breaks. Beats mode works by slicing the audio at transient points and rearranging the slices. It preserves the attack and punch of drums but can create gaps or overlaps in sustained sounds. Set the Transient Resolution to match the rhythmic density of your material (1/16 for busy patterns, 1/8 for simpler ones). The Transient Loop Mode determines what fills the gaps — "Loop Off" leaves silence (good for tight drums), "Loop Forward" repeats the transient tail (smooths gaps).

**Tones Mode:** Use this for monophonic pitched material: bass lines, single-note melodies, vocals with a clear pitch. Tones mode uses granular resynthesis optimized for pitched content. Set the Grain Size to match the character of the sound — smaller values (around 20-40) preserve detail but can add artifacts; larger values (60-100) are smoother but less precise. This is your go-to mode for vocal samples.

**Texture Mode:** Use this for polyphonic or complex tonal material: pads, chords, dense textures, ambient recordings. Texture mode uses a granular algorithm that randomizes grain positions slightly, which smears the detail but preserves the overall character. Good for atmospheric sounds where exact transient preservation does not matter. The Flux parameter controls the amount of randomization — higher values create a more diffuse, washy sound.

**Re-Pitch Mode:** This does not time-stretch at all. Instead, it changes the playback speed to match the tempo, which changes the pitch proportionally, just like speeding up or slowing down a record. Use this when you want the vinyl-style pitch shift effect, or when no time-stretching algorithm sounds good enough. Re-Pitch produces zero artifacts because it does not process the audio at all.

**Complex Mode:** Use this for full mixes, mastered tracks, or complex polyphonic material with both rhythmic and tonal content. Complex mode uses a more CPU-intensive algorithm that tries to handle all types of content reasonably well. It is the best choice for warping a reference track or a full song. It does not excel at any one thing, but it handles everything acceptably.

**Complex Pro Mode:** The highest-quality general-purpose mode. Use it for the same material as Complex but when you need better quality and can afford the CPU hit. The Formants control is useful for vocals — it preserves the natural timbral quality of a voice even when the pitch is shifted. Envelope controls the attack response — higher values preserve transients better.

**A practical rule:** Start with Beats for drums, Tones for melodies and vocals, Texture for pads and atmospheres, Complex Pro for full mixes. If something sounds wrong, try the next most appropriate mode. If nothing sounds right, use Re-Pitch and accept the pitch change, or find a different sample.

---

## Consolidating and Bouncing

When you have edited, warped, or arranged audio clips to your satisfaction, you should consolidate them.

**Consolidate (Cmd-J):** Select one or more clips on the same track and press Cmd-J. Ableton renders them into a single new audio file that includes all your edits, warping, and clip-level processing. The original files remain untouched in your project folder. This is nondestructive.

Consolidating is essential after arranging. If you have 20 short clips on a track that form your verse, consolidate them into a single clip. It simplifies the arrangement, makes it easier to move sections around, and ensures that all your warp settings are baked in.

**Freeze and Flatten:** Freezing a track (right-click the track header > Freeze Track) renders the entire track to audio, including all device processing. This is useful for freeing up CPU. Flattening (right-click > Flatten) then replaces the original clips and devices with the rendered audio permanently.

Freeze and Flatten is how you bounce MIDI to audio, render complex effect chains to a file, or commit to a sound so you stop tweaking it. It is also the workflow for resampling, which we will cover shortly.

**Export as Audio (Cmd-Shift-R):** For rendering your final mix or individual stems, use File > Export Audio/Video. You can export individual tracks, groups, or the master output. For stems, select "All Individual Tracks" in the Rendered Track dropdown.

---

## Audio Editing

Ableton's audio editing is streamlined compared to a dedicated audio editor, but it covers everything you need for music production.

**Splitting clips (Cmd-E):** Place your cursor at the point where you want to split, select the clip, and press Cmd-E. The clip divides into two independent clips at that point. Use this to isolate a specific section of a longer recording, or to create a gap in a clip.

**Fades:** When you hover near the beginning or end of an audio clip, you see small fade handles. Drag them to create fade-ins and fade-outs. For crossfades between adjacent clips, drag the end of one clip to overlap the beginning of the next — Ableton creates an automatic crossfade. You can adjust the fade curve by clicking the fade and dragging the curve handle.

Fades are critical for preventing clicks and pops at edit points. Any time you split a clip or place a clip that does not start or end at a zero crossing, add a short fade (even 2-5 ms) to eliminate artifacts.

**Reverse:** Right-click an audio clip and select Reverse. The clip plays backward. This is a creative tool as much as a technical one — reversed cymbals, reversed vocals, and reversed pads are staples of electronic production. Remember that reversing a clip is nondestructive in Ableton — it creates a new reversed file and leaves the original intact.

**Looping:** In the Clip View, enable the Loop toggle. Set the Loop Length and Position to define which portion of the clip repeats. This is useful for creating sustained textures from short recordings, or for isolating a specific groove from a longer performance.

**Clip Gain and Volume:** Use the clip's Gain control (in the Clip View, under the sample waveform display) to adjust the level of individual clips before they hit any effects. This is useful for matching levels between clips from different sources.

---

## Resampling

Resampling is the process of recording Ableton's own output back into itself. It is one of the most powerful creative tools available to you.

**Setup:** Create a new audio track. In the track's Input dropdown (the "Audio From" selector), choose "Resampling." Arm the track for recording (click the Arm button or press the track's key mapping). Now, anything that plays through Ableton's master output will be recorded into this track.

**Uses for resampling:**

- **Committing to a sound:** You have a synth patch running through five effects with automation on all of them. Resample it. Now you have a clean audio file that sounds exactly like what you heard, and you can delete the original synth and effects to free up CPU.

- **Creative destruction:** Play your loop, and while it plays, manipulate effects in real time — twist the filter, crank the distortion, add stutter effects. Resample the result. You will capture happy accidents and performance moments that you could never program.

- **Layering and stacking:** Resample a chord progression, then pitch it down an octave and layer it under the original. Resample a drum loop, add heavy saturation, and blend it with the clean version.

- **Building complexity from simplicity:** Start with a simple sine wave. Resample it with reverb. Resample the reverb tail with granular processing. Resample that with distortion. After a few rounds, you have a complex, evolving texture that started from nothing.

The workflow is simple: set input to Resampling, arm, play, record, stop. Then trim and use the resulting audio however you want.

---

## The Art and History of Sampling

Sampling is a philosophy as much as a technique. Understanding its history makes you a better producer.

**House music** emerged in the early 1980s in Chicago when DJs like Frankie Knuckles and producers like Larry Heard began looping and manipulating disco records. The Roland TR-808 and TR-909 provided the beats, but the harmonic and melodic content often came from sampled and replayed disco, soul, and funk records. Sampling was the bridge between the past and the future.

**Hip-hop** took sampling in a different direction. Producers like J Dilla, DJ Premier, and the Bomb Squad built entire sonic worlds from chopped-up vinyl. The MPC became the instrument of choice. You loaded a record into it, chopped it into slices, and replayed them on the pads in a new sequence. The sample was the composition.

**Jungle and drum & bass** were built on one sample more than any other: the Amen break, a four-bar drum solo from "Amen, Brother" by The Winstons (1969). Producers sped it up, sliced it, rearranged it, and layered it until it became something entirely new. The same six seconds of drumming became the foundation for an entire genre.

**The lesson:** sampling is not lazy. It is a creative act of recontextualization. You take a sound from one world and place it in another, and in doing so, you create meaning that did not exist before.

---

## Finding Samples

You need raw material. Where to find it:

**Ableton's Core Library:** Ships with Live and includes thousands of one-shots, loops, and processed samples. Browse it in the browser sidebar under Packs > Core Library. The quality is high and everything is royalty-free.

**Splice:** A subscription service where you pay monthly and download individual samples. The catalog is enormous and well-tagged. At $9.99/month for 100 credits, it is the most cost-effective way to build a sample library. Search by genre, key, BPM, and instrument type.

**Freesound.org:** A community-driven repository of Creative Commons-licensed sounds. The quality varies widely, but it is an incredible resource for field recordings, found sounds, and unusual textures that you will not find in commercial sample packs. Always check the license, since some require attribution.

**Your own recordings:** Your phone's microphone is a sampling instrument. Record street sounds, conversations (with consent), mechanical noises, your own voice. These give your music a texture that no sample pack can provide because nobody else has them.

**Vinyl and existing recordings:** This is the traditional sampling source. Be aware of copyright — if you release music with recognizable samples from copyrighted recordings, you need clearance. However, for learning, experimentation, and unreleased music, sampling records is one of the best ways to develop your ear and your skills.

---

## Chopping in Simpler Slice Mode

Simpler is Ableton's streamlined sampler, and its Slice mode turns it into a sample-chopping workstation.

**Step 1:** Drag an audio sample onto a MIDI track. Simpler loads automatically. If Sampler loads instead, right-click the title bar and choose "Simpler."

**Step 2:** In Simpler's interface, click the "Slice" mode button (one of three modes: Classic, One-Shot, Slice). Simpler analyzes the sample and places slice markers at detected transients.

**Step 3:** Each slice is mapped to a MIDI note, starting from C1 and moving up chromatically. Play your MIDI controller or draw MIDI notes in the piano roll to trigger individual slices. Each note plays one slice.

**Step 4:** Adjust the slicing. You can change the Slice By parameter:
- **Transient:** Slices at detected attacks. Adjust the Sensitivity to get more or fewer slices.
- **Beat:** Slices at regular rhythmic intervals (every beat, every half-beat, every bar).
- **Region:** Divides the sample into equal-sized regions.
- **Manual:** You place the slice markers yourself by clicking in the waveform.

**Step 5:** Now rearrange. Program a new MIDI pattern using the sliced notes. You are rearranging the sample — playing its fragments in a new order, at a new tempo, with a new rhythm. This is the essence of sample-based production.

**Tip:** After you have a MIDI pattern you like on a Simpler in Slice mode, right-click the Simpler title bar and select "Slice to Drum Rack." This converts each slice into a separate pad in a Drum Rack, giving you individual control over each slice's volume, panning, effects, and envelopes.

---

## Creative Recontextualization

The goal of sampling is not to use a sound as-is. It is to transform it until it becomes yours. Here are techniques for making samples unrecognizable:

**Pitch shifting:** Transpose a sample up or down an octave or more. A vocal sample pitched down 12 semitones becomes a deep, ominous texture. A guitar riff pitched up 7 semitones becomes a bell-like melody.

**Time-stretching to extremes:** Take a 4-bar loop and stretch it to 64 bars using Texture warp mode. You get a glacial, ambient wash that retains the harmonic character of the original but none of its rhythm.

**Reversing:** A reversed piano chord becomes a swelling pad. A reversed vocal becomes an alien texture. Combine with reverb for even more transformation.

**Granular processing:** If you have Granulator II (a free Max for Live device from Robert Henke), load a sample into it and explore the Grain Size, Position, and Spray parameters. You can dissolve any sample into a cloud of micro-fragments.

**Heavy processing chains:** Run a sample through distortion, then a resonant filter, then reverb, then a phaser, then bounce it. The result will bear no resemblance to the input. This is sound design through destruction.

**Isolating fragments:** Take a 30-second sample and use only a half-second of it — a single chord stab, a breath, a consonant. Remove all context and the sample becomes a raw sound source.

**Layering:** Combine three or four processed samples into a single texture. Even if each individual sample is recognizable, the combination is unique.

---

## Warping as Composition

Warping is not just a tool for tempo-matching. It is a compositional tool.

**Manual warp markers as performance:** Place warp markers at irregular intervals within a clip and drag them to create stutters, stretches, and rhythmic distortions. A straight vocal phrase becomes a glitchy, rhythmically complex performance.

**Extreme tempo changes:** Load a sample and set the project tempo dramatically different from the sample's original tempo. A 120 BPM break at 170 BPM becomes frantic jungle. The same break at 80 BPM becomes a lumbering half-time groove. The character changes entirely.

**Warp mode as texture:** The artifacts that warp modes produce are sounds in themselves. Beats mode at extreme stretches creates percussive stutters. Tones mode with wrong grain sizes creates metallic, robotic textures. Texture mode with high Flux values creates washy, dreamlike atmospheres. These are not flaws. They are tools.

---

## Case Study: The Avalanches — "Since I Left You"

> The Avalanches' debut album "Since I Left You" (2000) is perhaps the greatest sampling achievement in electronic music history. The album uses approximately 3,500 samples drawn from a vast range of sources: obscure 1960s pop records, film soundtracks, disco tracks, spoken word recordings, sound effects, and more.
>
> What makes the album remarkable is not the quantity of samples but the quality of their transformation and curation. Every sample is processed, pitched, filtered, and layered until the sources become unrecognizable. A string phrase from a 1970s film score becomes the harmonic foundation of a track. A two-word vocal snippet becomes a hook repeated and varied throughout an entire song. A drum break from a rare funk 45 becomes the rhythmic backbone of a dancefloor moment.
>
> The key lesson from the Avalanches is that sampling is composition. Robbie Chater and Tony Di Blasi did not paste samples together. They auditioned thousands of records, identified fragments with potential, and then assembled those fragments into entirely new musical structures. The choosing is the creative act as much as the arranging.
>
> Listen to the title track. The main melodic sample (from a 1960s Italian pop song) is pitched down and filtered until it sounds like nothing else. The vocal ("Since I left you, I found the world so new") is a fragment that carries the emotional weight of the entire album. Drums are layered from multiple sources and processed into a unified groove. None of these elements sound like they were "sampled." They sound like they were composed.
>
> For your own production: approach sampling as curation. Build a library of sounds you love. Listen to records not for their songs but for their moments — a two-beat drum fill, a single chord voicing, a texture in the background. Collect these moments and then combine them in unexpected ways. The art is in the selection and the combination.

---

## Exercise: Three-Sample Mashup

This exercise forces you to create something new from found material.

**Step 1:** Choose three completely unrelated audio samples. They should come from different genres, different eras, different instruments. A jazz piano recording, a field recording of rain, and a hip-hop vocal, for example. Use Freesound, your own library, or Ableton's Core Library.

**Step 2:** Import all three into Ableton. Warp each one to match your project tempo. Choose the appropriate warp mode for each.

**Step 3:** Your goal is to create a cohesive 8-bar musical section using only these three samples as source material. You may:
- Chop them in Simpler Slice mode
- Reverse them
- Pitch shift them
- Layer them
- Run them through any effects (filtering, reverb, delay, distortion)
- Resample and re-process

**Step 4:** The finished 8 bars should sound like they belong together — not like three unrelated sounds playing at the same time. Use EQ to carve space for each element. Use reverb on a send to place them in the same acoustic space. Use filtering to smooth out tonal clashes.

**Step 5:** Export the 8-bar section and listen to it on headphones, then on your phone speaker. Does it hold together? If not, identify what clashes and address it.

This exercise builds the most important sampling skill: the ability to hear potential in raw material and to transform disparate sources into a unified whole. Do it repeatedly with different source material and your ear will sharpen rapidly.

---

## Moving Forward

You now have the technical vocabulary and practical skills to work with audio in Ableton — warping, editing, chopping, resampling, and creative transformation. These skills intersect with everything else in this book. Sound design, arrangement, and mixing all benefit from your ability to manipulate audio confidently.

The next chapter tackles mixing fundamentals: getting all these elements to sit together in a clear, balanced, and impactful way.
