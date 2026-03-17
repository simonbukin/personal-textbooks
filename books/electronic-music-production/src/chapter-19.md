# Chapter 19: The Export and Delivery Pipeline

You have finished your track. It is mixed. It is mastered. Now you need to get it out of Ableton and into the world. This chapter covers export settings, dithering, metadata, distribution platforms, and how to prepare your music for different release contexts. These are not glamorous topics, but getting them wrong can undo hours of careful production and mixing work.

---

## Export Settings in Ableton

Go to File > Export Audio/Video, or press Cmd-Shift-R (Mac) / Ctrl-Shift-R (Windows). This opens the Export dialog. Here is what every setting means and what you should choose.

**Rendered Track.** This determines what gets exported. "Master" exports your full stereo mix including everything routed to the Master channel. This is what you want for a finished master. You can also export individual tracks or groups, which is how you create stems.

**Render Start / Render Length.** Set these to cover your entire track. Make sure you include any reverb or delay tails that extend past the last note. A common mistake is cutting the export right at the last MIDI note, chopping off the reverb tail. Add an extra bar or two at the end.

**Include Return and Master Effects.** Leave this on for your final master. Turn it off only if you are exporting dry stems for someone else to mix.

Now, the critical settings.

### WAV 24-bit for Mastering

If you are exporting a mix that will be mastered by someone else (or by you in a separate session), use these settings:

- File Type: WAV
- Bit Depth: 24
- Sample Rate: Whatever your project is set to (usually 44100 or 48000)
- Dither: Off
- Normalize: Off

24-bit gives you 144 dB of dynamic range. This preserves every detail of your mix with headroom to spare. You leave dithering off because the mastering engineer will apply dithering at the final stage. You leave normalization off because you want the mastering engineer to receive your mix at the level you set it, with whatever headroom exists.

Make sure your mix peaks at around -3 to -6 dBFS. This gives the mastering engineer room to work. If your mix is peaking at 0 dBFS, you are not leaving headroom, and the mastering engineer will have to turn it down before processing it, which is a waste of everyone's time.

### WAV 16-bit 44100 for Final Distribution

If you have mastered the track yourself and it is ready for distribution, export with these settings:

- File Type: WAV
- Bit Depth: 16
- Sample Rate: 44100 Hz
- Dither: Triangular (or POW-r 1)
- Normalize: Off

16-bit / 44100 is CD-quality audio. It is the standard for digital distribution. Most distributors (DistroKid, TuneCore) accept and prefer this format. Some accept 24-bit as well, but 16-bit / 44100 is universally accepted.

The dithering is critical here and we will discuss it in detail shortly.

### MP3 320 kbps for Sharing

For casual sharing -- sending a track to a friend, uploading a preview, posting on social media:

- File Type: MP3
- Bit Rate: 320 kbps
- Sample Rate: 44100 Hz

320 kbps is the highest quality MP3 encoding. It is perceptually transparent for most listeners on most playback systems, meaning the difference between the MP3 and the WAV is inaudible in normal listening conditions. It is fine for sharing. It is not fine for distribution to streaming platforms. They want WAV files and will encode to their own formats.

Do not use MP3 as an intermediate format. Never export to MP3, then import the MP3 back into a project for further work. Each round of lossy encoding degrades quality. WAV is your working format. MP3 is your delivery format for casual use only.

### Stems

Stems are separate audio files for each element or group of elements in your mix. You might export stems for:

- Remixers who want to rework your track.
- A mixing engineer who is mixing your project.
- Live performance, where you want to play back individual elements.
- Collaboration, where you are sending parts to someone working in a different DAW.

To export stems, solo each track or group and export individually, or use Ableton's "All Individual Tracks" option in the Rendered Track dropdown. Export as WAV 24-bit at your project sample rate, with no dithering. Make sure all stems start at the same point in time so they align when imported into another project.

Name your stems clearly: "Kick.wav," "Bass.wav," "Pad_Layer_1.wav," "Vocal_Chop.wav." The person receiving them should be able to understand what each file is without opening it.

---

## Dithering Explained

Dithering is one of those topics that sounds more complicated than it is, but getting it wrong is audible in some cases.

When you reduce bit depth -- for example, going from 24-bit to 16-bit -- you are reducing the resolution of the audio. The quietest sounds in your mix can no longer be represented accurately. Without dithering, this truncation creates a type of distortion called quantization noise, which sounds like a harsh, buzzy artifact, particularly noticeable in quiet passages and fade-outs.

Dithering adds a tiny amount of random noise to the signal before the bit depth reduction. This noise is essentially inaudible -- it sounds like a very faint hiss -- but it masks the quantization distortion, which sounds much worse. You are trading ugly distortion for barely-perceptible noise. It is a good trade.

**The rules of dithering are simple:**

