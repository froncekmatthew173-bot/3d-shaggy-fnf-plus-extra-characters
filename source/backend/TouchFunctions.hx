package backend;

import flixel.FlxBasic;
import flixel.FlxG;

class TouchFunctions
{
	public static var touchPressed(get, never):Bool;
	public static var touchJustPressed(get, never):Bool;
	public static var touchJustReleased(get, never):Bool;

	public static function touchOverlapObject(object:FlxBasic):Bool
	{
		for (touch in FlxG.touches.list)
			return touch.overlaps(object);
		return false;
	}

	@:noCompletion
	private static function get_touchPressed():Bool
	{
		for (touch in FlxG.touches.list)
			if (touch.pressed)
				return true;
		return false;
	}

	@:noCompletion
	private static function get_touchJustPressed():Bool
	{
		for (touch in FlxG.touches.list)
			if (touch.justPressed)
				return true;
		return false;
	}

	@:noCompletion
	private static function get_touchJustReleased():Bool
	{
		for (touch in FlxG.touches.list)
			if (touch.justReleased)
				return true;
		return false;
	}

	public static function anyTouchInRect(x:Float, y:Float, w:Float, h:Float):Bool
	{
		for (touch in FlxG.touches.list)
		{
			if (touch.pressed || touch.justPressed)
			{
				if (touch.x >= x && touch.x <= x + w && touch.y >= y && touch.y <= y + h)
					return true;
			}
		}
		return false;
	}

	public static function anyTouchJustPressedInRect(x:Float, y:Float, w:Float, h:Float):Bool
	{
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				if (touch.x >= x && touch.x <= x + w && touch.y >= y && touch.y <= y + h)
					return true;
			}
		}
		return false;
	}
}
