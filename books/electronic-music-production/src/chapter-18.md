# Chapter 18: Mastering: The Basics

Mastering is the most mystified stage of music production. It has an undeserved reputation as a dark art practiced by golden-eared wizards in acoustically perfect rooms. Some mastering engineers are happy to encourage this mystique. But the fundamentals of mastering are simple, and understanding them will make your music sound better even if you eventually hire someone else to do the final master.

This chapter covers what mastering actually is, the core processes involved, what mastering cannot fix, and when to handle it yourself versus hiring a professional.

---

## What Mastering Is

Mastering is the final stage of audio production before distribution. Its job is to prepare your finished mix for release. That means three things.

First, making the track sound as good as possible on as many playback systems as possible. Your mix sounds great on your studio monitors. Mastering makes it also sound great on earbuds, car speakers, laptop speakers, and club sound systems.

Second, bringing the track to an appropriate loudness for its intended distribution format. A track destined for Spotify needs to hit a different loudness target than a track going to vinyl.

Third, ensuring consistency across multiple tracks. If you are releasing an EP or album, mastering ensures that track one and track five feel like they belong together in terms of loudness, tonal balance, and overall character.

That is it. Mastering is not magic. It is quality control, optimization, and consistency.

---

## The Mastering Signal Chain

A typical mastering chain in Ableton consists of four to five devices on the Master channel, in this order. You do not always need all of them. Start with less and add only when you hear a problem.

### Step 1: Corrective EQ

Load EQ Eight on the Master channel. This is not for creative shaping. This is for fixing tonal imbalances that you missed in the mix or that your monitoring environment introduced.

The moves here should be subtle. We are talking 1 to 2 dB at most. If you need to cut 6 dB of low-mids on the master, your mix has a problem that mastering cannot solve. Go back and fix the mix.

Common corrective moves:

- A gentle high-pass filter at 25-30 Hz to remove sub-bass rumble that eats headroom without being audible on most systems. Set the EQ Eight filter type to a 12 dB/octave high-pass.
- A slight cut in the 200-400 Hz range if the mix sounds muddy. One to two dB, broad Q.
- A gentle shelf boost above 8-10 kHz if the mix sounds dull. One dB. Maybe two. This adds air and presence.

The cardinal rule of mastering EQ: if you cannot hear the difference when you bypass it, leave it off. Every processor in your mastering chain needs to justify its existence. "It probably helps" is not justification. "I can hear that it fixes this specific problem" is.

### Step 2: Tonal Shaping (Optional)

Sometimes the mix benefits from a touch of saturation or harmonic enhancement. Saturator set to a gentle curve with very low drive -- 1 to 3 dB -- can add warmth and glue. This is optional and should be subtle enough that you would not notice it in isolation. You are adding harmonic content to make the mix feel slightly more cohesive and present.

If you use this, keep the Dry/Wet at 100% and the Drive low. The output should be barely louder than the input. Use the Output knob to compensate for any volume increase so you are comparing fairly.

### Step 3: Compression (Optional)

Master bus compression is controversial. Many mastering engineers use it. Many do not. The goal, when it is used, is glue: making the mix feel like a single cohesive sound rather than a collection of individual elements.

If you use compression on the master, the settings should be gentle:

- Ratio: 1.5:1 to 2:1. Nothing higher.
- Attack: Slow. 20-30 ms. You want transients to pass through untouched.
- Release: Auto, or matched to the tempo so the compressor breathes with the music.
- Threshold: Set so you are getting 1-2 dB of gain reduction at most during the loudest sections. If your compressor is working hard, you are doing too much.

Glue Compressor is a good choice here because it was designed for bus compression. Load it, set a low ratio, slow attack, auto release, and bring the threshold down until you see 1-2 dB of gain reduction on the peaks.

If you are not sure whether master compression is helping, bypass it. If the track sounds better without it, leave it off. There is no rule that says you must compress the master.

### Step 4: Stereo Imaging

Load Utility after your EQ and compression. There are two things to address here.

**Bass in mono.** Low frequencies below roughly 150 Hz should be mono. Stereo bass causes phase issues on many playback systems, especially clubs, and wastes headroom. In Utility, set the Bass Mono option and set the frequency to around 120 Hz. This collapses everything below that frequency to the center without affecting the stereo image of everything above it.