1. Only dither when you are reducing bit depth. If you are exporting at the same bit depth as your project, do not dither.

2. Only dither once. Dithering adds noise. Dithering again adds more noise on top of the first layer of noise. If you dither when exporting your mix and then dither again when mastering, you have double-dithered, and the noise floor is higher than it needs to be.

3. Dither at the final stage. If your workflow is: mix at 24-bit, export for mastering at 24-bit, master, then export final master at 16-bit -- you dither only on that final export to 16-bit. Nowhere else.

4. Triangular dithering is the safest default. It adds the least noise and has no noise shaping. POW-r dithering options shape the noise into higher frequencies where human hearing is less sensitive, which can make the noise even less audible but at the cost of slightly more total noise energy. For most purposes, Triangular is fine.

In Ableton's Export dialog, select your dither type from the Dither Options dropdown. If you are exporting at 24-bit for mastering, select "No Dither." If you are exporting your final master at 16-bit, select "Triangular."

---

## Metadata Tagging

Your exported WAV or MP3 file is a container that can hold more than just audio. It can hold metadata: the track title, artist name, album name, year, genre, and other information. Most streaming platforms and media players use this metadata to display track information.

Ableton does not handle metadata well. After exporting, use a dedicated metadata editor.

**Kid3** is free, open-source, and works on Mac, Windows, and Linux. It handles WAV, MP3, FLAC, and most other audio formats.

**MP3Tag** is free for Windows and available for Mac. It is the most popular metadata editor for a reason: it is simple and reliable.

At minimum, tag your files with:

- Title: The track name.
- Artist: Your artist name.
- Album: The release name, if applicable.
- Year: The release year.
- Track Number: If part of an EP or album.
- Genre: A general genre tag.

If you are distributing through a platform like DistroKid, you will enter this information in their web interface and they will embed it. But it is good practice to tag your files regardless, because you will also share files directly, and a file called "bounce_final_v3_FINAL.wav" with no metadata is unprofessional.

While you are at it, name your files properly. "Artist_Name_-_Track_Title.wav" is a good convention. Not "master_03.wav." Not "finished maybe.wav." Future you will thank present you.

---

## Distribution Platforms

Getting your music onto streaming platforms requires a distributor, a service that acts as the middleman between you and Spotify, Apple Music, Tidal, Amazon Music, and the rest. You cannot upload directly to most of these platforms.

**DistroKid** charges an annual fee (around $20-25/year at time of writing) and lets you upload unlimited tracks to all major platforms. It is the most popular choice for independent artists. It is fast; tracks typically appear on platforms within a few days. The trade-off is that if you stop paying, your music gets taken down.

**TuneCore** charges per release (single or album pricing) and keeps your music up permanently. More expensive for prolific artists, but you own the distribution permanently.

**LANDR** offers distribution alongside their automated mastering service. Convenient if you are using their mastering, but their mastering is automated and not a substitute for learning the process yourself or hiring a human.

**Amuse** and **Ditto** are other options with different pricing models. Research current pricing before committing -- these services change their terms regularly.

All of these services take your WAV files, encode them to the formats required by each platform, and deliver them with metadata, artwork, and release information. You need:

