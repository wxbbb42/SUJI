# SUJI ambience audio provenance

The calm-space ambience is original procedural synthesis implemented in
`native/App/Services/AmbienceAudio.swift`. SUJI does not bundle, download, or
stream field recordings for these sounds. The UI therefore calls them “合成音景”
(synthesized ambience), rather than claiming that they were recorded in nature.

The four layers are generated in real time at 44.1 kHz:

- **Rain** — high-passed pseudo-random noise with short stochastic decay
  envelopes for individual droplets.
- **Stream** — filtered noise amplitude-modulated by two inharmonic sine
  oscillators to create continuously changing water shimmer.
- **Wind** — strongly low-passed pseudo-random noise under a slow sinusoidal
  gust envelope.
- **Fire** — low-passed noise with sparse, rapidly decaying stochastic crackle
  envelopes.

The xorshift noise generator, filters, oscillators, envelopes and mix values in
the source file were authored for this project. They use no third-party audio
samples or copyrighted recording material, so there is no external sample
license or attribution requirement.

Audio uses an `AVAudioSession` playback category with mixing enabled. The app
target must include the Audio background mode for continuous background
playback on device. Audio quality and interruption behavior still require a
physical-device review; simulator playback only proves signal routing and UI
state.
