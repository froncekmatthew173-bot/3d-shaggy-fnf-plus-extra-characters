package psychlua;

import flixel.FlxBasic;
import flixel.group.FlxGroup.FlxTypedGroup;
import objects.Character;
import psychlua.LuaUtils;
import psychlua.CustomSubstate;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;

import haxe.ValueException;

typedef HScriptInfos = {
	> haxe.PosInfos,
	var ?funcName:String;
	var ?showLine:Null<Bool>;
	#if LUA_ALLOWED
	var ?isLua:Null<Bool>;
	#end
}

class HScript extends Iris
{
	public var filePath:String;
	public var modFolder:String;
	public var returnValue:Dynamic;

	#if LUA_ALLOWED
	public var parentLua:FunkinLua;
	public static function initHaxeModule(parent:FunkinLua)
	{
		if(parent.hscript == null)
		{
			trace('initializing haxe interp for: ${parent.scriptName}');
			parent.hscript = new HScript(parent);
		}
	}

	public static function initHaxeModuleCode(parent:FunkinLua, code:String, ?varsToBring:Any = null)
	{
		var hs:HScript = try parent.hscript catch (e) null;
		if(hs == null)
		{
			trace('initializing haxe interp for: ${parent.scriptName}');
			try {
				parent.hscript = new HScript(parent, code, varsToBring);
			}
			catch(e:IrisError) {
				var pos:HScriptInfos = cast {fileName: parent.scriptName, isLua: true};
				if(parent.lastCalledFunction != '') pos.funcName = parent.lastCalledFunction;
				Iris.error(Printer.errorToString(e, false), pos);
				parent.hscript = null;
			}
		}
		else
		{
			try
			{
				hs.scriptCode = code;
				hs.varsToBring = varsToBring;
				hs.parse(true);
				var ret:Dynamic = hs.execute();
				hs.returnValue = ret;
			}
			catch(e:IrisError)
			{
				var pos:HScriptInfos = cast hs.interp.posInfos();
				pos.isLua = true;
				if(parent.lastCalledFunction != '') pos.funcName = parent.lastCalledFunction;
				Iris.error(Printer.errorToString(e, false), pos);
				hs.returnValue = null;
			}
		}
	}
	#end

