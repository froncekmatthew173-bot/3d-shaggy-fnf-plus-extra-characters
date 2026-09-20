/*
 * Copyright (C) 2025 Mobile Porting Team
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package mobile.backend;

import haxe.ds.Map;
import haxe.Json;
import haxe.io.Path;
import openfl.utils.Assets;
import openfl.utils.AssetType;
import flixel.util.FlxSave;
import sys.FileSystem;

/**
 * ...
 * @author: Karim Akra
 */
class MobileData
{
	public static var actionModes:Map<String, TouchButtonsData> = new Map();
	public static var dpadModes:Map<String, TouchButtonsData> = new Map();
	public static var extraActions:Map<String, ExtraActions> = new Map();

	public static var mode(get, set):Int;
	public static var forcedMode:Null<Int>;
	public static var save:FlxSave;

	public static function init()
	{
		save = new FlxSave();
		save.bind('MobileControls', CoolUtil.getSavePath());

		readDirectory(Paths.getSharedPath('mobile/DPadModes'), dpadModes);
		readDirectory(Paths.getSharedPath('mobile/ActionModes'), actionModes);
		#if MODS_ALLOWED
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'mobile/'))
		{
			readDirectory(Path.join([folder, 'DPadModes']), dpadModes);
			readDirectory(Path.join([folder, 'ActionModes']), actionModes);
		}
		#end

		for (data in ExtraActions.createAll())
			extraActions.set(data.getName(), data);
	}

	public static function setTouchPadCustom(touchPad:TouchPad):Void
	{
		if (save.data.buttons == null)
		{
			save.data.buttons = new Array();
			for (buttons in touchPad)
				save.data.buttons.push(FlxPoint.get(buttons.x, buttons.y));
		}
		else
		{
			var tempCount:Int = 0;
			for (buttons in touchPad)
			{
				save.data.buttons[tempCount] = FlxPoint.get(buttons.x, buttons.y);
				tempCount++;
			}
		}

		save.flush();
	}

	public static function getTouchPadCustom(touchPad:TouchPad):TouchPad
	{
		var tempCount:Int = 0;

		if (save.data.buttons == null)
			return touchPad;

		for (buttons in touchPad)
		{
			if (save.data.buttons[tempCount] != null)
			{
				buttons.x = save.data.buttons[tempCount].x;
				buttons.y = save.data.buttons[tempCount].y;
			}
			tempCount++;
		}

		return touchPad;
	}

	public static function setButtonsColors(buttonsInstance:Dynamic):Dynamic
	{
		// Dynamic Controls Color - FIX: guard against null ClientPrefs on mobile cold start
		try {
			var data:Dynamic = ClientPrefs.data != null ? ClientPrefs.data : ClientPrefs.defaultData;
			if (data == null || data.arrowRGB == null) return buttonsInstance;
			for (i => button in [
				buttonsInstance.buttonLeft,
				buttonsInstance.buttonDown,
				buttonsInstance.buttonUp,
				buttonsInstance.buttonRight])
			{
				if (button == null || button.label == null) continue;
				if (data.arrowRGB[i] == null) continue;
				button.color = data.arrowRGB[i][0];
				button.label.color = data.arrowRGB[i][0];
				button.label.updateColorTransform();
			}
		} catch(e) trace('setButtonsColors failed: $e');
		return buttonsInstance;
	}

	public static function readDirectory(folder:String, map:Dynamic)
	{
		folder = folder.contains(':') ? folder.split(':')[1] : folder;

		// FIX: On Android/iOS assets are inside APK/IPA, not on FileSystem. Original code would crash or leave maps empty on mobile, causing instant close.
		// Wrap FileSystem access in try/catch and fallback to Assets listing.
		var files:Array<String> = null;
		try {
			#if MODS_ALLOWED
			if (FileSystem.exists(folder)) files = FileSystem.readDirectory(folder);
			else files = [];
			#else
			files = FileSystem.readDirectory(folder);
			#end
		} catch(e) {
			trace('MobileData.readDirectory FileSystem failed for $folder: $e, falling back to Assets');
			files = [];
		}

		// If FileSystem found files, process them
		if (files != null && files.length > 0) {
			for (file in files)
			{
				var fileWithNoLib:String = file.contains(':') ? file.split(':')[1] : file;
				if (Path.extension(fileWithNoLib) == 'json')
				{
					file = Path.join([folder, Path.withoutDirectory(file)]);
					try {
						var str = #if MODS_ALLOWED File.getContent(file) #else Assets.getText(file) #end;
						var json:TouchButtonsData = cast Json.parse(str);
						var mapKey:String = Path.withoutDirectory(Path.withoutExtension(fileWithNoLib));
						map.set(mapKey, json);
					} catch(e) trace('Failed to load $file: $e');
				}
			}
			return;
		}

		// Fallback: enumerate via OpenFL Assets (works on mobile where files are embedded) - try both TEXT and BINARY for iOS/Android
		try {
			var assetLists:Array<Array<String>> = [];
			try assetLists.push(Assets.list(AssetType.TEXT)) catch(e) {}
			try assetLists.push(Assets.list(AssetType.BINARY)) catch(e) {}
			// also try unfiltered list
			try {
				var all = Assets.list(null);
				if (all != null) assetLists.push(all);
			} catch(e) {}
			var seen = new Map<String, Bool>();
			for (assetList in assetLists) {
				if (assetList == null) continue;
				for (assetPath in assetList) {
					if (seen.exists(assetPath)) continue;
					seen.set(assetPath, true);
					// asset paths are like "assets/shared/mobile/DPadModes/LEFT_FULL.json"
					if (assetPath.indexOf(folder) == -1 && assetPath.indexOf('mobile') == -1) continue;
					if (Path.extension(assetPath) != 'json') continue;
					if (assetPath.indexOf('DPadModes') == -1 && assetPath.indexOf('ActionModes') == -1) continue;
					// Ensure folder match
					var wantDPad = folder.indexOf('DPadModes') != -1;
					var isDPad = assetPath.indexOf('DPadModes') != -1;
					if (wantDPad != isDPad) continue;
					try {
						var str = Assets.getText(assetPath);
						if (str == null) continue;
						var json:TouchButtonsData = cast Json.parse(str);
						var mapKey:String = Path.withoutDirectory(Path.withoutExtension(assetPath));
						if (!map.exists(mapKey)) map.set(mapKey, json);
					} catch(e) trace('Failed to load asset $assetPath: $e');
				}
			}
		} catch(e) {
			trace('MobileData.readDirectory Assets fallback failed for $folder: $e');
		}

		// Last resort: if still empty, directly try known asset paths (works even when Assets.list is filtered)
		if (!(cast(map, Map<String, Dynamic>).keys().hasNext())) {
			trace('Warning: MobileData.readDirectory found no files for $folder via FileSystem or Assets, trying direct loads');
			var knownFiles:Array<String> = [];
			if (folder.indexOf('DPadModes') != -1) knownFiles = ['LEFT_FULL','RIGHT_FULL','LEFT_RIGHT','UP_DOWN','DIALOGUE_PORTRAIT','MENU_CHARACTER'];
			else if (folder.indexOf('ActionModes') != -1) knownFiles = ['A','B','E','P','A_B','A_B_C','A_B_X_Y','A_B_C_X_Y_Z','A_B_C_D_V_X_Y_Z','B_C','NONE','MENU_CHARACTER','DIALOGUE_PORTRAIT','CHARACTER_EDITOR','CHART_EDITOR','NOTE_SPLASH_EDITOR'];
			for (k in knownFiles) {
				var p = folder + '/' + k + '.json';
				// try multiple lookup variants: raw, shared path, colon-stripped
				for (trial in [p, 'assets/shared/mobile/' + (folder.indexOf('DPadModes')!=-1?'DPadModes/':'ActionModes/') + k + '.json']) {
					try {
						if (!Assets.exists(trial, AssetType.TEXT) && !openfl.utils.Assets.exists(trial, AssetType.TEXT)) continue;
						var str = Assets.getText(trial);
						if (str == null) continue;
						var json:TouchButtonsData = cast Json.parse(str);
						if (!map.exists(k)) {
							map.set(k, json);
							trace('MobileData direct loaded $trial');
						}
						break;
					} catch(e) {}
				}
			}
			var typedMap:Map<String, Dynamic> = cast map;
			if (!typedMap.keys().hasNext()) {
				trace('ERROR: MobileData still empty for $folder - injecting hardcoded fallback');
				// Hardcoded minimal fallback - guarantees LEFT_RIGHT + A_B exist even if asset system completely fails (common on Android if assets not listed)
				if (folder.indexOf('DPadModes') != -1) {
					if (!typedMap.exists('LEFT_RIGHT')) typedMap.set('LEFT_RIGHT', {buttons: [{button:"buttonLeft", graphic:"left", x:0, y:500, color:"0xFFC24B99"}, {button:"buttonRight", graphic:"right", x:196, y:500, color:"0xFF00FFFF"}]});
					if (!typedMap.exists('LEFT_FULL')) typedMap.set('LEFT_FULL', {buttons: [{button:"buttonLeft", graphic:"left", x:0, y:500, color:"0xFFC24B99"}, {button:"buttonRight", graphic:"right", x:196, y:500, color:"0xFF00FFFF"}, {button:"buttonUp", graphic:"up", x:98, y:405, color:"0xFF12FA05"}, {button:"buttonDown", graphic:"down", x:98, y:595, color:"0xFF00FFFF"}]});
					if (!typedMap.exists('RIGHT_FULL')) typedMap.set('RIGHT_FULL', {buttons: [{button:"buttonLeft", graphic:"left", x:800, y:500, color:"0xFFC24B99"}, {button:"buttonRight", graphic:"right", x:996, y:500, color:"0xFF00FFFF"}, {button:"buttonUp", graphic:"up", x:898, y:405, color:"0xFF12FA05"}, {button:"buttonDown", graphic:"down", x:898, y:595, color:"0xFF00FFFF"}]});
				} else {
					if (!typedMap.exists('A_B')) typedMap.set('A_B', {buttons: [{button:"buttonA", graphic:"a", x:1150, y:500, color:"0xFF00FF00"}, {button:"buttonB", graphic:"b", x:1050, y:600, color:"0xFFFF0000"}]});
					if (!typedMap.exists('NONE')) typedMap.set('NONE', {buttons: []});
				}
				trace('MobileData hardcoded fallback injected for $folder: ${[for(k in typedMap.keys()) k].join(",")}');
			} else trace('MobileData recovered ${[for(k in typedMap.keys()) k].join(",")} for $folder');
		}
	}

	static function set_mode(mode:Int = 3)
	{
		if (save == null)
			init();
		save.data.mobileControlsMode = mode;
		save.flush();
		return mode;
	}

	static function get_mode():Int
	{
		if (forcedMode != null)
			return forcedMode;

		if (save == null)
			init();

		if (save.data.mobileControlsMode == null)
		{
			save.data.mobileControlsMode = 3;
			save.flush();
		}

		return save.data.mobileControlsMode;
	}
}

typedef TouchButtonsData =
{
	buttons:Array<ButtonsData>
}

typedef ButtonsData =
{
	button:String, // what TouchButton should be used, must be a valid TouchButton var from TouchPad as a string.
	graphic:String, // the graphic of the button, usually can be located in the TouchPad xml .
	x:Float, // the button's X position on screen.
	y:Float, // the button's Y position on screen.
	color:String // the button color, default color is white.
}

enum ExtraActions
{
	SINGLE;
	DOUBLE;
	NONE;
}