- Master audio files (WAV 16-bit 44100, or 24-bit -- check your distributor's requirements).
- Album artwork at minimum 3000x3000 pixels, JPEG or PNG.
- Track titles, artist name, and release date.
- ISRC codes (your distributor usually generates these for you).

---

## Streaming Platform Considerations

Every major streaming platform applies loudness normalization. This means they measure your track's loudness and adjust playback volume so that all tracks on the platform play at roughly the same perceived loudness.

**Spotify** normalizes to approximately -14 LUFS. If your track is mastered to -10 LUFS, Spotify turns it down by about 4 dB. If your track is mastered to -16 LUFS, Spotify turns it up by about 2 dB (depending on the user's settings).

**Apple Music** normalizes to approximately -16 LUFS using Sound Check (when enabled by the user).

**YouTube** normalizes to approximately -14 LUFS.

**Tidal** normalizes to approximately -14 LUFS.

What this means in practice: there is no loudness advantage to crushing your master to -8 LUFS. The platform will just turn it down, and in doing so, all the dynamic range you sacrificed for loudness is gone but the squashed, lifeless sound remains. You made your track worse for no benefit.

Master to -14 LUFS for streaming and let the dynamics breathe. Your track will play at its intended volume and sound better than the over-compressed track next to it in the playlist.

If you are also releasing for DJ play, consider making a separate, louder master at -8 to -10 LUFS for that context. DJs expect hotter levels. But your streaming master should be -14 LUFS.

---

## Preparing for Different Release Contexts

Different platforms and formats have different requirements and conventions. Here is how to prepare for each.

### Bandcamp

Bandcamp is the most artist-friendly platform. It lets listeners buy your music directly, pays a high royalty share, and allows you to offer multiple download formats.

Upload WAV 24-bit at your project sample rate. Bandcamp will generate MP3, FLAC, AAC, Ogg, and other formats from your source file. Upload the highest quality file you have and let Bandcamp handle the encoding.

Bandcamp does not apply loudness normalization. Your track plays back at whatever loudness you mastered it to. This gives you more control, but it also means that if your track is mastered too quietly compared to other Bandcamp releases, it will sound quiet.

### SoundCloud

SoundCloud accepts WAV, FLAC, AIFF, and MP3. Upload WAV for the best quality. SoundCloud transcodes everything to 128 kbps Opus (or MP3 for older uploads), so your source file quality matters -- a better source file produces a better transcode.

SoundCloud applies some loudness normalization, but it is inconsistent. Master to -14 LUFS and you will be fine.

SoundCloud is excellent for sharing works in progress, unreleased tracks, and DJ mixes. It has a strong community features and is where many electronic music listeners discover new artists.

### Spotify and Apple Music

Upload through your distributor. WAV 16-bit 44100 is the standard format. Both platforms transcode to their own formats (Ogg Vorbis for Spotify, AAC for Apple Music).

These are the platforms where loudness normalization matters most. Master to -14 LUFS. Ensure your artwork meets their specifications (3000x3000 minimum for Spotify, 4000x4000 recommended for Apple Music).

### Vinyl

If you are pressing vinyl, the mastering requirements are different and specialized. Vinyl has physical constraints -- the bass must be mono (stereo bass causes the needle to jump), the overall level cannot be as hot as digital, and very high frequencies can cause distortion.

You almost certainly need a professional mastering engineer who specializes in vinyl cutting. Provide them with your mix (not your digital master) as a 24-bit WAV. They will create a vinyl-specific master with appropriate EQ, mono bass, and level adjustments.

Vinyl is expensive to press and has a long lead time (weeks to months). But there is a dedicated audience that values the format, and for certain genres -- house, techno, ambient -- a vinyl release carries cultural weight.

---

## The Export Checklist

Before you export your final master, run through this checklist:

1. Listen to the entire track from beginning to end without stopping. No skipping ahead. If anything bothers you, fix it before exporting.

2. Check the beginning and end. Does the track start cleanly? Does the reverb tail at the end fade out completely, or is it cut off?

3. Check for clicks, pops, or digital artifacts. Solo each track briefly and listen for problems.

4. Verify your export range covers the entire track plus tail.

5. Verify your export settings match your intended use (see the settings above).

6. After exporting, open the exported file in a fresh Ableton session (or any audio player) and listen to it from beginning to end. Confirm it sounds like what you expected. Occasionally, exports have glitches that were not present in the session.

7. Tag your metadata.

8. Name the file properly.

9. Back up both the exported file and the Ableton project. Store them in at least two locations.

---

## File Management

This is unglamorous but important. Professional producers have hundreds or thousands of project files, audio exports, stems, and alternate versions. Without a system, you will lose things.

A simple folder structure:

```
Music/
  Projects/
    2026-03-Track_Name/
      Track_Name.als
      Samples/
  Exports/
    Track_Name/
      Track_Name_Mix_v1.wav
      Track_Name_Master_v1.wav
      Track_Name_Master_FINAL.wav
  Stems/
    Track_Name/
      Kick.wav
      Bass.wav
      ...
```

Use "Collect All and Save" in Ableton (File > Collect All and Save) to ensure all samples used in your project are copied into the project folder. This makes your project portable. You can move it to another drive or computer without losing samples.

Date your project folders or use version numbers. "Track_Name_v1," "Track_Name_v2" is clearer than "Track_Name," "Track_Name_new," "Track_Name_new_FINAL," "Track_Name_new_FINAL_2."

Back up your work. External drive, cloud storage, both. Hard drives fail. Laptops get stolen. The only thing worse than losing a track you spent forty hours on is losing it because you did not spend thirty seconds copying it to a backup drive.

---

## Exercises

1. Export a finished track in three formats: WAV 24-bit (for mastering), WAV 16-bit 44100 with dithering (for distribution), and MP3 320 kbps (for sharing). Import all three into a new Ableton session and compare them. Can you hear differences? You probably cannot between the WAVs. You might between the WAV and MP3 on very detailed passages.

2. Export stems for one of your finished tracks. Import them into a new session and verify they align and sum to match your original mix. This is the quality check that confirms your stems are correct.

3. Tag a set of exported files with complete metadata using Kid3 or MP3Tag. Get into the habit now so it is automatic later.

4. Set up a file management system using the folder structure above (or your own variation). Move your existing projects and exports into it. Spend thirty minutes organizing now to save hours of searching later.