	public var origin:String;
	override public function new(?parent:Dynamic, ?file:String, ?varsToBring:Any = null, ?manualRun:Bool = false)
	{
		if (file == null)
			file = '';

		filePath = file;
		if (filePath != null && filePath.length > 0)
		{
			this.origin = filePath;
			#if MODS_ALLOWED
			var myFolder:Array<String> = filePath.split('/');
			if(myFolder[0] + '/' == Paths.mods() && (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1]))) //is inside mods folder
				this.modFolder = myFolder[1];
			#end
		}
		var scriptThing:String = file;
		var scriptName:String = null;
		if(parent == null && file != null)
		{
			var f:String = file.replace('\\', '/');
			if(f.contains('/') && !f.contains('\n')) {
				scriptThing = File.getContent(f);
				scriptName = f;
			}
		}
		scriptThing = preprocessCompatSource(scriptThing);
		#if LUA_ALLOWED
		if (scriptName == null && parent != null)
			scriptName = parent.scriptName;
		#end
		super(scriptThing, new IrisConfig(scriptName, false, false));
		var customInterp:CustomInterp = new CustomInterp();
		customInterp.parentInstance = FlxG.state;
		customInterp.showPosOnLog = false;
		this.interp = customInterp;
		#if LUA_ALLOWED
		parentLua = parent;
		if (parent != null)
		{
			this.origin = parent.scriptName;
			this.modFolder = parent.modFolder;
		}
		#end
		preset();
		this.varsToBring = varsToBring;
		if (!manualRun) {
			try {
				var ret:Dynamic = execute();
				returnValue = ret;
			} catch(e:IrisError) {
				returnValue = null;
				this.destroy();
				throw e;
			}
		}
	}

	var varsToBring(default, set):Any = null;
	static function preprocessCompatSource(source:String):String
	{
		if(source == null || source.length < 1) return source;

		// Codename scripts often import the same concepts through Codename package names.
		// Psych already exposes these symbols in the HScript preset, so drop the foreign aliases
		// before Iris tries to resolve classes that do not exist in this codebase.
		source = ~/^\s*import\s+funkin\.backend\.assets\.Paths\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+funkin\.game\.PlayState\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+funkin\.backend\.system\.Conductor\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+funkin\.[A-Za-z0-9_\.]+\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+haxe\.Json\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+lime\.utils\.Assets\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+flixel\.[A-Za-z0-9_\.]+\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+objects\.(BGSprite|HealthIcon|StrumNote|NoteSplash)\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+backend\.(Highscore|StageData|Difficulty)\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+openfl\.display\.BlendMode\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+flixel\.input\.keyboard\.FlxKey\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+flixel\.input\.gamepad\.FlxGamepadInputID\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+haxe\.xml\.Access\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+haxe\.xml\.Parser\s*;\s*$/gm.replace(source, '');
		source = ~/^\s*import\s+haxe\.xml\.Printer\s*;\s*$/gm.replace(source, '');
		source = ~/if\s*\(\s*data\.codenameChart\s*!=\s*null\s*&&\s*data\.codenameChart\s*\)/g.replace(source, 'if (data != null && data.codenameChart != null && data.codenameChart)');

		// Lower the most common Codename lifecycle callback names to the Psych
		// callbacks this engine already dispatches.
		// A parameterized Codename `create(event)` belongs to pause/game-over/state
		// scripts, not ordinary PlayState song scripts. Keep it out of Psych's zero-arg
		// `onCreate()` dispatch instead of calling it with the wrong signature.
		source = ~/function\s+create\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)[^)]*\)/g.replace(source, 'function onCompatCreate($1)');
		source = ~/function\s+create\s*\(/g.replace(source, 'function onCreate(');
		source = ~/function\s+postCreate\s*\(/g.replace(source, 'function onCreatePost(');
		source = ~/function\s+update\s*\(/g.replace(source, 'function onUpdate(');
		source = ~/function\s+postUpdate\s*\(/g.replace(source, 'function onUpdatePost(');
		source = ~/function\s+stepHit\s*\(/g.replace(source, 'function onStepHit(');
		source = ~/function\s+beatHit\s*\(/g.replace(source, 'function onBeatHit(');
		source = ~/function\s+onPlayerHit\s*\(/g.replace(source, 'function goodNoteHit(');
		source = ~/function\s+onDadHit\s*\(/g.replace(source, 'function opponentNoteHit(');
		source = ~/function\s+onPlayerMiss\s*\(/g.replace(source, 'function noteMiss(');

		// Iris accepts ordinary HScript loops, but some Codename scripts use Haxe's
		// key/value array loop form. Lower the common array/group form conservatively.
		var keyValueLoop = ~/for\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*=>\s*([A-Za-z_][A-Za-z0-9_]*)\s+in\s+([A-Za-z_][A-Za-z0-9_\.]*)\s*\)\s*\{/g;
		source = keyValueLoop.map(source, function(r)
		{
			var index = r.matched(1);
			var value = r.matched(2);
			var collection = r.matched(3);
			return 'for ($index in 0...$collection.length) { var $value = $collection[$index];';
		});
		return source;
	}

	override function preset() {
		super.preset();

		// Some very commonly used classes
		set('Type', Type);
		set('Reflect', Reflect);
		set('Json', CompatJson);
		set('Map', haxe.ds.StringMap);
		set('Assets', CompatAssets);
		set('Xml', Xml);
		set('FlxKey', CompatFlxKey);
		set('FlxGamepadInputID', CompatFlxGamepadInputID);
		#if sys
		set('File', File);
		set('FileSystem', FileSystem);
		#end
		set('FlxG', flixel.FlxG);
		set('FlxMath', flixel.math.FlxMath);
		set('FlxSprite', flixel.FlxSprite);
		set('FlxBackdrop', flixel.addons.display.FlxBackdrop);
		set('FlxGridOverlay', flixel.addons.display.FlxGridOverlay);
		set('FlxTypeText', flixel.addons.text.FlxTypeText);
		set('FlxFlicker', flixel.effects.FlxFlicker);
		set('FlxGroup', flixel.group.FlxGroup);
		set('FlxTypedGroup', flixel.group.FlxGroup.FlxTypedGroup);
		set('FlxTypedSpriteGroup', flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup);
		set('FlxSpriteGroup', flixel.group.FlxSpriteGroup);
		set('FlxObject', flixel.FlxObject);
		set('FlxSound', flixel.sound.FlxSound);
		set('FlxGraphic', flixel.graphics.FlxGraphic);
		set('FlxBasePoint', flixel.math.FlxBasePoint);
		set('FlxRandom', flixel.math.FlxRandom);
		set('FlxRect', flixel.math.FlxRect);
		set('FlxState', flixel.FlxState);
		set('FlxText', flixel.text.FlxText);
		set('FlxTextBorderStyle', flixel.text.FlxText.FlxTextBorderStyle);
		set('FlxTextFormat', flixel.text.FlxTextFormat);
		set('FlxTextFormatMarkerPair', flixel.text.FlxTextFormatMarkerPair);
		set('FunkinText', flixel.text.FlxText);
		set('FlxCamera', flixel.FlxCamera);
		set('PsychCamera', backend.PsychCamera);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxBar', flixel.ui.FlxBar);
		set('FlxGradient', flixel.util.FlxGradient);
		set('FlxSave', flixel.util.FlxSave);
		set('FlxStringUtil', flixel.util.FlxStringUtil);
		set('FlxColor', CustomFlxColor);
		set('Options', CompatOptions);
		set('Countdown', backend.BaseStage.Countdown);
		set('PlayState', PlayState);
		set('FreeplayState', states.FreeplayState);
		set('MainMenuState', states.MainMenuState);
		set('TitleState', states.TitleState);
		set('StoryMenuState', states.StoryMenuState);
		set('Paths', Paths);
		set('CoolUtil', CoolUtil);
		set('Chart', CompatChart);
		set('Conductor', Conductor);
		set('ClientPrefs', ClientPrefs);
		#if ACHIEVEMENTS_ALLOWED
		set('Achievements', Achievements);
		#end
		set('Character', Character);
		set('CharacterFactory', objects.CharacterFactory);
		set('BGSprite', objects.BGSprite);
		set('HealthIcon', objects.HealthIcon);
		set('StrumNote', objects.StrumNote);
		set('NoteSplash', objects.NoteSplash);
		set('Highscore', backend.Highscore);
		set('DiscordClient', backend.DiscordClient);
		set('Mods', backend.Mods);
		set('StageData', backend.StageData);
		set('Difficulty', backend.Difficulty);
		set('Song', backend.Song);
		set('PsychUIButton', backend.ui.PsychUIButton);
		set('PsychUINumericStepper', backend.ui.PsychUINumericStepper);
		set('Alphabet', Alphabet);
		set('Note', objects.Note);
		set('RGBPalette', shaders.RGBPalette);
		set('RGBShaderReference', shaders.RGBPalette.RGBShaderReference);
		set('CustomShader', CompatCustomShader);
		set('CustomSubstate', CustomSubstate);
		#if (!flash && sys)
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		set('ErrorHandledRuntimeShader', shaders.ErrorHandledShader.ErrorHandledRuntimeShader);
		#end
		set('ShaderFilter', openfl.filters.ShaderFilter);
		set('StringTools', StringTools);
		set('Image', lime.graphics.Image);
		set('NativeAPI', CompatNativeAPI);
		set('WindowUtils', CompatWindowUtils);
		#if flxanimate
		set('FlxAnimate', FlxAnimate);
		#end

		// Functions & Variables
		set('setVar', function(name:String, value:Dynamic) {
			MusicBeatState.getVariables().set(name, value);
			return value;
		});
		set('getVar', function(name:String) {
			var result:Dynamic = null;
			if(MusicBeatState.getVariables().exists(name)) result = MusicBeatState.getVariables().get(name);
			return result;
		});
		set('removeVar', function(name:String)
		{
			if(MusicBeatState.getVariables().exists(name))
			{
				MusicBeatState.getVariables().remove(name);
				return true;
			}
			return false;
		});
		set('debugPrint', function(text:String, ?color:FlxColor = null) {
			if(color == null) color = FlxColor.WHITE;
			PlayState.instance.addTextToDebug(text, color);
		});
		set('lerp', function(a:Float, b:Float, ratio:Float) return flixel.math.FlxMath.lerp(a, b, ratio));
		set('getModSetting', function(saveTag:String, ?modName:String = null) {
			if(modName == null)
			{
				if(this.modFolder == null)
				{
					Iris.error('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', this.interp.posInfos());
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.getModSetting(saveTag, modName);
		});

		// Keyboard & Gamepads
		set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
		set('anyGamepadPressed', function(name:String) FlxG.gamepads.anyPressed(name));
		set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));

		set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadJustPressed', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		set('gamepadPressed', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.pressed, name) == true;
		});
		set('gamepadReleased', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		set('keyJustPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}
			return false;
		});
		set('keyPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}
			return false;
		});
		set('keyReleased', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}
			return false;
		});

		// For adding your own callbacks
		// not very tested but should work
		#if LUA_ALLOWED
		set('createGlobalCallback', function(name:String, func:Dynamic)
		{
			for (script in PlayState.instance.luaArray)
				if(script != null && script.lua != null && !script.closed)
					Lua_helper.add_callback(script.lua, name, func);

			FunkinLua.customFunctions.set(name, func);
		});

		// this one was tested
		set('createCallback', function(name:String, func:Dynamic, ?funk:FunkinLua = null)
		{
			if(funk == null) funk = parentLua;
			
			if(funk != null) funk.addLocalCallback(name, func);
			else Iris.error('createCallback ($name): 3rd argument is null', this.interp.posInfos());
		});
		#end

		set('addHaxeLibrary', function(libName:String, ?libPackage:String = '') {
			try {
				var str:String = '';
				if(libPackage.length > 0)
					str = libPackage + '.';

				set(libName, Type.resolveClass(str + libName));
			}
			catch (e:IrisError) {
				Iris.error(Printer.errorToString(e, false), this.interp.posInfos());
			}
		});
		#if LUA_ALLOWED
		set('parentLua', parentLua);
		#else
		set('parentLua', null);
		#end
		set('this', this);
		set('game', FlxG.state);
		set('controls', Controls.instance);

		// Light compatibility aliases used by several Codename/Yoshi-style scripts.
		// Keep these additive and conservative: Psych fields still remain the source of truth.
		if(Std.isOfType(FlxG.state, PlayState))
		{
			var playState:PlayState = cast FlxG.state;
			set('state', playState);
			set('playState', playState);
			set('camGame', playState.camGame);
			set('camHUD', playState.camHUD);
			set('camOther', playState.camOther);
			set('boyfriend', playState.boyfriend);
			set('dad', playState.dad);
			set('gf', playState.gf);
			set('healthBar', playState.healthBar);
			set('iconP1', playState.iconP1);
			set('iconP2', playState.iconP2);
			set('comboGroup', playState.comboGroup);
			set('uiGroup', playState.uiGroup);
			set('noteGroup', playState.noteGroup);
			set('cpuStrums', playState.opponentStrums);
			set('strumLines', new CompatStrumLines(playState));
			set('events', CompatEvents.fromPsych(playState.eventNotes));
			set('members', playState.members);
			set('insert', function(index:Int, obj:FlxBasic)
			{
				var safeIndex:Int = index;
				if(safeIndex < 0) safeIndex = 0;
				if(safeIndex > playState.members.length) safeIndex = playState.members.length;
				return playState.insert(safeIndex, obj);
			});
			set('window', FlxG.stage.window);
			set('strumID', 0);
			set('charID', 0);
			set('downscroll', ClientPrefs.data.downScroll);
			set('middlescroll', ClientPrefs.data.middleScroll);
			set('flashing', ClientPrefs.data.flashing);
			set('importScript', function(path:String)
			{
				if(path == null || path.trim().length < 1) return false;
				return playState.startHScriptsNamed(path);
			});
			set('addBehindGF', function(obj:FlxBasic) return playState.insert(playState.members.indexOf(playState.gfGroup), obj));
			set('addBehindBF', function(obj:FlxBasic) return playState.insert(playState.members.indexOf(playState.boyfriendGroup), obj));
			set('addBehindDad', function(obj:FlxBasic) return playState.insert(playState.members.indexOf(playState.dadGroup), obj));
		}

		set('buildTarget', LuaUtils.getBuildTarget());
		set('customSubstate', CustomSubstate.instance);
		set('customSubstateName', CustomSubstate.name);

		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('Function_StopLua', LuaUtils.Function_StopLua); //doesnt do much cuz HScript has a lower priority than Lua
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
	}

	public function getCompatValue(name:String):Dynamic
	{
		return interp != null && interp.variables.exists(name) ? interp.variables.get(name) : null;
	}

	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua) {
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			initHaxeModuleCode(funk, codeToRun, varsToBring);
			if (funk.hscript != null)
			{
				final retVal:IrisCall = funk.hscript.call(funcToRun, funcArgs);
				if (retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
				else if (funk.hscript.returnValue != null)
				{
					return funk.hscript.returnValue;
				}
			}
			return null;
		});
		
		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			if (funk.hscript != null)
			{
				final retVal:IrisCall = funk.hscript.call(funcToRun, funcArgs);
				if (retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
			}
			else
			{
				var pos:HScriptInfos = cast {fileName: funk.scriptName, showLine: false};
				if (funk.lastCalledFunction != '') pos.funcName = funk.lastCalledFunction;
				Iris.error("runHaxeFunction: HScript has not been initialized yet! Use \"runHaxeCode\" to initialize it", pos);
			}
			return null;
		});
		// This function is unnecessary because import already exists in HScript as a native feature
		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			var str:String = '';
			if (libPackage.length > 0)
				str = libPackage + '.';
			else if (libName == null)
				libName = '';

			var c:Dynamic = Type.resolveClass(str + libName);
			if (c == null)
				c = Type.resolveEnum(str + libName);

			if (funk.hscript == null)
				initHaxeModule(funk);

			var pos:HScriptInfos = cast funk.hscript.interp.posInfos();
			pos.showLine = false;
			if (funk.lastCalledFunction != '')
				 pos.funcName = funk.lastCalledFunction;

			try {
				if (c != null)
					funk.hscript.set(libName, c);
			}
			catch (e:IrisError) {
				Iris.error(Printer.errorToString(e, false), pos);
			}
			FunkinLua.lastCalledScript = funk;
			if (FunkinLua.getBool('luaDebugMode') && FunkinLua.getBool('luaDeprecatedWarnings'))
				Iris.warn("addHaxeLibrary is deprecated! Import classes through \"import\" in HScript!", pos);
		});
	}
	#end

	override function call(funcToRun:String, ?args:Array<Dynamic>):IrisCall {
		if (funcToRun == null || interp == null) return null;

		if (!exists(funcToRun)) {
			Iris.error('No function named: $funcToRun', this.interp.posInfos());
			return null;
		}

		try {
			var func:Dynamic = interp.variables.get(funcToRun); // function signature
			final ret = Reflect.callMethod(null, func, args ?? []);
			return {funName: funcToRun, signature: func, returnValue: ret};
		}
		catch(e:IrisError) {
			var pos:HScriptInfos = cast this.interp.posInfos();
			pos.funcName = funcToRun;
			#if LUA_ALLOWED
			if (parentLua != null)
			{
				pos.isLua = true;
				if (parentLua.lastCalledFunction != '') pos.funcName = parentLua.lastCalledFunction;
			}
			#end
			Iris.error(Printer.errorToString(e, false), pos);
		}
		catch (e:ValueException) {
			var pos:HScriptInfos = cast this.interp.posInfos();
			pos.funcName = funcToRun;
			#if LUA_ALLOWED
			if (parentLua != null)
			{
				pos.isLua = true;
				if (parentLua.lastCalledFunction != '') pos.funcName = parentLua.lastCalledFunction;
			}
			#end
			Iris.error('$e', pos);
		}
		return null;
	}

	override public function destroy()
	{
		origin = null;
		#if LUA_ALLOWED parentLua = null; #end
		super.destroy();
	}

	function set_varsToBring(values:Any) {
		if (varsToBring != null)
			for (key in Reflect.fields(varsToBring))
				if (exists(key.trim()))
					interp.variables.remove(key.trim());

		if (values != null)
		{
			for (key in Reflect.fields(values))
			{
				key = key.trim();
				set(key, Reflect.field(values, key));
			}
		}

		return varsToBring = values;
	}
}

