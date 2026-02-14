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
      {"-y", "-f", "avfoundation", "-i", ":0", "-ar", "16000", "-ac", "1", tempWav})
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
