package backend;

import haxe.Json;
import lime.utils.Assets;

import objects.Note;
import states.editors.content.VSlice;
import states.editors.content.VSlice.VSliceChart;
import states.editors.content.VSlice.VSliceMetadata;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;

	// Raw Codename payload retained for HScript compatibility.
	@:optional var codenameChart:Bool;
	@:optional var meta:Dynamic;
	@:optional var strumLines:Array<Dynamic>;
	@:optional var noteTypes:Array<String>;
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psych_v1';

	public static function convert(songJson:Dynamic) // Convert old charts to psych_v1 format
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			if(Reflect.hasField(songJson, 'customEvents'))
			{
				var customEvents:Array<Dynamic> = cast Reflect.field(songJson, 'customEvents');
				for (event in customEvents)
				{
					var params:Array<Dynamic> = event.parameters != null ? cast event.parameters : [];
					var eventName:String = event.name;
					if(eventName == 'onPsychEvent' && params.length > 0)
					{
						eventName = Std.string(params.shift());
					}
					while(params.length < 2) params.push('');
					songJson.events.push([event.time, [[eventName, params[0], params[1]]]]);
				}
			}
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		var sectionsData:Array<SwagSection> = songJson.notes;
		if(sectionsData == null) return;

		for (section in sectionsData)
		{
			var beats:Null<Float> = cast section.sectionBeats;
			if (beats == null || Math.isNaN(beats))
			{
				section.sectionBeats = 4;
				if(Reflect.hasField(section, 'lengthInSteps')) Reflect.deleteField(section, 'lengthInSteps');
			}

			for (note in section.sectionNotes)
			{
				var gottaHitNote:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);

				if(!Std.isOfType(note[3], String))
					note[3] = Note.defaultNoteTypes[note[3]]; //compatibility with Week 7 and 0.1-0.3 psych charts
			}
		}
	}

	public static var chartPath:String;
	public static var loadedSongName:String;
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		PlayState.SONG = getChart(jsonInput, folder);
		loadedSongName = folder;
		chartPath = _lastPath;
		#if windows
		// prevent any saving errors by fixing the path on Windows (being the only OS to ever use backslashes instead of forward slashes for paths)
		chartPath = chartPath.replace('/', '\\');
		#end
		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}

	static var _lastPath:String;
	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		var rawData:String = null;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		_lastPath = Paths.json('$formattedFolder/$formattedSong');

		#if MODS_ALLOWED
		if(FileSystem.exists(_lastPath))
			rawData = File.getContent(_lastPath);
		else if(Assets.exists(_lastPath))
			rawData = Assets.getText(_lastPath);
		#else
		if(Assets.exists(_lastPath))
			rawData = Assets.getText(_lastPath);
		#end

		if(rawData != null)
		{
			var parsed = parseJSON(rawData, jsonInput);
			#if MODS_ALLOWED
			if(parsed != null && (parsed.stage == null || parsed.stage.length < 1))
			{
				var modRoot:String = Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0 ? Paths.mods(Mods.currentModDirectory + '/') : Paths.mods();
				var songConfPath = modRoot + 'song_conf.hx';
				if(FileSystem.exists(songConfPath))
				{
					var stage = CompatData.findYoshiSongStage(File.getContent(songConfPath), folder);
					if(stage != null) parsed.stage = stage;
				}
			}
			#end
			return parsed;
		}

		#if MODS_ALLOWED
		var modRoot:String = Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0 ? Paths.mods(Mods.currentModDirectory + '/') : Paths.mods();
		var codenameChartsDir:String = modRoot + 'songs/' + formattedFolder + '/charts';
		var codenameMetaPath:String = modRoot + 'songs/' + formattedFolder + '/meta.json';
		var codenameMeta:CompatData.CodenameSongMeta = FileSystem.exists(codenameMetaPath) ? cast Json.parse(File.getContent(codenameMetaPath)) : null;
		var codenameDifficulty:String = jsonInput;
		if(jsonInput == formattedFolder && codenameMeta != null && codenameMeta.difficulties != null && codenameMeta.difficulties.length > 0)
		{
			codenameDifficulty = codenameMeta.difficulties.contains('normal') ? 'normal' : codenameMeta.difficulties[0];
		}

		var codenameChartPath:String = codenameChartsDir + '/' + codenameDifficulty + '.json';
		if(!FileSystem.exists(codenameChartPath))
		{
			var caseInsensitiveChart = CompatData.findCaseInsensitiveFile(codenameChartsDir, codenameDifficulty + '.json');
			if(caseInsensitiveChart != null) codenameChartPath = caseInsensitiveChart;
		}
		if(FileSystem.exists(codenameChartPath))
		{
			var chart:Dynamic = Json.parse(File.getContent(codenameChartPath));
			if(chart != null && chart.codenameChart == true)
			{
				_lastPath = codenameChartPath;
				return CompatData.convertCodenameChart(chart, codenameMeta, folder);
			}
		}

		var vsliceSongDir:String = modRoot + 'songs/' + formattedFolder;
		var vsliceChartPath:String = vsliceSongDir + '/' + formattedFolder + '-chart.json';
		var vsliceMetaPath:String = vsliceSongDir + '/' + formattedFolder + '-metadata.json';
		if(!FileSystem.exists(vsliceChartPath))
		{
			var caseInsensitiveVSliceChart = CompatData.findCaseInsensitiveFile(vsliceSongDir, formattedFolder + '-chart.json');
			if(caseInsensitiveVSliceChart != null) vsliceChartPath = caseInsensitiveVSliceChart;
		}
		if(!FileSystem.exists(vsliceMetaPath))
		{
			var caseInsensitiveVSliceMeta = CompatData.findCaseInsensitiveFile(vsliceSongDir, formattedFolder + '-metadata.json');
			if(caseInsensitiveVSliceMeta != null) vsliceMetaPath = caseInsensitiveVSliceMeta;
		}
		if(FileSystem.exists(vsliceChartPath) && FileSystem.exists(vsliceMetaPath))
		{
			var chart:VSliceChart = cast Json.parse(File.getContent(vsliceChartPath));
			var metadata:VSliceMetadata = cast Json.parse(File.getContent(vsliceMetaPath));
			var pack = VSlice.convertToPsych(chart, metadata);
			var difficulty:String = jsonInput;
			if(pack.difficulties.exists(difficulty))
			{
				_lastPath = vsliceChartPath;
				return pack.difficulties.get(difficulty);
			}
		}
		#end
		return null;
	}

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);
		if(Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if(convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if(fmt == null) fmt = songJson.format = 'unknown';

			switch(convertTo)
			{
				case 'psych_v1':
					if(!fmt.startsWith('psych_v1')) //Convert to Psych 1.0 format
					{
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						songJson.format = 'psych_v1_convert';
						convert(songJson);
					}
			}
		}
		return songJson;
	}
}
