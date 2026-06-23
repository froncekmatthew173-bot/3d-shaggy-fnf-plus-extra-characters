package backend;

import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import haxe.Json;
import haxe.xml.Access;

typedef WeekFile =
{
	// JSON variables
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
}

class WeekData {
	public static var weeksLoaded:Map<String, WeekData> = new Map<String, WeekData>();
	public static var weeksList:Array<String> = [];
	public var folder:String = '';

	// JSON variables
	public var songs:Array<Dynamic>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:String;

	public var fileName:String;

	public static function createWeekFile():WeekFile {
		var weekFile:WeekFile = {
			songs: [["Bopeebo", "face", [146, 113, 253]], ["Fresh", "face", [146, 113, 253]], ["Dad Battle", "face", [146, 113, 253]]],
			#if BASE_GAME_FILES
			weekCharacters: ['dad', 'bf', 'gf'],
			#else
			weekCharacters: ['bf', 'bf', 'gf'],
			#end
			weekBackground: 'stage',
			weekBefore: 'tutorial',
			storyName: 'Your New Week',
			weekName: 'Custom Week',
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: false,
			hideFreeplay: false,
			difficulties: ''
		};
		return weekFile;
	}

	// HELP: Is there any way to convert a WeekFile to WeekData without having to put all variables there manually? I'm kind of a noob in haxe lmao
	public function new(weekFile:WeekFile, fileName:String) {
		// here ya go - MiguelItsOut
		for (field in Reflect.fields(weekFile))
			if(Reflect.fields(this).contains(field)) // Reflect.hasField() won't fucking work :/
				Reflect.setProperty(this, field, Reflect.getProperty(weekFile, field));

		this.fileName = fileName;
	}

	public static function reloadWeekFiles(isStoryMode:Null<Bool> = false)
	{
		weeksList = [];
		weeksLoaded.clear();
		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods(), Paths.getSharedPath()];
		var originalLength:Int = directories.length;

		for (mod in Mods.parseList().enabled)
			directories.push(Paths.mods(mod + '/'));
		#else
		var directories:Array<String> = [Paths.getSharedPath()];
		var originalLength:Int = directories.length;
		#end

