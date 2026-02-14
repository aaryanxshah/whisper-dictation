# Whisper Dictation

**Free, local, private voice-to-text for macOS.** Press a hotkey, speak, and your words appear wherever your cursor is. No cloud, no accounts, no subscriptions.

Your audio never leaves your machine. It uses [Whisper.cpp](https://github.com/ggerganov/whisper.cpp) (OpenAI's speech recognition running locally), [FFmpeg](https://ffmpeg.org/) (audio capture), and [Hammerspoon](https://www.hammerspoon.org/) (global hotkey + menu bar indicator).

Works in any app -- your terminal, browser, Slack, Notes, VS Code, anything with a text cursor.

## Usage

| Action | What Happens |
|---|---|
| Press **Option + V** | Recording starts. Menu bar shows **REC** |
| Speak naturally | Your Mac is listening locally |
| Press **Option + V** again | Recording stops. Menu bar shows **...** while transcribing |
| Wait ~1-2 seconds | Your spoken text is typed at your cursor |

## Quick Setup with Claude Code

You'll need [Homebrew](https://brew.sh) and [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed. Then open your terminal, launch Claude Code, and paste this prompt:

```
Set up local voice-to-text on my Mac using Hammerspoon, whisper-cpp, and ffmpeg.

1. Install dependencies:
   brew install whisper-cpp ffmpeg
   brew install --cask hammerspoon

2. Download the Whisper model:
   mkdir -p ~/.whisper
   curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" -o ~/.whisper/ggml-base.en.bin

3. Find my microphone device number:
   ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -A10 "audio devices"
   Use the correct device number (usually :0 or :1) in the config below.

4. Create ~/.hammerspoon/init.lua with this exact config (replace DEVICE_NUMBER with the number from step 3):

-- Voice-to-text with Option+V
local voiceTask = nil
local isRecording = false
local tempWav = "/tmp/voice_input.wav"
local whisperModel = os.getenv("HOME") .. "/.whisper/ggml-base.en.bin"

local menubar = hs.menubar.new()
menubar:setTitle("")

local function updateMenubar(state)
  if state == "recording" then
    menubar:setTitle("REC")
  elseif state == "transcribing" then
    menubar:setTitle("...")
  else
    menubar:setTitle("")
  end
end

hs.hotkey.bind({"alt"}, "v", function()
  if not isRecording then
    isRecording = true
    updateMenubar("recording")

    voiceTask = hs.task.new("/opt/homebrew/bin/ffmpeg", function() end,
      {"-y", "-f", "avfoundation", "-i", ":DEVICE_NUMBER", "-ar", "16000", "-ac", "1", tempWav})
    voiceTask:start()
  else
    isRecording = false
    updateMenubar("transcribing")

    if voiceTask then
      voiceTask:terminate()
      voiceTask = nil
    end

    hs.timer.doAfter(0.5, function()
      local whisperTask = hs.task.new("/opt/homebrew/bin/whisper-cli", function(exitCode, stdOut, stdErr)
        updateMenubar("")
        local result = stdOut:gsub("%[.*%]", ""):gsub("\n", " "):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
        if result and result ~= "" then
          hs.eventtap.keyStrokes(result)
        end
        os.remove(tempWav)
      end, {"-m", whisperModel, "-f", tempWav, "--no-timestamps"})
      whisperTask:start()
    end)
  end
end)

5. Open Hammerspoon:
   open /Applications/Hammerspoon.app

6. Reset microphone permissions so macOS prompts for access:
   tccutil reset Microphone org.hammerspoon.Hammerspoon

After setup, tell me to reload Hammerspoon config and test with Option+V.
```

Claude Code will install everything, detect your microphone, and write the config automatically.

## Manual Setup

### Prerequisites

- macOS (Apple Silicon or Intel)
- [Homebrew](https://brew.sh)

### 1. Install dependencies

```bash
brew install whisper-cpp ffmpeg
brew install --cask hammerspoon
```

### 2. Download the Whisper model

```bash
mkdir -p ~/.whisper
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" \
  -o ~/.whisper/ggml-base.en.bin
```

### 3. Find your microphone device number

```bash
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -A10 "audio devices"
```

Note the number next to your microphone (e.g., `[0] MacBook Pro Microphone` means device `:0`).

### 4. Install the config

```bash
git clone https://github.com/aaryanxshah/whisper-dictation.git
mkdir -p ~/.hammerspoon
cp whisper-dictation/init.lua ~/.hammerspoon/init.lua
```

Edit `~/.hammerspoon/init.lua` and replace `:0` in the `-i` argument with your device number from step 3 if different.

### 5. Launch and grant permissions

```bash
open /Applications/Hammerspoon.app
```

macOS will ask you to grant two permissions:

1. **Accessibility** -- System Settings > Privacy & Security > Accessibility > toggle Hammerspoon on
2. **Microphone** -- Should prompt on first use of Option+V. If not, run:
   ```bash
   tccutil reset Microphone org.hammerspoon.Hammerspoon
   ```
   Then reload config from the Hammerspoon menu bar icon and try Option+V again.

### 6. Reload and use

Click the Hammerspoon menu bar icon > **Reload Config**. Press **Option+V** to start recording.

## Troubleshooting

| Problem | Fix |
|---|---|
| "REC" shows but no text appears | Microphone permission not granted. Check System Settings > Privacy & Security > Microphone |
| Wrong microphone | Re-run the device list command in step 3 and update the `:0` in init.lua |
| Option+V doesn't respond | Accessibility permission not granted for Hammerspoon |
| Slow or inaccurate transcription | Download a larger model: replace `ggml-base.en.bin` with `ggml-medium.en.bin` in both the curl command and init.lua |

## How It Works

1. **Option+V** triggers Hammerspoon's hotkey listener
2. Hammerspoon spawns `ffmpeg` to record from your microphone to a temp WAV file
3. **Option+V** again stops recording and spawns `whisper-cli` to transcribe the WAV
4. The transcribed text is typed at your cursor using `hs.eventtap.keyStrokes`
5. The temp file is deleted

Everything runs locally. Zero network calls.

## License

MIT
