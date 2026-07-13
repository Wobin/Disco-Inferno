local mod = get_mod("Disco Inferno")

local ipairs = ipairs
local pcall = pcall
local math_floor = math.floor
local string_match = string.match
local table_remove = table.remove
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
	self.bag = {}
	self.play_id = nil
	self.sample_id = nil
	self.token = 0
	self.sample_token = 0

	self:rebuild_playlist()
end

DiscoInfernoJukebox.rebuild_playlist = function(self)
	local sa = self.simple_audio

	self.tracks = {}
	self.path_lookup = {}
	self.bag = {}

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

DiscoInfernoJukebox.choose = function(self, rand)
	local count = #self.tracks

	if count == 0 then
		return nil
	end

	if #self.bag == 0 then
		for i = 1, count do
			self.bag[i] = self.tracks[i].file_path
		end
	end

	local n = #self.bag
	local index = 1

	if rand and n > 1 then
		index = math_floor(rand:random_range(1, n + 1))

		if index < 1 then
			index = 1
		elseif index > n then
			index = n
		end
	end

	local key = table_remove(self.bag, index)

	log("jukebox: chose '%s' (%d left in bag)", tostring(key), #self.bag)

	return key
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
		audio_type = "sfx",
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

	self:stop_sample()

	self.sample_token = self.sample_token + 1

	local token = self.sample_token

	local ok, id = pcall(sa.play_file, path, {
		audio_type = "sfx",
		volume = volume or 100,
		on_finished = function()
			if self.sample_token == token then
				self.sample_id = nil
			end
		end,
	})

	if ok then
		self.sample_id = id
	end

	log("jukebox: play_sample '%s' ok=%s id=%s", tostring(path), tostring(ok), tostring(id))

	return id
end

DiscoInfernoJukebox.is_sample_playing = function(self)
	return self.sample_id ~= nil
end

DiscoInfernoJukebox.stop_sample = function(self)
	local sa = self.simple_audio

	if sa and self.sample_id then
		pcall(sa.stop_file, self.sample_id)
		self.sample_id = nil
	end
end

DiscoInfernoJukebox.stop = function(self)
	local sa = self.simple_audio

	if sa and self.play_id then
		pcall(sa.stop_file, self.play_id)
		self.play_id = nil
	end
end

DiscoInfernoJukebox.stop_all = function(self)
	self:stop()
	self:stop_sample()
end

return DiscoInfernoJukebox