class CustomFlxColor {
	public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
	public static var BLACK(default, null):Int = FlxColor.BLACK;
	public static var WHITE(default, null):Int = FlxColor.WHITE;
	public static var GRAY(default, null):Int = FlxColor.GRAY;

	public static var GREEN(default, null):Int = FlxColor.GREEN;
	public static var LIME(default, null):Int = FlxColor.LIME;
	public static var YELLOW(default, null):Int = FlxColor.YELLOW;
	public static var ORANGE(default, null):Int = FlxColor.ORANGE;
	public static var RED(default, null):Int = FlxColor.RED;
	public static var PURPLE(default, null):Int = FlxColor.PURPLE;
	public static var BLUE(default, null):Int = FlxColor.BLUE;
	public static var BROWN(default, null):Int = FlxColor.BROWN;
	public static var PINK(default, null):Int = FlxColor.PINK;
	public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
	public static var CYAN(default, null):Int = FlxColor.CYAN;

	public static function fromInt(Value:Int):Int 
		return cast FlxColor.fromInt(Value);

	public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int
		return cast FlxColor.fromRGB(Red, Green, Blue, Alpha);

	public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha);

	public static inline function fromCMYK(Cyan:Float, Magenta:Float, Yellow:Float, Black:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromCMYK(Cyan, Magenta, Yellow, Black, Alpha);

	public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSB(Hue, Sat, Brt, Alpha);

	public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSL(Hue, Sat, Light, Alpha);

	public static function fromString(str:String):Int
		return cast FlxColor.fromString(str);
}

