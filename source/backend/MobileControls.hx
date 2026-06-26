package backend;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;

#if android
import android.FlxNewHitbox;
#end

class MobileControls extends FlxTypedGroup<FlxSprite>
{
	public static var instance:MobileControls;

	#if android
	public var newhbox:FlxNewHitbox;
	#end

	private var _firstTap:Bool = true;
	private var _tapTimer:Float = 0;

	public function new()
	{
		super();
		instance = this;

		#if android
		newhbox = new FlxNewHitbox();
		newhbox.alpha = ClientPrefs.data.controlsAlpha;
		add(newhbox);
		#end
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
	}

	public function anyJustPressed(keys:Array<Int>):Bool
	{
		#if android
		if (newhbox != null)
		{
			for (key in keys)
			{
				if (newhbox.justPressed(key))
					return true;
			}
		}
		#end
		return false;
	}

	public function anyPressed(keys:Array<Int>):Bool
	{
		#if android
		if (newhbox != null)
		{
			for (key in keys)
			{
				if (newhbox.pressed(key))
					return true;
			}
		}
		#end
		return false;
	}

	public function anyJustReleased(keys:Array<Int>):Bool
	{
		#if android
		if (newhbox != null)
		{
			for (key in keys)
			{
				if (newhbox.justReleased(key))
					return true;
			}
		}
		#end
		return false;
	}

	public function anyOverlap(x:Float, y:Float, width:Float, height:Float):Bool
	{
		#if android
		if (newhbox != null)
		{
			for (touch in FlxG.touches.list)
			{
				if (touch.pressed)
				{
					var tx = touch.x;
					var ty = touch.y;
					if (tx >= x && tx <= x + width && ty >= y && ty <= y + height)
						return true;
				}
			}
		}
		#end
		return false;
	}

	public function anyJustPressedOverlap(x:Float, y:Float, width:Float, height:Float):Bool
	{
		#if android
		if (newhbox != null)
		{
			for (touch in FlxG.touches.list)
			{
				if (touch.justPressed)
				{
					var tx = touch.x;
					var ty = touch.y;
					if (tx >= x && tx <= x + width && ty >= y && ty <= y + height)
						return true;
				}
			}
		}
		#end
		return false;
	}
}
