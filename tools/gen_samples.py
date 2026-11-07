"""Generate placeholder one-shots so BeatGo plays out of the box.
Run: python3 tools/gen_samples.py  (writes to assets/samples/)
These are stand-ins; real samples come from the phone's library."""
import numpy as np, wave, os
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "samples")

def write(name, x):
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def env(n, a, d):
    t = np.arange(n) / SR
    return np.minimum(t / a, 1) * np.exp(-t / d)

def noise(n): return np.random.uniform(-1, 1, n)

n = int(SR * 0.5); t = np.arange(n) / SR
# kick: pitch sweep 150->45 Hz
f = 45 + 105 * np.exp(-t * 28)
write("kick.wav", np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.001, 0.13) * 0.95)
# clap: 3 noise bursts + tail
clap = np.zeros(n)
for off in (0, 0.012, 0.024):
    i = int(off * SR); m = n - i
    clap[i:] += noise(m) * env(m, 0.0005, 0.012)
clap += noise(n) * env(n, 0.03, 0.08) * 0.6
b, a = np.array([1, -1]), None
write("clap.wav", np.convolve(clap, [1, -0.6])[:n] * 0.7)
# closed hat
n2 = int(SR * 0.12)
write("hat_closed.wav", np.convolve(noise(n2), [1, -0.95])[:n2] * env(n2, 0.0005, 0.02) * 0.6)
# open hat
n3 = int(SR * 0.4)
write("hat_open.wav", np.convolve(noise(n3), [1, -0.95])[:n3] * env(n3, 0.0005, 0.12) * 0.5)
# shaker
n4 = int(SR * 0.1)
write("shaker.wav", np.convolve(noise(n4), [1, -0.98])[:n4] * env(n4, 0.008, 0.025) * 0.5)
# bass: one note at C1 (32.7 Hz) saw+sub, 1.2 s, for pitching
n5 = int(SR * 1.2); t5 = np.arange(n5) / SR; f0 = 32.703
saw = 2 * ((t5 * f0) % 1) - 1
sub = np.sin(2 * np.pi * f0 * t5)
# crude lowpass by moving average
lp = np.convolve(saw, np.ones(40) / 40, mode="same")
write("bass_c1.wav", (lp * 0.6 + sub * 0.5) * env(n5, 0.004, 0.9) * 0.8)
print("ok")

# pad: detuned saws at C3, slow attack, for the Chords channel
n6 = int(SR * 2.0); t6 = np.arange(n6) / SR; fc = 130.81
def saw(f): return 2 * ((t6 * f) % 1) - 1
pad = saw(fc) + saw(fc * 1.003) + saw(fc * 0.997) + 0.5 * saw(fc * 2.002)
pad = np.convolve(pad, np.ones(24) / 24, mode="same")
pad = pad * np.minimum(t6 / 0.08, 1) * np.exp(-t6 / 1.6)
write("pad_c3.wav", pad / np.max(np.abs(pad)) * 0.6)