class CompatOptions {
	public static var antialiasing(get, never):Bool;
	public static var downscroll(get, never):Bool;
	public static var gameplayShaders(get, never):Bool;
	public static var colorHealthBar(get, never):Bool;

	static inline function get_antialiasing():Bool return ClientPrefs.data.antialiasing;
	static inline function get_downscroll():Bool return ClientPrefs.data.downScroll;
	static inline function get_gameplayShaders():Bool return ClientPrefs.data.shaders;
	static inline function get_colorHealthBar():Bool return true;
}

class CompatFlxKey {
	public static function fromString(value:String):Int
		return flixel.input.keyboard.FlxKey.fromString(value);
}

class CompatFlxGamepadInputID {
	public static function fromString(value:String):Int
		return flixel.input.gamepad.FlxGamepadInputID.fromString(value);
}

class CompatAssets {
	public static function exists(path:String):Bool
	{
		#if sys
		if(path != null && FileSystem.exists(path)) return true;
		#end
		return openfl.utils.Assets.exists(path);
	}

	public static function getText(path:String):String
	{
		#if sys
		if(path != null && FileSystem.exists(path)) return File.getContent(path);
		#end
		return openfl.utils.Assets.getText(path);
	}

	public static function getBytes(path:String):haxe.io.Bytes
	{
		#if sys
		if(path != null && FileSystem.exists(path)) return File.getBytes(path);
		#end
		return openfl.utils.Assets.getBytes(path);
	}
}