**Overall width.** Check your stereo image. If the mix sounds too narrow, you can increase the Width slightly above 100%. If it sounds too wide or phasey, pull it back. Small moves -- 95% to 110% is the typical range. Anything beyond that starts to sound artificial.

You can also use EQ Eight in Mid/Side mode to make more surgical adjustments. For example, boosting the Side signal above 5 kHz by a dB or two adds air and width to the top end without affecting the centered low-frequency content. But this is an advanced move. Start with Utility's Width and Bass Mono.

### Step 5: Limiting

The limiter is the last device in your mastering chain. Its job is to bring the track up to the target loudness while preventing the signal from exceeding 0 dBFS, which would cause digital clipping.

Load Limiter on the Master channel, after everything else.

**Ceiling.** Set to -1.0 dB. Not 0. Not -0.5. Set it to -1.0 dB. This leaves headroom for lossy encoding (MP3, AAC, streaming codecs) which can cause intersample peaks that exceed 0 dBFS. The -1 dB ceiling prevents this.

**Gain.** This is where you set your loudness. Bring the Gain up slowly. Watch the gain reduction meter. You want the limiter working, but not working hard. For most electronic music, 3-6 dB of gain into the limiter is typical. If you are pushing 10+ dB of gain reduction, your mix is too quiet and you should go back and address levels in the mix, not try to fix it with the limiter.

**Target loudness.** For streaming platforms (Spotify, Apple Music, Tidal), aim for -14 LUFS integrated. This is the loudness normalization target for most streaming services. If your track is louder than -14 LUFS, the platform will turn it down. If it is quieter, some platforms will turn it up. Hitting -14 LUFS means your track plays back at the volume you intended.

For club music or tracks that will primarily be played by DJs, you might target -8 to -10 LUFS, which is significantly louder. Know your context.

**Measuring loudness.** You need a loudness meter. Ableton does not include a dedicated LUFS meter, but you can use the free Youlean Loudness Meter plugin or similar. If you want to stay stock, keep an eye on the Limiter's gain reduction and use your ears -- but a proper LUFS meter is one of the few third-party tools worth installing.

---

## Using Reference Tracks

Do not master in a vacuum. Load a professionally mastered reference track into an audio track in your session. Put a Utility on that track and match its perceived loudness to your master. Now A/B between them.

You are not trying to make your track sound identical to the reference. You are checking for glaring differences. Is your track significantly darker? Brighter? More or less bass-heavy? Is the stereo image narrower or wider?

Reference tracks expose the biases of your monitoring environment. If every track you master comes out bass-heavy compared to references, your room probably has a bass null at your listening position and you are unconsciously compensating. The reference track tells you the truth that your room is hiding.

Choose references in a similar genre with a similar energy level. Comparing your ambient track to a maximally compressed EDM banger will not teach you anything useful.

---

## What Mastering Is Not

This needs its own section because the misconceptions are widespread and damaging.

**Mastering is not a fix for a bad mix.** If your kick is buried, your vocals are too loud, or your low end is boomy, mastering cannot fix these problems. Every tool in the mastering chain operates on the stereo mix as a whole. You cannot turn up just the kick on a mastered file because the kick is not a separate element anymore. It is baked into the stereo file. Go back and fix the mix.

**Mastering is not "making it loud."** Loudness is one component of mastering. If loudness is the only thing your mastering chain does, you are not mastering. You are just limiting.

**Mastering is not where you add creative effects.** If you want to add distortion, heavy filtering, or dramatic EQ curves, do it in the mix. Mastering is subtle refinement, not sound design.

**Mastering does not make a mediocre track good.** It makes a good mix slightly better and ready for distribution. If you are hoping that mastering will transform your track, you are hoping for something that does not exist.

The most honest description of mastering I have heard: it takes a track from 90% to 95%. If your track is at 60% before mastering, it will be at 65% after. The leverage is small. The mix is where the real work happens.

---

## When to Master Yourself vs. Hiring a Professional

Master your own tracks when:

- You are learning and want to understand the process.
- You are releasing music informally (SoundCloud, Bandcamp, sending to friends).
- Your budget does not allow for professional mastering.
- You are producing a lot of tracks and want quick turnaround.

Hire a professional mastering engineer when:

