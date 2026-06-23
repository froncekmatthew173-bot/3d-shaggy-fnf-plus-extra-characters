package backend;

import haxe.Json;
import haxe.xml.Access;
import backend.Song.SwagSong;
import backend.Song.SwagSection;
import backend.StageData.StageFile;

typedef CodenameSongMeta =
{
	var bpm:Float;
	var displayName:String;
	var icon:String;
	var color:String;
	var needsVoices:Bool;
	var difficulties:Array<String>;
	@:optional var customValues:Dynamic;
}

class CompatData
{
	public static function findCaseInsensitiveFile(folder:String, fileName:String):String
	{
		if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return null;
		var wanted = fileName.toLowerCase();
		for (entry in FileSystem.readDirectory(folder))
			if(entry.toLowerCase() == wanted)
				return folder + '/' + entry;
		return null;
	}

	public static function convertCodenameChart(chart:Dynamic, meta:CodenameSongMeta, songId:String):SwagSong
	{
		var songBpm:Float = meta != null ? meta.bpm : 100;
		var sectionLength:Float = Conductor.calculateCrochet(songBpm) * 4;
		var lastTime:Float = 0;
		var player1:String = 'bf';
		var player2:String = 'dad';
		var gfVersion:String = 'gf';
		var keyCountChanges:Array<Array<Dynamic>> = [[-999999, 4]];
		if(chart.events != null)
			for(event in cast(chart.events, Array<Dynamic>))
				if((event.name == 'Set Key Count' || event.name == 'Change Key Count') && event.params != null && event.params.length > 0)
					keyCountChanges.push([event.time, Std.int(event.params[0])]);
		keyCountChanges.sort(function(a, b) return a[0] < b[0] ? -1 : (a[0] > b[0] ? 1 : 0));

		for (line in cast(chart.strumLines, Array<Dynamic>))
		{
			if(line.position == 'boyfriend' && line.characters != null && line.characters.length > 0) player1 = line.characters[0];
			if(line.position == 'dad' && line.characters != null && line.characters.length > 0) player2 = line.characters[0];
			if(line.position == 'girlfriend' && line.characters != null && line.characters.length > 0) gfVersion = line.characters[0];
			for (note in cast(line.notes, Array<Dynamic>))
			{
				var noteEnd:Float = note.time + (note.sLen != null ? note.sLen : 0);
				if(noteEnd > lastTime) lastTime = noteEnd;
			}
		}

		var sections:Array<SwagSection> = [];
		var sectionCount:Int = Std.int(Math.ceil(lastTime / sectionLength)) + 1;
		for (i in 0...sectionCount)
		{
			sections.push({
				sectionNotes: [],
				sectionBeats: 4,
				mustHitSection: false
			});
		}

		for (line in cast(chart.strumLines, Array<Dynamic>))
		{
			var isPlayer:Bool = line.position == 'boyfriend' || line.type == 1;
			for (note in cast(line.notes, Array<Dynamic>))
			{
				var sec:Int = Std.int(Math.floor(note.time / sectionLength));
				while(sec >= sections.length)
					sections.push({sectionNotes: [], sectionBeats: 4, mustHitSection: false});

				var noteKeyCount:Int = 4;
				for(change in keyCountChanges)
					if(note.time >= change[0]) noteKeyCount = change[1];
				var noteData:Int = note.id;
				var noteType:Dynamic = null;
				if(chart.noteTypes != null && note.type != null && note.type > 0 && Std.int(note.type) - 1 < chart.noteTypes.length)
					noteType = chart.noteTypes[Std.int(note.type) - 1];

				var psychNote:Array<Dynamic> = [note.time, noteData, note.sLen != null ? note.sLen : 0];
				if(noteType != null) psychNote.push(noteType);
				else psychNote.push('');
				psychNote.push(isPlayer);
				psychNote.push(noteKeyCount);
				sections[sec].sectionNotes.push(psychNote);
			}
		}

		var events:Array<Dynamic> = [];
		if(chart.events != null)
		{
			for (event in cast(chart.events, Array<Dynamic>))
			{
				var params:Array<Dynamic> = event.params != null ? cast event.params : [];
				while(params.length < 2) params.push('');
				var eventName:String = Std.string(event.name);
				var value1:String = Std.string(params[0]);
				var value2:String = Std.string(params[1]);

				// Keep common Codename built-ins useful after conversion instead of
				// blindly dropping every parameter after the second one.
				switch(eventName)
				{
					case 'Play Animation':
						// Codename: [character, animation, forced]
						// Psych:    [animation, character]
						value1 = Std.string(params.length > 1 ? params[1] : '');
						value2 = Std.string(params[0]);
					case 'Camera Flash':
						// Codename: [reversed, color, timeSteps, camera]
						value1 = [Std.string(params[0]), Std.string(params.length > 1 ? params[1] : '#FFFFFF')].join(',');
						value2 = [Std.string(params.length > 2 ? params[2] : 0), Std.string(params.length > 3 ? params[3] : 'camGame')].join(',');
					case 'Scroll Speed Change':
						// Codename: [tween, speed, timeSteps, ease, type]
						value1 = Std.string(params.length > 1 ? params[1] : params[0]);
						value2 = [
							Std.string(params[0]),
							Std.string(params.length > 2 ? params[2] : 0),
							Std.string(params.length > 3 ? params[3] : 'linear'),
							Std.string(params.length > 4 ? params[4] : '')
						].join(',');
				}

				// Psych's chart schema only has two string value slots, but Codename
				// custom events may define any number of typed params. Preserve the
				// original payload as a fourth internal field so HScript event scripts
				// still receive the full `event.event.params` array at runtime.
				events.push([event.time, [[eventName, value1, value2, params.copy()]]]);
			}
		}

		var compatMeta:Dynamic = meta != null ? Reflect.copy(meta) : {};
		if(!Reflect.hasField(compatMeta, 'name'))
			Reflect.setField(compatMeta, 'name', meta != null && meta.displayName != null ? meta.displayName : songId);
		if(!Reflect.hasField(compatMeta, 'customValues') || Reflect.field(compatMeta, 'customValues') == null)
			Reflect.setField(compatMeta, 'customValues', {});

		return {
			song: meta != null && meta.displayName != null ? meta.displayName : songId,
			notes: sections,
			events: events,
			bpm: songBpm,
			needsVoices: meta == null || meta.needsVoices != false,
			speed: chart.scrollSpeed != null ? chart.scrollSpeed : 1,
			offset: 0,
			player1: player1,
			player2: player2,
			gfVersion: gfVersion,
			stage: chart.stage != null ? chart.stage : 'stage',
			format: 'codename_convert',
			arrowSkin: chart.stage == '3d' ? 'game/notes/3d' : null,
			codenameChart: true,
			meta: compatMeta,
			strumLines: chart.strumLines != null ? chart.strumLines : [],
			noteTypes: chart.noteTypes != null ? chart.noteTypes : []
		};
	}