class CompatJson {
	public static function parse(text:String):Dynamic
		return haxe.Json.parse(text);

	public static function stringify(value:Dynamic, ?replacer:Dynamic, ?space:String):String
		return haxe.Json.stringify(value, replacer, space);
}

class CompatChart {}

class CompatNativeAPI {
	public static function allocConsole():Void {}
}

class CompatWindowUtils {
	public static var winTitle(get, set):String;
	static function get_winTitle():String
		return FlxG.stage != null && FlxG.stage.window != null ? FlxG.stage.window.title : '';
	static function set_winTitle(value:String):String
	{
		if(FlxG.stage != null && FlxG.stage.window != null) FlxG.stage.window.title = value;
		return value;
	}
}

#if (!flash && sys)
class CompatCustomShader extends shaders.ErrorHandledShader.ErrorHandledRuntimeShader
{
	public var hue(default, set):Float = 0;
	public var saturation(default, set):Float = 0;
	public var brightness(default, set):Float = 0;
	public var contrast(default, set):Float = 0;

	public function new(shaderName:String)
	{
		var frag:String = null;
		var vert:String = null;
		if(PlayState.instance != null)
		{
			PlayState.instance.initLuaShader(shaderName);
			if(PlayState.instance.runtimeShaders.exists(shaderName))
			{
				var data = PlayState.instance.runtimeShaders.get(shaderName);
				frag = data[0];
				vert = data[1];
			}
		}
		super(shaderName, frag, vert);
	}

