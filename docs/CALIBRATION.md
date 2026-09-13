# Audio calibration

Every installation has its own microphone, loudspeaker placement, room noise
and echo. These settings are sliders in the admin (Settings → Voice activity
detection) and take effect for new conversations; tune them on site with the
real hardware. Each slider shows its value and a reset link back to the default.

For on-site work, sign in to the admin, then open the public page (kiosk mode
included): a **Voice detection** button appears in the bottom-right corner. Its
panel carries the same sliders plus a live speech-probability meter with the two
thresholds marked. Moving a slider changes the running microphone at once, for
this browser only; **Save as default** persists the values for every new
conversation, **Revert** goes back to the saved ones.

## What the settings mean

| Setting | Default | Effect |
| --- | --- | --- |
| `positive_speech_threshold` | 0.5 | Probability above which a 32 ms frame counts as speech. Raise it in noisy rooms or when the loudspeaker triggers the microphone. |
| `negative_speech_threshold` | 0.35 | Probability below which a frame counts as silence. Keep it about 0.15 below the positive threshold. |
| `min_speech_ms` | 250 | Shorter bursts are ignored (coughs, chairs). |
| `redemption_ms` | 600 | Silence tolerated inside an utterance before it is considered finished. Raise it for hesitant speakers, lower it for snappier turns. |
| `pre_speech_pad_ms` | 300 | Audio kept from before the detected start, so first syllables are not cut. |
| `interrupt_min_speech_ms` | 300 | While a character speaks, playback pauses as soon as speech is detected and stops for good only after this much continuous speech. Raise it if the characters get interrupted by noise; lower it if interruptions feel sluggish. |

The browser applies echo cancellation, noise suppression and automatic gain
control through `getUserMedia`; the microphone stays on for the whole session
and the red indicator is always visible while it is live.

## Procedure

1. Sign in to the admin on the installation computer, then open the kiosk URL
   (`/?kiosk=true`) with the real microphone and loudspeakers, open the
   **Voice detection** panel, start a conversation and speak normally from the
   visitor position. Watch the meter: your voice should push it past the red
   mark, silence should stay under the grey one. Confirm the "You're speaking" status appears and
   disappears with your voice and that nothing triggers while you stay silent.
2. Let the characters answer at exhibition volume. If the status flickers to
   "You're speaking" during playback without anyone talking, raise
   `positive_speech_threshold` by 0.05 and `interrupt_min_speech_ms` by 100 ms,
   then repeat.
3. Interrupt a character mid-sentence. The audio should stop within about half
   a second and the transcript should keep only the words that were heard. If
   short interjections are missed, lower `interrupt_min_speech_ms`.
4. Speak with pauses inside a sentence. If your sentence is split into two
   utterances, raise `redemption_ms`; if the characters wait too long after you
   finish, lower it.
5. Check the transcript for cut first syllables and raise `pre_speech_pad_ms`
   if needed.
6. Press **Save as default** in the panel and start a fresh conversation to confirm.
   Note the final values in the installation log; `bin/rails runner
   'puts AppConfig.current.vad_settings'` prints them.
