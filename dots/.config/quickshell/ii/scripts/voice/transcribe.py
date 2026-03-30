#!/usr/bin/env python3
"""
Real-time speech-to-text using faster-whisper + sounddevice.

Output protocol (stdout, line-buffered JSON):
  {"type": "status", "value": "ready"}
  {"type": "status", "value": "stopped"}
  {"type": "status", "value": "loading"}
  {"type": "error",  "message": "..."}
  {"type": "level",  "bars": [0.0..1.0, ...50 values]}
  {"type": "partial","text": "..."}
  {"type": "segment","text": "..."}

Stops cleanly on SIGTERM: flushes last audio buffer, prints final segment.
"""
import sys
import signal
import threading
import queue
import json
import time

# Force line-buffered stdout so SplitParser receives lines immediately
sys.stdout.reconfigure(line_buffering=True)

MODEL_SIZE = sys.argv[1] if len(sys.argv) > 1 else "base"
SAMPLE_RATE   = 16000
BLOCK_FRAMES  = 1600     # 100ms blocks at 16kHz
BARS          = 50       # number of visualizer bars
LEVEL_EMIT_HZ = 15       # target fps for level data
LEVEL_BLOCKS  = max(1, SAMPLE_RATE // BLOCK_FRAMES // LEVEL_EMIT_HZ)
SILENCE_RMS   = 0.015    # RMS threshold below which we consider silence
SILENCE_SEC   = 1.2      # seconds of silence to finalize a segment
PARTIAL_EVERY = 5        # emit a PARTIAL every N speech blocks


def emit(obj: dict):
    print(json.dumps(obj, ensure_ascii=False), flush=True)


def rms(arr) -> float:
    import numpy as np
    return float(np.sqrt(np.mean(arr ** 2))) if arr.size else 0.0


def compute_bars(audio) -> list:
    import numpy as np
    n = len(audio)
    chunk = max(1, n // BARS)
    bars = []
    for i in range(BARS):
        seg = audio[i * chunk : (i + 1) * chunk]
        v = rms(seg) * 12.0
        bars.append(round(min(1.0, v), 4))
    return bars


def main():
    try:
        import numpy as np
        import sounddevice as sd
    except ImportError as e:
        emit({"type": "error", "message": f"missing_dependency: {e}"})
        sys.exit(1)

    emit({"type": "status", "value": "loading"})

    try:
        from faster_whisper import WhisperModel
        model = WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")
    except Exception as e:
        emit({"type": "error", "message": f"model_load: {e}"})
        sys.exit(1)

    audio_q: queue.Queue = queue.Queue()
    stop_evt = threading.Event()

    def on_signal(sig, frame):
        stop_evt.set()

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    # ── audio callback ────────────────────────────────────────────────────
    def audio_callback(indata, frames, ts, status):
        audio_q.put(indata[:, 0].copy())

    # ── transcription helper ──────────────────────────────────────────────
    def transcribe(audio_np) -> str:
        audio_f32 = audio_np.flatten().astype(np.float32)
        if audio_f32.size < SAMPLE_RATE * 0.3:   # skip very short clips
            return ""
        try:
            segs, _ = model.transcribe(
                audio_f32,
                beam_size=5,
                vad_filter=True,
                language=None,
            )
            return " ".join(s.text.strip() for s in segs).strip()
        except Exception:
            return ""

    emit({"type": "status", "value": "ready"})

    accumulated: list  = []   # speech blocks collected since last silence
    level_buf:   list  = []   # recent blocks for level averaging
    silence_blocks     = 0
    speech_blocks      = 0
    blocks_per_silence = max(1, int(SILENCE_SEC * SAMPLE_RATE / BLOCK_FRAMES))

    try:
        with sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype="float32",
            blocksize=BLOCK_FRAMES,
            callback=audio_callback,
        ):
            while not stop_evt.is_set():
                # ── drain the audio queue ─────────────────────────────────
                try:
                    block = audio_q.get(timeout=0.15)
                except queue.Empty:
                    continue

                level_buf.append(block)

                # emit level every LEVEL_BLOCKS blocks
                if len(level_buf) >= LEVEL_BLOCKS:
                    combined = np.concatenate(level_buf)
                    emit({"type": "level", "bars": compute_bars(combined)})
                    level_buf.clear()

                is_speech = rms(block) > SILENCE_RMS

                if is_speech:
                    accumulated.append(block)
                    silence_blocks = 0
                    speech_blocks += 1

                    # emit a PARTIAL every few blocks to show live progress
                    if speech_blocks % PARTIAL_EVERY == 0 and len(accumulated) > 2:
                        partial_audio = np.concatenate(accumulated)
                        text = transcribe(partial_audio)
                        if text:
                            emit({"type": "partial", "text": text})

                elif accumulated:
                    # trailing silence — keep buffering up to the threshold
                    accumulated.append(block)
                    silence_blocks += 1

                    if silence_blocks >= blocks_per_silence:
                        segment_audio = np.concatenate(accumulated)
                        text = transcribe(segment_audio)
                        if text:
                            emit({"type": "segment", "text": text})
                        accumulated.clear()
                        silence_blocks = 0
                        speech_blocks  = 0

    except Exception as e:
        emit({"type": "error", "message": str(e)})
        sys.exit(1)

    # ── flush remaining audio on stop ─────────────────────────────────────
    if accumulated:
        import numpy as np
        segment_audio = np.concatenate(accumulated)
        text = transcribe(segment_audio)
        if text:
            emit({"type": "segment", "text": text})

    emit({"type": "status", "value": "stopped"})


if __name__ == "__main__":
    main()