	inline function set_hue(value:Float):Float { setFloat('hue', value); return hue = value; }
	inline function set_saturation(value:Float):Float { setFloat('saturation', value); return saturation = value; }
	inline function set_brightness(value:Float):Float { setFloat('brightness', value); return brightness = value; }
	inline function set_contrast(value:Float):Float { setFloat('contrast', value); return contrast = value; }
}
#end

class CompatStrumLines {
	public var members:Array<CompatStrumLine>;
	public var length(get, never):Int;

	public function new(playState:PlayState)
	{
		members = [];
		var rawLines:Array<Dynamic> = PlayState.SONG != null && PlayState.SONG.strumLines != null ? PlayState.SONG.strumLines : [];
		if(rawLines.length > 0)
		{
			for(i in 0...rawLines.length)
			{
				var raw = rawLines[i];
				var chars:Array<Character> = [];
				var position:String = raw != null && raw.position != null ? Std.string(raw.position) : '';
				switch(position)
				{
					case 'dad': if(playState.dad != null) chars.push(playState.dad);
					case 'boyfriend': if(playState.boyfriend != null) chars.push(playState.boyfriend);
					case 'girlfriend': if(playState.gf != null) chars.push(playState.gf);
				}
				if(chars.length < 1)
				{
					if(i == 0 && playState.dad != null) chars.push(playState.dad);
					else if(i == 1 && playState.boyfriend != null) chars.push(playState.boyfriend);
					else if(i == 2 && playState.gf != null) chars.push(playState.gf);
				}
				if(raw != null && raw.characters != null && chars.length > 0)
				{
					var rawChars:Array<Dynamic> = cast raw.characters;
					for(charIndex in 1...rawChars.length)
					{
						var extra:Character = objects.CharacterFactory.create(chars[0].x, chars[0].y, Std.string(rawChars[charIndex]), position == 'boyfriend');
						extra.visible = false;
						switch(position)
						{
							case 'boyfriend': playState.boyfriendGroup.add(extra);
							case 'girlfriend': playState.gfGroup.add(extra);
							default: playState.dadGroup.add(extra);
						}
						chars.push(extra);
					}
				}
				members.push(new CompatStrumLine(i, chars, i == 1 ? playState.playerStrums : playState.opponentStrums, raw));
			}
		}
		else
		{
			members = [
				new CompatStrumLine(0, [playState.dad], playState.opponentStrums, null),
				new CompatStrumLine(1, [playState.boyfriend], playState.playerStrums, null),
				new CompatStrumLine(2, playState.gf != null ? [playState.gf] : [], playState.opponentStrums, null)
			];
		}
	}