	public static function convertCodenameCharacter(rawXml:String):Dynamic
	{
		var xml = new Access(Xml.parse(rawXml).firstElement());
		var root = xml.name == 'character' ? xml : xml.node.character;
		var anims:Array<Dynamic> = [];
		for (anim in root.nodes.anim)
		{
			var indices:Array<Int> = [];
			if(anim.has.indices)
			{
				var raw = anim.att.indices;
				if(raw.indexOf('..') > -1)
				{
					var split = raw.split('..');
					var start = Std.parseInt(split[0]);
					var end = Std.parseInt(split[1]);
					if(start != null && end != null)
						for (i in start...(end + 1)) indices.push(i);
				}
			}
			anims.push({
				anim: anim.att.name,
				name: anim.att.anim,
				fps: anim.has.fps ? Std.parseInt(anim.att.fps) : 24,
				loop: anim.has.loop && anim.att.loop == 'true',
				indices: indices,
				offsets: [
					anim.has.x ? Std.int(Std.parseFloat(anim.att.x)) : 0,
					anim.has.y ? Std.int(Std.parseFloat(anim.att.y)) : 0
				]
			});
		}

		return {
			animations: anims,
			image: root.att.sprite,
			scale: root.has.scale ? Std.parseFloat(root.att.scale) : 1,
			sing_duration: 4,
			healthicon: root.has.icon ? root.att.icon : root.att.sprite,
			position: [
				root.has.x ? Std.parseFloat(root.att.x) : 0,
				root.has.y ? Std.parseFloat(root.att.y) : 0
			],
			camera_position: [
				root.has.camx ? Std.parseFloat(root.att.camx) : 0,
				root.has.camy ? Std.parseFloat(root.att.camy) : 0
			],
			flip_x: root.has.flipX && root.att.flipX == 'true',
			no_antialiasing: false,
			healthbar_colors: parseColor(root.has.color ? root.att.color : '#A1A1A1'),
			vocals_file: '',
			_editor_isPlayer: root.has.isPlayer && root.att.isPlayer == 'true'
		};
	}

