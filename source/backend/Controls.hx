package backend;

import flixel.FlxG;
import flixel.input.gamepad.FlxGamepadButton;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.mappings.FlxGamepadMapping;
import flixel.input.keyboard.FlxKey;

#if android
import android.AndroidControls.AndroidControls;
import android.FlxNewHitbox;
import android.FlxVirtualPad;
import flixel.ui.FlxButton;
import android.flixel.FlxButton as FlxNewButton;
#end

class Controls
{
	//Keeping same use cases on stuff for it to be easier to understand/use
	//I'd have removed it but this makes it a lot less annoying to use in my opinion

	//You do NOT have to create these variables/getters for adding new keys,
	//but you will instead have to use:
	//   controls.justPressed("ui_up")   instead of   controls.UI_UP

	//Dumb but easily usable code, or Smart but complicated? Your choice.
	//Also idk how to use macros they're weird as fuck lol

	// Pressed buttons (directions)
	public var UI_UP_P(get, never):Bool;
	public var UI_DOWN_P(get, never):Bool;
	public var UI_LEFT_P(get, never):Bool;
	public var UI_RIGHT_P(get, never):Bool;
	public var NOTE_UP_P(get, never):Bool;
	public var NOTE_DOWN_P(get, never):Bool;
	public var NOTE_LEFT_P(get, never):Bool;
	public var NOTE_RIGHT_P(get, never):Bool;
	private function get_UI_UP_P() return justPressed('ui_up');
	private function get_UI_DOWN_P() return justPressed('ui_down');
	private function get_UI_LEFT_P() return justPressed('ui_left');
	private function get_UI_RIGHT_P() return justPressed('ui_right');
	private function get_NOTE_UP_P() return justPressed('note_up');
	private function get_NOTE_DOWN_P() return justPressed('note_down');
	private function get_NOTE_LEFT_P() return justPressed('note_left');
	private function get_NOTE_RIGHT_P() return justPressed('note_right');

	// Held buttons (directions)
	public var UI_UP(get, never):Bool;
	public var UI_DOWN(get, never):Bool;
	public var UI_LEFT(get, never):Bool;
	public var UI_RIGHT(get, never):Bool;
	public var NOTE_UP(get, never):Bool;
	public var NOTE_DOWN(get, never):Bool;
	public var NOTE_LEFT(get, never):Bool;
	public var NOTE_RIGHT(get, never):Bool;
	private function get_UI_UP() return pressed('ui_up');
	private function get_UI_DOWN() return pressed('ui_down');
	private function get_UI_LEFT() return pressed('ui_left');
	private function get_UI_RIGHT() return pressed('ui_right');
	private function get_NOTE_UP() return pressed('note_up');
	private function get_NOTE_DOWN() return pressed('note_down');
	private function get_NOTE_LEFT() return pressed('note_left');
	private function get_NOTE_RIGHT() return pressed('note_right');

	// Released buttons (directions)
	public var UI_UP_R(get, never):Bool;
	public var UI_DOWN_R(get, never):Bool;
	public var UI_LEFT_R(get, never):Bool;
	public var UI_RIGHT_R(get, never):Bool;
	public var NOTE_UP_R(get, never):Bool;
	public var NOTE_DOWN_R(get, never):Bool;
	public var NOTE_LEFT_R(get, never):Bool;
	public var NOTE_RIGHT_R(get, never):Bool;
	private function get_UI_UP_R() return justReleased('ui_up');
	private function get_UI_DOWN_R() return justReleased('ui_down');
	private function get_UI_LEFT_R() return justReleased('ui_left');
	private function get_UI_RIGHT_R() return justReleased('ui_right');
	private function get_NOTE_UP_R() return justReleased('note_up');
	private function get_NOTE_DOWN_R() return justReleased('note_down');
	private function get_NOTE_LEFT_R() return justReleased('note_left');
	private function get_NOTE_RIGHT_R() return justReleased('note_right');


	// Pressed buttons (others)
	public var ACCEPT(get, never):Bool;
	public var BACK(get, never):Bool;
	public var PAUSE(get, never):Bool;
	public var RESET(get, never):Bool;
	private function get_ACCEPT() return justPressed('accept');
	private function get_BACK() return justPressed('back');
	private function get_PAUSE() return justPressed('pause');
	private function get_RESET() return justPressed('reset');

	//Gamepad & Keyboard & Mobile stuff
	public var keyboardBinds:Map<String, Array<FlxKey>>;
	public var gamepadBinds:Map<String, Array<FlxGamepadInputID>>;