	public inline function iterator()
		return members.iterator();

	inline function get_length():Int
		return members.length;
}

class CompatStrumLine {
	public var characters:Array<Character>;
	public var notes:FlxTypedGroup<objects.Note>;
	public var members:Array<Dynamic>;
	public var cpu:Bool = false;
	public var strumScale:Float = 1;
	public var ID:Int = 0;
	public var data:Dynamic;
	public var animSuffix:String = '';
	public var vocals:Dynamic = null;

	public function new(id:Int, characters:Array<Character>, ?strums:Dynamic, ?data:Dynamic)
	{
		this.ID = id;
		this.characters = characters;
		this.notes = new FlxTypedGroup<objects.Note>();
		this.members = strums != null && strums.members != null ? strums.members : [];
		this.data = data != null ? data : {position: id == 1 ? 'boyfriend' : (id == 2 ? 'girlfriend' : 'dad')};
	}

	public inline function iterator()
		return members.iterator();

	public function remove(member:Dynamic, ?splice:Bool = false):Dynamic
	{
		members.remove(member);
		return member;
	}

	public function clear():Void
		members = [];

	public function generateStrums(?count:Int = 4):Void {}
}

class CompatEvents {
	public static function fromPsych(eventNotes:Array<objects.Note.EventNote>):Array<Dynamic>
	{
		var result:Array<Dynamic> = [];
		if(eventNotes == null) return result;

		for(event in eventNotes)
			result.push({
				name: event.event,
				params: event.params != null ? event.params.copy() : [event.value1, event.value2],
				time: event.strumTime
			});
		return result;
	}
}

