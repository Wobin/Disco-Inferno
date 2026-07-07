local mod = get_mod("Disco Inferno")

local ipairs = ipairs
local pcall = pcall
local string_match = string.match
local unit_alive = Unit.alive

local function log(fmt, ...)
	if mod:get("di_debug") then
		mod:info(fmt, ...)
	end
end

local function basename(path)
	return string_match(path, "[^/\\]+$") or path
end

local DiscoInfernoJukebox = class("DiscoInfernoJukebox")

local EXTENSIONS = { "mp3", "ogg", "opus", "wav", "flac", "m4a", "aac", "wma", "mp4", "m4v", "webm", "mkv", "flv", "mov" }

local AUDIO_DIR = "mods/Disco Inferno/audio/"

DiscoInfernoJukebox.init = function(self, simple_audio)
	self.simple_audio = simple_audio
	self.tracks = {}
	self.path_lookup = {}
	self.play_id = nil
	self.token = 0

	self:rebuild_playlist()
end

DiscoInfernoJukebox.rebuild_playlist = function(self)
	local sa = self.simple_audio

	self.tracks = {}
	self.path_lookup = {}

	if not sa then
		return
	end

	for _, ext in ipairs(EXTENSIONS) do
		local pattern = AUDIO_DIR .. "*." .. ext
		local ok, result = pcall(sa.glob, pattern)

		if ok and result then
			local list = result:list()

			log("jukebox: glob '%s' -> %d file(s)", pattern, #list)

			for _, path in ipairs(list) do
				local name = basename(path)

				self.tracks[#self.tracks + 1] = { file_path = name, _path = path }
				self.path_lookup[name] = path
			end
		else
			log("jukebox: glob '%s' -> none (%s)", pattern, tostring(result))
		end
	end

	log("jukebox loaded %d track(s) total", #self.tracks)
end

DiscoInfernoJukebox.get_music = function(self)
	return self.tracks
end

DiscoInfernoJukebox.has_tracks = function(self)
	return #self.tracks > 0
end

DiscoInfernoJukebox.choose = function(self, seed)
	if #self.tracks == 0 then
		return nil
	end

	local index = (seed % #self.tracks) + 1

	return self.tracks[index].file_path
end

DiscoInfernoJukebox.play = function(self, skull_unit, song_key, volume)
	local sa = self.simple_audio

	if not sa then
		log("jukebox: play skipped - no SimpleAudio")
		return
	end

	if #self.tracks == 0 then
		log("jukebox: play skipped - 0 tracks (add audio files to mods/Disco Inferno/audio/)")
		return
	end

	local path = song_key and self.path_lookup[song_key]

	if not path then
		path = self.tracks[1]._path
	end

	self:stop()

	self.token = self.token + 1

	local token = self.token
	local set_position = sa.set_position
	local since_update = 0

	local ok, id = pcall(sa.play_file, path, {
		audio_type = "music",
		volume = volume or 100,
		on_update = set_position and function(pid, dt)
			since_update = since_update + dt

			if since_update < 0.1 then
				return
			end

			since_update = 0

			if unit_alive(skull_unit) then
				pcall(set_position, pid, skull_unit)
			end
		end or nil,
		on_finished = function()
			if self.token == token then
				self.play_id = nil
			end
		end,
	}, skull_unit)

	if ok then
		self.play_id = id
	end

	log("jukebox: play_file '%s' ok=%s id=%s", tostring(path), tostring(ok), tostring(id))

	return id
end

DiscoInfernoJukebox.play_sample = function(self, song_key, volume)
	local sa = self.simple_audio

	if not sa then
		log("jukebox: play_sample skipped - no SimpleAudio")
		return
	end

	local path = song_key and self.path_lookup[song_key]

	if not path then
		log("jukebox: play_sample skipped - unknown song_key '%s'", tostring(song_key))
		return
	end

	local ok, id = pcall(sa.play_file, path, {
		audio_type = "music",
		volume = volume or 100,
		on_finished = function()
			mod.playingSample = nil
		end,
	})

	log("jukebox: play_sample '%s' ok=%s id=%s", tostring(path), tostring(ok), tostring(id))

	if ok then
		return id
	end
end

DiscoInfernoJukebox.stop_sample = function(self, id)
	local sa = self.simple_audio

	if sa and id then
		pcall(sa.stop_file, id)
	end
end

DiscoInfernoJukebox.stop = function(self)
	local sa = self.simple_audio

	if sa and self.play_id then
		pcall(sa.stop_file, self.play_id)
		self.play_id = nil
	end
end

return DiscoInfernoJukebox