	public function justPressed(key:String)
	{
		var result:Bool = (FlxG.keys.anyJustPressed(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadJustPressed(gamepadBinds[key]) == true #if android || _myAndroidJustPressed(key) == true #end;
	}

	public function pressed(key:String)
	{
		var result:Bool = (FlxG.keys.anyPressed(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadPressed(gamepadBinds[key]) == true #if android || _myAndroidPressed(key) == true #end;
	}

	public function justReleased(key:String)
	{
		var result:Bool = (FlxG.keys.anyJustReleased(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadJustReleased(gamepadBinds[key]) == true #if android || _myAndroidJustReleased(key) == true #end;
	}

	public var controllerMode:Bool = false;
	private function _myGamepadJustPressed(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyJustPressed(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}
	private function _myGamepadPressed(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyPressed(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}
	private function _myGamepadJustReleased(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyJustReleased(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}

	#if android
	private function _myAndroidJustPressed(key:String):Bool
	{
		var mobileControls:MobileControls = MobileControls.instance;
		if (mobileControls == null) return false;

		var result:Bool = false;

		switch(key)
		{
			case 'ui_up':
				result = mobileControls.anyJustPressed([FlxNewHitbox.DPAD_UP]);
			case 'ui_down':
				result = mobileControls.anyJustPressed([FlxNewHitbox.DPAD_DOWN]);
			case 'ui_left':
				result = mobileControls.anyJustPressed([FlxNewHitbox.DPAD_LEFT]);
			case 'ui_right':
				result = mobileControls.anyJustPressed([FlxNewHitbox.DPAD_RIGHT]);
			case 'note_up':
				result = mobileControls.anyJustPressed([FlxNewHitbox.DPAD_UP]);
			case 'note_down':
				result = mobileControls.anyJustPressed([FlxNewHitbox.DPAD_DOWN]);
			case 'note_left':
				result = mobileControls.anyJustPressed([FlxNewHitbox.DPAD_LEFT]);
			case 'note_right':
				result = mobileControls.anyJustPressed([FlxNewHitbox.DPAD_RIGHT]);
			case 'accept':
				result = mobileControls.anyJustPressed([FlxNewHitbox.DPAD_UP]);
			case 'back':
				result = mobileControls.anyJustPressed([FlxNewHitbox.DPAD_DOWN]);
		}

		if (result) controllerMode = true;
		return result;
	}

	private function _myAndroidPressed(key:String):Bool
	{
		var mobileControls:MobileControls = MobileControls.instance;
		if (mobileControls == null) return false;

		var result:Bool = false;

		switch(key)
		{
			case 'ui_up':
				result = mobileControls.anyPressed([FlxNewHitbox.DPAD_UP]);
			case 'ui_down':
				result = mobileControls.anyPressed([FlxNewHitbox.DPAD_DOWN]);
			case 'ui_left':
				result = mobileControls.anyPressed([FlxNewHitbox.DPAD_LEFT]);
			case 'ui_right':
				result = mobileControls.anyPressed([FlxNewHitbox.DPAD_RIGHT]);
			case 'note_up':
				result = mobileControls.anyPressed([FlxNewHitbox.DPAD_UP]);
			case 'note_down':
				result = mobileControls.anyPressed([FlxNewHitbox.DPAD_DOWN]);
			case 'note_left':
				result = mobileControls.anyPressed([FlxNewHitbox.DPAD_LEFT]);
			case 'note_right':
				result = mobileControls.anyPressed([FlxNewHitbox.DPAD_RIGHT]);
		}

		if (result) controllerMode = true;
		return result;
	}

	private function _myAndroidJustReleased(key:String):Bool
	{
		var mobileControls:MobileControls = MobileControls.instance;
		if (mobileControls == null) return false;

		var result:Bool = false;

		switch(key)
		{
			case 'ui_up':
				result = mobileControls.anyJustReleased([FlxNewHitbox.DPAD_UP]);
			case 'ui_down':
				result = mobileControls.anyJustReleased([FlxNewHitbox.DPAD_DOWN]);
			case 'ui_left':
				result = mobileControls.anyJustReleased([FlxNewHitbox.DPAD_LEFT]);
			case 'ui_right':
				result = mobileControls.anyJustReleased([FlxNewHitbox.DPAD_RIGHT]);
			case 'note_up':
				result = mobileControls.anyJustReleased([FlxNewHitbox.DPAD_UP]);
			case 'note_down':
				result = mobileControls.anyJustReleased([FlxNewHitbox.DPAD_DOWN]);
			case 'note_left':
				result = mobileControls.anyJustReleased([FlxNewHitbox.DPAD_LEFT]);
			case 'note_right':
				result = mobileControls.anyJustReleased([FlxNewHitbox.DPAD_RIGHT]);
		}

		if (result) controllerMode = true;
		return result;
	}
	#end

	// IGNORE THESE
	public static var instance:Controls;
	public function new()
	{
		keyboardBinds = ClientPrefs.keyBinds;
		gamepadBinds = ClientPrefs.gamepadBinds;
	}
}