class CustomInterp extends crowplexus.hscript.Interp
{
	public var parentInstance(default, set):Dynamic = [];
	private var _instanceFields:Array<String>;
	function set_parentInstance(inst:Dynamic):Dynamic
	{
		parentInstance = inst;
		if(parentInstance == null)
		{
			_instanceFields = [];
			return inst;
		}
		_instanceFields = Type.getInstanceFields(Type.getClass(inst));
		return inst;
	}

	public function new()
	{
		super();
	}

	override function fcall(o:Dynamic, funcToRun:String, args:Array<Dynamic>):Dynamic {
		for (_using in usings) {
			var v = _using.call(o, funcToRun, args);
			if (v != null)
				return v;
		}

		var f = get(o, funcToRun);

		if (f == null) {
			Iris.error('Tried to call null function $funcToRun', posInfos());
			return null;
		}

		return Reflect.callMethod(o, f, args);
	}

	override function resolve(id: String): Dynamic {
		if (locals.exists(id)) {
			var l = locals.get(id);
			return l.r;
		}

		if (variables.exists(id)) {
			var v = variables.get(id);
			return v;
		}

		if (imports.exists(id)) {
			var v = imports.get(id);
			return v;
		}

		if(parentInstance != null && _instanceFields.contains(id)) {
			var v = Reflect.getProperty(parentInstance, id);
			return v;
		}

		error(EUnknownVariable(id));

		return null;
	}
}
#else
class HScript
{
	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua) {
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			PlayState.instance.addTextToDebug('HScript is not supported on this platform!', FlxColor.RED);
			return null;
		});
		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			PlayState.instance.addTextToDebug('HScript is not supported on this platform!', FlxColor.RED);
			return null;
		});
		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			PlayState.instance.addTextToDebug('HScript is not supported on this platform!', FlxColor.RED);
			return null;
		});
	}
	#end
}
#end
