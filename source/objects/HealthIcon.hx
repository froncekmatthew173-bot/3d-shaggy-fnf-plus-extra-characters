package objects;

import shaders.ColorSwap;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isPlayer:Bool = false;
	private var char:String = '';
	public var paletteKey:String = null;
	public var colorSwap:ColorSwap;

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true, ?paletteKey:String = null)
	{
		super();
		this.isPlayer = isPlayer;
		this.paletteKey = paletteKey != null ? paletteKey : char;
		colorSwap = new ColorSwap();
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String, ?allowGPU:Bool = true) {
		if(this.char != char) {
			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE) && Paths.fileExists('images/icons/' + char + '/icon.png', IMAGE))
				name = 'icons/' + char + '/icon'; // Codename Engine icon folders
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon
			
			var graphic = Paths.image(name, allowGPU);
			var iSize:Float = Math.round(graphic.width / graphic.height);
			loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;
			updateHitbox();

			animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			if(char.endsWith('-pixel'))
				antialiasing = false;
			
			if(char.endsWith('-3d'))
				antialiasing = false;
			else
				antialiasing = ClientPrefs.data.antialiasing;

			applySavedColorSwap();
		}
	}

	public function setPaletteKey(value:String):Void
	{
		paletteKey = value != null ? value : char;
		applySavedColorSwap();
	}

	public function applySavedColorSwap():Void
	{
		if(colorSwap == null) colorSwap = new ColorSwap();
		var values:Array<Float> = ClientPrefs.data.characterColorSwaps != null ? ClientPrefs.data.characterColorSwaps.get(paletteKey) : null;
		if(values == null || values.length < 3)
		{
			colorSwap.hue = 0;
			colorSwap.saturation = 0;
			colorSwap.brightness = 0;
			shader = null;
			return;
		}

		colorSwap.hue = values[0];
		colorSwap.saturation = values[1];
		colorSwap.brightness = values[2];
		shader = colorSwap.shader;
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		if(autoAdjustOffset)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}

	public function getCharacter():String {
		return char;
	}
}