	public static function convertFolderCharacter(rawJson:String, character:String):Dynamic
	{
		var json:Dynamic = Json.parse(rawJson);
		var anims:Array<Dynamic> = [];
		for (anim in cast(json.anims, Array<Dynamic>))
		{
			anims.push({
				anim: anim.name,
				name: anim.anim,
				fps: anim.framerate != null ? anim.framerate : 24,
				loop: anim.loop == true,
				indices: anim.indices != null ? anim.indices : [],
				offsets: [
					anim.x != null ? Std.int(anim.x) : 0,
					anim.y != null ? Std.int(anim.y) : 0
				]
			});
		}

		var color = json.healthbarColor != null ? json.healthbarColor : '#A1A1A1';
		return {
			animations: anims,
			image: '../characters/' + character + '/spritesheet',
			scale: json.scale != null ? json.scale : 1,
			sing_duration: 4,
			healthicon: '../characters/' + character + '/icon',
			position: [
				json.globalOffset != null ? json.globalOffset.x : 0,
				json.globalOffset != null ? json.globalOffset.y : 0
			],
			camera_position: [
				json.camOffset != null ? json.camOffset.x : 0,
				json.camOffset != null ? json.camOffset.y : 0
			],
			flip_x: json.flipX == true,
			no_antialiasing: json.antialiasing == false,
			healthbar_colors: parseColor(color),
			vocals_file: ''
		};
	}