		var sexList:Array<String> = CoolUtil.coolTextFile(Paths.getSharedPath('weeks/weekList.txt'));
		for (i in 0...sexList.length) {
			for (j in 0...directories.length) {
				var fileToCheck:String = directories[j] + 'weeks/' + sexList[i] + '.json';
				if(!weeksLoaded.exists(sexList[i])) {
					var week:WeekFile = getWeekFile(fileToCheck);
					if(week != null) {
						var weekFile:WeekData = new WeekData(week, sexList[i]);

						#if MODS_ALLOWED
						if(j >= originalLength) {
							weekFile.folder = directories[j].substring(Paths.mods().length, directories[j].length-1);
						}
						#end

						if(weekFile != null && (isStoryMode == null || (isStoryMode && !weekFile.hideStoryMode) || (!isStoryMode && !weekFile.hideFreeplay))) {
							weeksLoaded.set(sexList[i], weekFile);
							weeksList.push(sexList[i]);
						}
					}
				}
			}
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i] + 'weeks/';
			if(FileSystem.exists(directory)) {
				var listOfWeeks:Array<String> = CoolUtil.coolTextFile(directory + 'weekList.txt');
				for (daWeek in listOfWeeks)
				{
					var path:String = directory + daWeek + '.json';
					if(FileSystem.exists(path))
					{
						addWeek(daWeek, path, directories[i], i, originalLength);
					}
				}

				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						addWeek(file.substr(0, file.length - 5), path, directories[i], i, originalLength);
					}
				}
			}
		}

		for (mod in Mods.parseList().enabled)
		{
			var codenameList:String = Paths.mods(mod + '/data/config/freeplaySonglist.txt');
			if(!FileSystem.exists(codenameList))
				codenameList = Paths.mods(mod + '/data/freeplaySonglist.txt');
			if(FileSystem.exists(codenameList))
				addCodenameFreeplayWeek(mod, codenameList);

			var daveList:String = Paths.mods(mod + '/data/freeplaySonglist.json');
			if(FileSystem.exists(daveList))
				addDaveFreeplayWeek(mod, daveList);

			var codenameWeeksList:String = Paths.mods(mod + '/data/weeks/weeks.txt');
			if(FileSystem.exists(codenameWeeksList))
				addCodenameXmlWeeks(mod, codenameWeeksList);
		}
		#end
	}

	private static function addDaveFreeplayWeek(mod:String, listPath:String)
	{
		var raw:Dynamic = Json.parse(File.getContent(listPath));
		if(raw == null || raw.songs == null) return;
		var songs:Array<Dynamic> = [];
		for (song in cast(raw.songs, Array<Dynamic>))
		{
			if(song.name == null) continue;
			songs.push([
				song.displayName != null ? song.displayName : song.name,
				song.char != null ? song.char : 'face',
				backend.CompatData.parseColor(song.color != null ? song.color : '#9271FD')
			]);
		}
		if(songs.length < 1) return;

		var key = 'compat_' + mod + '_dave';
		if(weeksLoaded.exists(key)) return;
		var week:WeekFile = createWeekFile();
		week.songs = songs;
		week.storyName = mod;
		week.weekName = mod;
		week.hideStoryMode = true;
		week.hideFreeplay = false;
		var data = new WeekData(week, key);
		data.folder = mod;
		weeksLoaded.set(key, data);
		weeksList.push(key);
	}

	private static function addCodenameFreeplayWeek(mod:String, listPath:String)
	{
		var songs:Array<Dynamic> = [];
		var difficulties:Array<String> = [];
		for (song in CoolUtil.coolTextFile(listPath))
		{
			var folder = Paths.formatToSongPath(song);
			var metaPath = Paths.mods(mod + '/songs/' + folder + '/meta.json');
			if(!FileSystem.exists(metaPath)) continue;
			var meta:Dynamic = Json.parse(File.getContent(metaPath));
			var color = backend.CompatData.parseColor(meta.color != null ? meta.color : '#9271FD');
			// Keep the real folder/chart id in slot 0; Psych also uses this field to load the chart.
			songs.push([song, meta.icon != null ? meta.icon : 'face', color]);
			if(meta.difficulties != null)
			{
				for (difficulty in cast(meta.difficulties, Array<Dynamic>))
				{
					var diff = compatDifficultyName(Std.string(difficulty));
					if(!difficulties.contains(diff))
						difficulties.push(diff);
				}
			}
		}
		if(songs.length < 1) return;

		var key = 'compat_' + mod;
		if(weeksLoaded.exists(key)) return;
		var week:WeekFile = createWeekFile();
		week.songs = songs;
		week.storyName = mod;
		week.weekName = mod;
		week.hideStoryMode = true;
		week.hideFreeplay = false;
		if(difficulties.length > 0)
			week.difficulties = difficulties.join(',');
		var data = new WeekData(week, key);
		data.folder = mod;
		weeksLoaded.set(key, data);
		weeksList.push(key);
	}

	private static function addCodenameXmlWeeks(mod:String, listPath:String)
	{
		for (weekName in CoolUtil.coolTextFile(listPath))
		{
			var xmlPath = Paths.mods(mod + '/data/weeks/weeks/' + weekName + '.xml');
			if(!FileSystem.exists(xmlPath)) continue;

			try
			{
				var xml = new Access(Xml.parse(File.getContent(xmlPath)).firstElement());
				var root = xml.name == 'week' ? xml : xml.node.week;
				var songs:Array<Dynamic> = [];
				for (songNode in root.nodes.song)
				{
					var songName:String = songNode.innerData.trim();
					if(songName.length < 1) continue;
					var folder = Paths.formatToSongPath(songName);
					var metaPath = Paths.mods(mod + '/songs/' + folder + '/meta.json');
					var icon = root.has.chars ? root.att.chars.split(',')[0] : 'face';
					var color = root.has.bgColor ? backend.CompatData.parseColor(root.att.bgColor) : [146, 113, 253];
					if(FileSystem.exists(metaPath))
					{
						var meta:Dynamic = Json.parse(File.getContent(metaPath));
						// Keep the real folder/chart id in slot 0; Psych also uses this field to load the chart.
						songs.push([songName, meta.icon != null ? meta.icon : icon, meta.color != null ? backend.CompatData.parseColor(meta.color) : color]);
					}
					else songs.push([songName, icon, color]);
				}
				if(songs.length < 1) continue;

				var key = 'compat_' + mod + '_week_' + weekName;
				if(weeksLoaded.exists(key)) continue;
				var week:WeekFile = createWeekFile();
				week.songs = songs;
				week.storyName = root.has.name ? root.att.name : weekName;
				week.weekName = root.has.name ? root.att.name : weekName;
				week.hideStoryMode = false;
				week.hideFreeplay = false;
				var diffs:Array<String> = [];
				for (difficulty in root.nodes.difficulty)
					if(difficulty.has.name)
						diffs.push(compatDifficultyName(difficulty.att.name));
				if(diffs.length > 0) week.difficulties = diffs.join(',');

				var data = new WeekData(week, key);
				data.folder = mod;
				weeksLoaded.set(key, data);
				weeksList.push(key);
			}
			catch(e:Dynamic)
				trace('Error loading Codename week "$weekName" from "$mod": $e');
		}
	}

	private static function compatDifficultyName(name:String):String
	{
		if(name == null || name.length < 1) return name;
		name = Paths.formatToSongPath(name);
		return name.charAt(0).toUpperCase() + name.substr(1);
	}

	private static function addWeek(weekToCheck:String, path:String, directory:String, i:Int, originalLength:Int)
	{
		if(!weeksLoaded.exists(weekToCheck))
		{
			var week:WeekFile = getWeekFile(path);
			if(week != null)
			{
				var weekFile:WeekData = new WeekData(week, weekToCheck);
				if(i >= originalLength)
				{
					#if MODS_ALLOWED
					weekFile.folder = directory.substring(Paths.mods().length, directory.length-1);
					#end
				}
				if((PlayState.isStoryMode && !weekFile.hideStoryMode) || (!PlayState.isStoryMode && !weekFile.hideFreeplay))
				{
					weeksLoaded.set(weekToCheck, weekFile);
					weeksList.push(weekToCheck);
				}
			}
		}
	}

	private static function getWeekFile(path:String):WeekFile {
		var rawJson:String = null;
		#if MODS_ALLOWED
		if(FileSystem.exists(path)) {
			rawJson = File.getContent(path);
		}
		#else
		if(OpenFlAssets.exists(path)) {
			rawJson = Assets.getText(path);
		}
		#end

		if(rawJson != null && rawJson.length > 0) {
			return cast tjson.TJSON.parse(rawJson);
		}
		return null;
	}

	//   FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE

	//To use on PlayState.hx or Highscore stuff
	public static function getWeekFileName():String {
		return weeksList[PlayState.storyWeek];
	}

	//Used on LoadingState, nothing really too relevant
	public static function getCurrentWeek():WeekData {
		return weeksLoaded.get(weeksList[PlayState.storyWeek]);
	}

	public static function setDirectoryFromWeek(?data:WeekData = null) {
		Mods.currentModDirectory = '';
		if(data != null && data.folder != null && data.folder.length > 0) {
			Mods.currentModDirectory = data.folder;
		}
	}
}
