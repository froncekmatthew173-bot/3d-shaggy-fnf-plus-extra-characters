package states;

import flixel.FlxSubState;

import flixel.effects.FlxFlicker;
import lime.app.Application;

class FlashingState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var isYes:Bool = true;
	var texts:FlxTypedSpriteGroup<FlxText>;
	var bg:FlxSprite;

	override function create()
	{
		super.create();

		addTouchPad("LEFT_RIGHT", "A_B");
		addTouchPadCamera();

		final enter:String = (controls.mobileC) ? 'A' : 'ENTER';
		final back:String = (controls.mobileC) ? 'B' : 'BACK';

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		texts = new FlxTypedSpriteGroup<FlxText>();
		texts.alpha = 0.0;
		add(texts);

		var warnText:FlxText = new FlxText(0, 0, FlxG.width,
			"Hey, watch out!\n
			This Mod contains some flashing lights!\n
			Do you wish to disable them?");
		warnText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		texts.add(warnText);

		final keys = ["Yes", "No"];
		for (i in 0...keys.length) {
			final button = new FlxText(0, 0, FlxG.width, keys[i]);
			button.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
			button.y = (warnText.y + warnText.height) + 24;
			button.x += (128 * i) - 80;
			texts.add(button);
		}
		if (touchPad != null) touchPad.alpha = 0;

		FlxTween.tween(texts, {alpha: 1.0}, 0.5, {
			onComplete: (_) -> updateItems()
		});
		if (touchPad != null) FlxTween.tween(touchPad, {alpha: 1.0}, 0.5);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(leftState) {
			return;
		}

		var leftP:Bool = controls.UI_LEFT_P;
		var rightP:Bool = controls.UI_RIGHT_P;
		var accept:Bool = controls.ACCEPT;
		var back:Bool = controls.BACK;

		if (touchPad != null) {
			leftP = leftP || touchPad.buttonLeft.justPressed;
			rightP = rightP || touchPad.buttonRight.justPressed;
			accept = accept || touchPad.buttonA.justPressed;
			back = back || touchPad.buttonB.justPressed;
		}

		if (leftP || rightP) {
			FlxG.sound.play(Paths.sound("scrollMenu"), 0.7);
			isYes = !isYes;
			updateItems();
		}
		if (accept || back) {
			leftState = true;
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			if(!back) {
				ClientPrefs.data.flashing = !isYes;
				ClientPrefs.saveSettings();
				FlxG.sound.play(Paths.sound('confirmMenu'));
				final button = texts.members[isYes ? 1 : 2];
				FlxFlicker.flicker(button, 1, 0.1, false, true, function(flk:FlxFlicker) {
					new FlxTimer().start(0.5, function (tmr:FlxTimer) {
						FlxTween.tween(texts, {alpha: 0}, 0.2, {
							onComplete: (_) -> MusicBeatState.switchState(new TitleState())
						});
						if (touchPad != null) FlxTween.tween(touchPad, {alpha: 0}, 0.2);
					});
				});
			} else {
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(texts, {alpha: 0}, 1, {
					onComplete: (_) -> MusicBeatState.switchState(new TitleState())
				});
				if (touchPad != null) FlxTween.tween(touchPad, {alpha: 0}, 1);
			}
		}
	}

	function updateItems() {
		// it's clunky but it works.
		texts.members[1].alpha = isYes ? 1.0 : 0.6;
		texts.members[2].alpha = isYes ? 0.6 : 1.0;
	}
}
