package options;

import objects.Character;
import objects.CharacterFactory;
import objects.HealthIcon;
using StringTools;

class CharacterColorSubState extends MusicBeatSubstate
{
	var characterIDs:Array<String> = [];
	var curCharacter:Int = 0;
	var curChannel:Int = 0;
	var preview:Character;
	var iconPreview:HealthIcon;
	var titleText:Alphabet;
	var charText:Alphabet;
	var valueText:Alphabet;
	var helpText:FlxText;
	var channels:Array<String> = ['Hue', 'Saturation', 'Brightness'];

	public function new()
	{
		super();

		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFEA71FD;
		bg.screenCenter();
		add(bg);

		characterIDs = findAllCharacterIDs();
		if(characterIDs.length < 1) characterIDs = ['bf'];

		titleText = new Alphabet(70, 35, 'Character Colors', true);
		titleText.setScale(0.6);
		add(titleText);

		charText = new Alphabet(60, 560, '', true);
		charText.setScale(0.55);
		add(charText);

		valueText = new Alphabet(60, 625, '', false);
		valueText.setScale(0.45);
		add(valueText);

		helpText = new FlxText(40, 690, FlxG.width - 80,
			'UP/DOWN: Character   ACCEPT: Channel   LEFT/RIGHT: Change   RESET: Clear', 20);
		helpText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(helpText);

		loadPreview();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(controls.UI_UP_P) changeCharacter(-1);
		if(controls.UI_DOWN_P) changeCharacter(1);
		if(controls.ACCEPT) curChannel = (curChannel + 1) % channels.length;

		if(controls.UI_LEFT || controls.UI_RIGHT)
		{
			var delta:Float = (controls.UI_LEFT ? -1 : 1) * (FlxG.keys.pressed.SHIFT ? 0.01 : 0.0025);
			var values = getValues(currentID());
			values[curChannel] = FlxMath.bound(values[curChannel] + delta, curChannel == 0 ? -1 : -1, curChannel == 0 ? 1 : 1);
			ClientPrefs.data.characterColorSwaps.set(currentID(), values);
			preview.applySavedColorSwap();
			iconPreview.applySavedColorSwap();
		}

		if(controls.RESET)
		{
			ClientPrefs.data.characterColorSwaps.remove(currentID());
			preview.applySavedColorSwap();
			iconPreview.applySavedColorSwap();
		}

		if(controls.BACK)
		{
			ClientPrefs.saveSettings();
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		refreshText();
	}

	function changeCharacter(change:Int)
	{
		curCharacter = FlxMath.wrap(curCharacter + change, 0, characterIDs.length - 1);
		loadPreview();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function loadPreview()
	{
		if(preview != null)
		{
			remove(preview);
			preview.destroy();
		}
		if(iconPreview != null)
		{
			remove(iconPreview);
			iconPreview.destroy();
		}

		preview = CharacterFactory.create(0, 0, currentID());
		preview.scale.set(0.7, 0.7);
		preview.updateHitbox();
		preview.screenCenter();
		preview.y -= 35;
		add(preview);

		iconPreview = new HealthIcon(preview.healthIcon, false, false, currentID());
		iconPreview.setPosition(FlxG.width - iconPreview.width - 70, 110);
		add(iconPreview);
		refreshText();
	}

	inline function currentID():String
		return characterIDs[curCharacter];

	function getValues(id:String):Array<Float>
	{
		var values = ClientPrefs.data.characterColorSwaps.get(id);
		if(values == null || values.length < 3)
			values = [0, 0, 0];
		return values.copy();
	}

	function refreshText()
	{
		var values = getValues(currentID());
		charText.text = currentID();
		valueText.text =
			'${channels[curChannel]} selected   H: ${FlxMath.roundDecimal(values[0], 3)}   S: ${FlxMath.roundDecimal(values[1], 3)}   B: ${FlxMath.roundDecimal(values[2], 3)}';
	}

	static function findAllCharacterIDs():Array<String>
	{
		var ids:Array<String> = [];
		#if sys
		collectFlatCharacters('assets/characters', ids, '.json');
		collectFlatCharacters('assets/shared/characters', ids, '.json');
		if(FileSystem.exists('mods'))
			for(mod in FileSystem.readDirectory('mods'))
			{
				collectFlatCharacters('mods/$mod/characters', ids, '.json');
				collectFolderCharacters('mods/$mod/characters', ids);
				collectFlatCharacters('mods/$mod/data/characters', ids, '.xml');
			}
		#end
		ids.sort(function(a, b) return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
		return ids;
	}

	static function collectFlatCharacters(folder:String, ids:Array<String>, extension:String):Void
	{
		#if sys
		if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return;
		for(entry in FileSystem.readDirectory(folder))
			if(entry.toLowerCase().endsWith(extension))
			{
				var id = entry.substr(0, entry.length - extension.length);
				if(!ids.contains(id)) ids.push(id);
			}
		#end
	}

	static function collectFolderCharacters(folder:String, ids:Array<String>):Void
	{
		#if sys
		if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return;
		for(entry in FileSystem.readDirectory(folder))
		{
			var full = folder + '/' + entry;
			if(FileSystem.isDirectory(full) && FileSystem.exists(full + '/Character.json') && !ids.contains(entry))
				ids.push(entry);
		}
		#end
	}
}