- You are releasing on a label. Most labels expect professional mastering.
- You are releasing an album or EP and need consistency across tracks.
- You have been staring at the same tracks for months and need fresh ears.
- You want the track to compete sonically with professional releases.
- Your monitoring environment is compromised and you do not trust your ears on fine details.

A good mastering engineer brings three things you probably do not have: a room that is acoustically treated to a very high standard, monitoring systems that reveal details your setup hides, and ears that are not fatigued from having mixed the track for the last three weeks. That fresh perspective is valuable.

Professional mastering typically costs between $25 and $75 per track, depending on the engineer. For an EP, that is $100 to $375. If you are serious about a release, it is worth it.

---

## Common Mastering Mistakes

**Too much limiting.** This is the most common mistake by a wide margin. You push the limiter until the track is as loud as your reference, and in doing so you crush all the dynamics out of the music. The kick stops punching. The quiet moments are not quiet anymore. The track sounds flat and fatiguing. Back off the limiter until you can hear the dynamics breathing again.

**EQ moves that are too aggressive.** If you are making 4+ dB moves on the master EQ, you are mastering a mix that is not ready to be mastered. Go back. Fix the mix. Master EQ should be 1-2 dB moves, broad strokes.

**Not checking on multiple systems.** Your master sounds great on your monitors. Does it sound great on earbuds? On your phone speaker? In the car? Export your master and listen on at least three different systems before you call it finished. If it falls apart on earbuds, you have a problem.

**Mastering in the same session as the mix.** This is tempting but problematic. You are too close to the mix. Your ears are fatigued. You will make decisions based on what you have been hearing for hours rather than what is actually there. Export your mix as a stereo WAV. Open a new Ableton project. Import the WAV. Master it fresh. Better yet, wait a day between mixing and mastering.

**A/B without level matching.** Louder sounds better. Always. If you are comparing your mastered track to your unmastered mix without matching their levels, you will think the mastered version sounds better even if you have actually made it worse. Use Utility to match the perceived loudness before comparing.

**Skipping the bypass check.** After you have set up your mastering chain, bypass the entire chain and listen to the raw mix. Then enable it. Is it better? If you are not sure, it is not better. Remove processors until you can clearly hear the improvement. A mastering chain with one device that is clearly helping is better than a chain with five devices that might be helping.

**Processing before the mix is finished.** Do not put mastering processors on your master bus while you are still mixing. You will make mix decisions that compensate for what the mastering chain is doing, and when you change the mastering chain, your mix will sound wrong. Mix first. Master second. Keep them separate.

---

## A Simple Mastering Workflow

Here is a practical workflow you can follow for every track.

1. Export your finished mix as a 24-bit WAV file with at least 3 dB of headroom. This means your mix should peak at around -3 dBFS before any mastering processing.

2. Open a new Ableton session. Import the WAV file.

3. Import a reference track. Level-match it to your mix using Utility.

4. Add EQ Eight to the Master. Listen critically. Make small corrective moves if needed. A/B constantly.

5. Decide if you need compression. If the mix already feels cohesive, skip it. If it feels like elements are fighting each other, add gentle Glue Compressor.

6. Add Utility. Enable Bass Mono at 120 Hz. Check the Width.

7. Add Limiter last. Set ceiling to -1 dB. Bring up the Gain until you hit your target loudness. For streaming, aim for -14 LUFS.

8. A/B against your reference. A/B against the unmastered version with level matching.

9. Export. Listen on three different systems. If anything sounds wrong, go back and adjust.

10. If you cannot fix it in mastering, go back and fix it in the mix.

---

## Exercises

1. Take a finished mix and master it using only EQ Eight and Limiter -- the minimum chain. Set the ceiling to -1 dB and target -14 LUFS. Export and listen on headphones, phone speakers, and whatever monitors you have. Note what sounds good and what does not.

2. Master the same track again, this time adding Glue Compressor and Utility. Compare the two masters. Can you hear the difference? Is the fuller chain actually better, or just different?

3. Find three professionally mastered tracks in a similar genre to yours. Load them into a session and level-match them. Compare their tonal balance, stereo width, and dynamic range to your master. What differences do you notice?

4. Deliberately over-master a track. Push the limiter until you get 10+ dB of gain reduction. Make aggressive EQ moves. Listen to the result. This is what over-processing sounds like. Now you know what to avoid.