	public static function convertYoshiCharacter(rawHx:String, character:String):Dynamic
	{
		var anims:Array<Dynamic> = [];
		var offsets:Map<String, Array<Int>> = [];
		var originalHx = rawHx;

		var animRegex = ~/character\.animation\.addByPrefix\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]+)['"]\s*,\s*([0-9]+)\s*,\s*(true|false)\s*\)/g;
		while(animRegex.match(rawHx))
		{
			var animName = animRegex.matched(1);
			anims.push({
				anim: animName,
				name: animRegex.matched(2),
				fps: Std.parseInt(animRegex.matched(3)),
				loop: animRegex.matched(4) == 'true',
				indices: [],
				offsets: [0, 0]
			});
			rawHx = animRegex.matchedRight();
		}

		var offsetSource = originalHx;
		var offsetRegex = ~/character\.addOffset\(\s*['"]([^'"]+)['"]\s*,\s*(-?[0-9]+)\s*,\s*(-?[0-9]+)\s*\)/g;
		while(offsetRegex.match(offsetSource))
		{
			offsets.set(offsetRegex.matched(1), [Std.parseInt(offsetRegex.matched(2)), Std.parseInt(offsetRegex.matched(3))]);
			offsetSource = offsetRegex.matchedRight();
		}

		for (anim in anims)
			if(offsets.exists(anim.anim))
				anim.offsets = offsets.get(anim.anim);

		return {
			animations: anims,
			image: '../characters/' + character + '/spritesheet',
			scale: 1,
			sing_duration: 4,
			healthicon: '../characters/' + character + '/icon',
			position: [0, 0],
			camera_position: [0, 0],
			flip_x: false,
			no_antialiasing: false,
			healthbar_colors: [161, 161, 161],
			vocals_file: ''
		};
	}

	public static function findYoshiSongStage(rawHx:String, songName:String):String
	{
		var normalized = songName.toLowerCase();
		var caseRegex = ~/case\s+["']([^"']+)["']\s*:\s*([\s\S]*?)(?=case\s+["']|$)/g;
		while(caseRegex.match(rawHx))
		{
			if(caseRegex.matched(1).toLowerCase() == normalized)
			{
				var block = caseRegex.matched(2);
				var stageRegex = ~/stage\s*=\s*["']([^"']+)["']/;
				if(stageRegex.match(block))
					return stageRegex.matched(1);
			}
			rawHx = caseRegex.matchedRight();
		}
		return null;
	}

	public static function convertCodenameStage(rawXml:String):StageFile
	{
		var xml = new Access(Xml.parse(rawXml).firstElement());
		var root = xml.name == 'stage' ? xml : xml.node.stage;
		var folder:String = root.has.folder ? root.att.folder : '';
		var objects:Array<Dynamic> = [];

		for (sprite in root.nodes.sprite)
		{
			var image:String = sprite.att.sprite;
			if(folder.length > 0 && image.indexOf('/') < 0)
				image = folder + image;
			objects.push({
				type: 'sprite',
				name: sprite.has.name ? sprite.att.name : image,
				image: image,
				x: sprite.has.x ? Std.parseFloat(sprite.att.x) : 0,
				y: sprite.has.y ? Std.parseFloat(sprite.att.y) : 0,
				scroll: [
					sprite.has.scrollx ? Std.parseFloat(sprite.att.scrollx) : (sprite.has.scroll ? Std.parseFloat(sprite.att.scroll) : 1),
					sprite.has.scrolly ? Std.parseFloat(sprite.att.scrolly) : (sprite.has.scroll ? Std.parseFloat(sprite.att.scroll) : 1)
				],
				scale: [
					sprite.has.scalex ? Std.parseFloat(sprite.att.scalex) : (sprite.has.scale ? Std.parseFloat(sprite.att.scale) : 1),
					sprite.has.scaley ? Std.parseFloat(sprite.att.scaley) : (sprite.has.scale ? Std.parseFloat(sprite.att.scale) : 1)
				],
				color: '#FFFFFF',
				alpha: sprite.has.alpha ? Std.parseFloat(sprite.att.alpha) : 1,
				antialiasing: !sprite.has.antialiasing || sprite.att.antialiasing != 'false',
				filters: 0
			});
		}

		function readActor(actor:Access, fallback:Array<Float>):Array<Float>
		{
			return [
				actor.has.x ? Std.parseFloat(actor.att.x) : fallback[0],
				actor.has.y ? Std.parseFloat(actor.att.y) : fallback[1]
			];
		}

		var boyfriendPos = root.hasNode.boyfriend ? readActor(root.node.boyfriend, [770.0, 100.0]) : (root.hasNode.bf ? readActor(root.node.bf, [770.0, 100.0]) : [770.0, 100.0]);
		var girlfriendPos = root.hasNode.girlfriend ? readActor(root.node.girlfriend, [400.0, 130.0]) : (root.hasNode.gf ? readActor(root.node.gf, [400.0, 130.0]) : [400.0, 130.0]);
		var opponentPos = root.hasNode.dad ? readActor(root.node.dad, [100.0, 100.0]) : [100.0, 100.0];

		return {
			directory: '',
			defaultZoom: root.has.zoom ? Std.parseFloat(root.att.zoom) : 0.9,
			stageUI: 'normal',
			boyfriend: boyfriendPos,
			girlfriend: girlfriendPos,
			opponent: opponentPos,
			hide_girlfriend: false,
			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1,
			objects: objects
		};
	}

	public static function convertDaveStage(rawJson:String):StageFile
	{
		var json:Dynamic = Json.parse(rawJson);
		var objects:Array<Dynamic> = [];
		var boyfriend = [770, 100];
		var girlfriend = [400, 130];
		var opponent = [100, 100];

		for (sprite in cast(json.sprites, Array<Dynamic>))
		{
			switch(sprite.type)
			{
				case 'BF':
					boyfriend = sprite.pos;
				case 'GF':
					girlfriend = sprite.pos;
				case 'Dad':
					opponent = sprite.pos;
				default:
					objects.push({
						type: 'sprite',
						name: sprite.name,
						image: sprite.src,
						x: sprite.pos[0],
						y: sprite.pos[1],
						scroll: sprite.scrollFactor != null ? sprite.scrollFactor : [1, 1],
						scale: [sprite.scale != null ? sprite.scale : 1, sprite.scale != null ? sprite.scale : 1],
						color: '#FFFFFF',
						alpha: sprite.alpha != null ? sprite.alpha : 1,
						antialiasing: sprite.antialiasing != false,
						filters: 0
					});
			}
		}

		return {
			directory: '',
			defaultZoom: json.defaultCamZoom != null ? json.defaultCamZoom : 0.9,
			stageUI: 'normal',
			boyfriend: boyfriend,
			girlfriend: girlfriend,
			opponent: opponent,
			hide_girlfriend: false,
			camera_boyfriend: json.bfOffset != null ? json.bfOffset : [0, 0],
			camera_opponent: json.dadOffset != null ? json.dadOffset : [0, 0],
			camera_girlfriend: json.gfOffset != null ? json.gfOffset : [0, 0],
			camera_speed: json.followLerp != null ? json.followLerp : 1,
			objects: objects
		};
	}

	public static function parseColor(value:String):Array<Int>
	{
		var clean = value.replace('#', '');
		if(clean.length != 6) return [161, 161, 161];
		var color = Std.parseInt('0x$clean');
		return [(color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF];
	}
}
