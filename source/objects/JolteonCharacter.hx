package objects;

import flixel.FlxSprite;
import flixel.math.FlxPoint;
import openfl.geom.Rectangle;

class JolteonCharacter extends Character
{
	static inline final BOUNCE_DURATION:Float = 0.12;
	static inline final BOUNCE_HEIGHT:Float = 10;
	static inline final SING_POSE_DURATION:Float = 0.18;
	static inline final HEY_POSE_DURATION:Float = 0.6;
	static inline final HIT_POSE_DURATION:Float = 0.35;
	static inline final TAIL_WAG_SPEED:Float = 3;
	static inline final TAIL_WAG_AMPLITUDE:Float = 10;
	static inline final GUNARM_SWING:Float = 4;
	static inline final BODY_BOB_AMPLITUDE:Float = 2.5;
	static inline final BREATH_SCALE:Float = 0.015;

	var body:FlxSprite;
	var gunarm:FlxSprite;
	var tail:FlxSprite;
	var headIdle:FlxSprite;
	var headLeft:FlxSprite;
	var headRight:FlxSprite;
	var headUp:FlxSprite;
	var headDown:FlxSprite;

	var allParts:Array<FlxSprite>;
	var headParts:Array<FlxSprite>;

	var time:Float = 0;
	var singPoseTime:Float = 0;
	var singTimer:Float = 0;
	var bounceTimer:Float = 0;
	var missFlashTimer:Float = 0;
	var currentAnim:String = 'idle';

	public function new(x:Float, y:Float, ?character:String = 'jolteon', ?isPlayer:Bool = false)
	{
		super(x, y, character, isPlayer);

		curCharacter = character;
		healthIcon = 'jolteon';
		healthColorArray = [248, 216, 80];
		singDuration = 4;
		noAntialiasing = true;
		antialiasing = false;
		hasMissAnimations = true;

		offset.set();
		origin.set(width * 0.5, height * 0.5);

		body = makePart('characters/jolteon/body');
		gunarm = makePart('characters/jolteon/gunarm');
		tail = makePart('characters/jolteon/tail');
		headIdle = makePart('characters/jolteon/headidle');
		headLeft = makePart('characters/jolteon/headleft');
		headRight = makePart('characters/jolteon/headright');
		headUp = makePart('characters/jolteon/headup');
		headDown = makePart('characters/jolteon/headdown');

		allParts = [tail, gunarm, body, headIdle, headLeft, headRight, headUp, headDown];
		headParts = [headIdle, headLeft, headRight, headUp, headDown];

		for (anim in [
			'idle', 'idle-loop', 'hey',
			'singLEFT', 'singDOWN', 'singUP', 'singRIGHT',
			'singLEFT-loop', 'singDOWN-loop', 'singUP-loop', 'singRIGHT-loop',
			'singLEFTmiss', 'singDOWNmiss', 'singUPmiss', 'singRIGHTmiss',
			'hurt', 'hit', 'scared'
		])
			addOffset(anim);

		playAnim('idle', true);
	}

	function makePart(image:String):FlxSprite
	{
		var spr = new FlxSprite();
		spr.loadGraphic(Paths.image(image));
		spr.antialiasing = false;
		return spr;
	}

	function getHeadForAnim(anim:String):FlxSprite
	{
		return switch (getPoseAnim(anim))
		{
			case 'singLEFT': headLeft;
			case 'singDOWN': headDown;
			case 'singUP': headUp;
			case 'singRIGHT': headRight;
			default: headIdle;
		}
	}

	function setActiveHead(anim:String)
	{
		var active = getHeadForAnim(anim);
		for (h in headParts)
			h.visible = (h == active);
	}

	override function update(elapsed:Float)
	{
		if (debugMode)
			super.update(elapsed);

		if (missFlashTimer > 0)
		{
			missFlashTimer -= elapsed;
			for (p in allParts)
				p.color = 0xFF00A0FF;
		}
		else
		{
			for (p in allParts)
				p.color = color;
		}

		setActiveHead(currentAnim);

		if (isIdleAnim(currentAnim))
			applyIdle(elapsed);
		else
		{
			singPoseTime += elapsed;
			applyPose(currentAnim);

			if (!debugMode && !isHeldPose(currentAnim))
			{
				singTimer -= elapsed;
				if (singTimer <= 0)
				{
					var loopAnim:String = currentAnim + '-loop';
					if (currentAnim.startsWith('sing') && hasAnimation(loopAnim))
						playAnim(loopAnim);
					else
					{
						currentAnim = 'idle';
						specialAnim = false;
						heyTimer = 0;
						bounceTimer = BOUNCE_DURATION;
					}
				}
			}
		}

		if (bounceTimer > 0)
		{
			bounceTimer -= elapsed;
			var bounceProgress = bounceTimer / BOUNCE_DURATION;
			for (p in allParts)
				p.y -= Math.sin(bounceProgress * Math.PI) * BOUNCE_HEIGHT;
		}

		holdTimer = currentAnim.startsWith('sing') ? holdTimer + elapsed : 0;
		if (!debugMode && !isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		for (p in allParts)
			p.update(elapsed);
	}

	function applyIdle(elapsed:Float)
	{
		time += elapsed;

		var bodyBob = Math.sin(time * 2) * BODY_BOB_AMPLITUDE;
		var bodyBreath = 1 + Math.sin(time * 1.2) * BREATH_SCALE;
		positionPart(body, 0, bodyBob, 0, bodyBreath, bodyBreath);

		var tailWag = Math.sin(time * TAIL_WAG_SPEED + 0.5) * TAIL_WAG_AMPLITUDE;
		positionPart(tail, 0, bodyBob * 0.5, tailWag);

		var gunarmSway = Math.sin(time * 2.5) * GUNARM_SWING * 0.5;
		positionPart(gunarm, 0, bodyBob * 0.3, gunarmSway);

		var headBob = bodyBob * 0.3 + Math.sin(time * 2.2) * 1.5;
		var headWiggle = Math.sin(time * 4) * 1.5;
		positionPart(headIdle, 0, bodyBob + headBob, headWiggle);
	}

	function applyPose(anim:String)
	{
		var loopWave:Float = Math.sin(singPoseTime * 12);
		var tailWave:Float = Math.sin(singPoseTime * 18);
		var attackPulse:Float = anim.endsWith('-loop') ? 0 : Math.sin(Math.min(singPoseTime / SING_POSE_DURATION, 1) * Math.PI);
		var bodyBob:Float = loopWave * 1.5;
		var headBob:Float = loopWave * 1.2 + attackPulse * 2;
		var tailFlick:Float = tailWave * 4 + attackPulse * 5;
		var currentHead = getHeadForAnim(anim);

		switch (getPoseAnim(anim))
		{
			case 'singLEFT':
				positionPart(body, -3 - attackPulse * 2, 1 + bodyBob, -0.25 - loopWave * 0.25, 1, 1);
				positionPart(tail, 0, 5 + bodyBob, -5 - tailFlick);
				positionPart(gunarm, 3 + attackPulse, bodyBob * 0.3, -1 - loopWave * 0.5);
				positionPart(currentHead, -4 - attackPulse * 2, headBob, -0.5 - loopWave * 1.5);
			case 'singDOWN':
				positionPart(body, 1, 4 + bodyBob + attackPulse * 2, loopWave * 0.15, 1.02 + attackPulse * 0.01, 0.98 - attackPulse * 0.01);
				positionPart(tail, 0, 12 + bodyBob + attackPulse, tailFlick * 0.6);
				positionPart(gunarm, 1, bodyBob * 0.3 + attackPulse, loopWave * 0.3);
				positionPart(currentHead, 2, headBob + attackPulse * 2, loopWave * 0.5);
			case 'singUP':
				positionPart(body, 1, -3 + bodyBob - attackPulse * 2, 0.15 + loopWave * 0.2, 0.99 - attackPulse * 0.01, 1.02 + attackPulse * 0.02);
				positionPart(tail, 0, bodyBob - attackPulse, 8 + tailFlick);
				positionPart(gunarm, 0, bodyBob * 0.3 - attackPulse * 0.5, loopWave * 0.3);
				positionPart(currentHead, 2, headBob - attackPulse * 2, 0.5 + loopWave * 1.25);
			case 'singRIGHT':
				positionPart(body, 4 + attackPulse * 2, 1 + bodyBob, 0.25 + loopWave * 0.25, 1, 1);
				positionPart(tail, 0, 5 + bodyBob, 5 + tailFlick);
				positionPart(gunarm, -2 - attackPulse, bodyBob * 0.3, 1 + loopWave * 0.5);
				positionPart(currentHead, 6 + attackPulse * 2, headBob, 0.5 + loopWave * 1.5);
			case 'idle':
				positionPart(body, 0, 0, 0, 1, 1);
				positionPart(tail, 0, 0, 0);
				positionPart(gunarm, 0, 0, 0);
				positionPart(currentHead, 0, 0, 0);
			case 'hey':
				var frame:Int = getProceduralFrame(HEY_POSE_DURATION, 6);
				var pop:Float = switch (frame)
				{
					case 0: 0.25;
					case 1: 0.85;
					case 2, 3: 1;
					case 4: 0.65;
					default: 0.35;
				}
				var wave:Float = Math.sin(singPoseTime * 18);
				positionPart(body, 0, -3 - pop * 4, wave * 0.3, 1 + pop * 0.012, 1 - pop * 0.01);
				positionPart(tail, 0, 6 - pop * 2, pop * 8 + Math.sin(singPoseTime * 24) * 4);
				positionPart(gunarm, 0, -pop * 2, wave * 0.5 + pop * 3);
				positionPart(currentHead, 0, -6 - pop * 5, wave * 2);
			case 'hurt', 'hit':
				var p:Float = easePose(singPoseTime, HIT_POSE_DURATION);
				var decay:Float = 1 - p;
				var shake:Float = Math.sin(singPoseTime * 75) * 5 * decay;
				positionPart(body, -6 * decay + shake, 4 * decay, -3 * decay + shake * 0.4, 1, 1);
				positionPart(tail, 0, 5 * decay, 10 * decay - shake);
				positionPart(gunarm, -3 * decay + shake, 2 * decay, shake * 0.5);
				positionPart(currentHead, -8 * decay + shake * 1.2, 3 * decay, -5 * decay + shake * 0.5);
			case 'scared':
				var shake:Float = Math.sin(singPoseTime * 70) * 3;
				var shiver:Float = Math.sin(singPoseTime * 42) * 2;
				positionPart(body, shake, 5 + shiver, shiver * 0.5, 0.98, 1.02);
				positionPart(tail, 0, 8 + shiver, 22 + Math.sin(singPoseTime * 55) * 4);
				positionPart(gunarm, shake * 0.5, 2 + shiver * 0.5, shiver * 0.3);
				positionPart(currentHead, 3 + shake * 1.4, -1 + shiver, shake * 1.2);
		}
	}

	function easePose(time:Float, duration:Float):Float
		return Math.min(time / duration, 1);

	function getProceduralFrame(duration:Float, frames:Int):Int
		return Std.int(Math.min((singPoseTime / duration) * frames, frames - 1));

	function getPoseAnim(anim:String):String
		return anim.replace('-loop', '').replace('miss', '');

	function isIdleAnim(anim:String):Bool
		return anim == 'idle' || anim == 'idle-loop' || anim == 'danceLeft' || anim == 'danceRight';

	function isHeldPose(anim:String):Bool
		return anim.endsWith('-loop') || anim == 'scared';

	function positionPart(spr:FlxSprite, offsetX:Float, offsetY:Float, angleValue:Float = 0, scaleX:Float = 1, scaleY:Float = 1)
	{
		var direction:Float = flipX ? -1 : 1;
		spr.x = x + offsetX * direction;
		spr.y = y + offsetY;
		spr.angle = angleValue * direction;
		spr.scale.set(scale.x * scaleX, scale.y * scaleY);
		spr.flipX = flipX;
	}

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		if (Force || getPoseAnim(currentAnim) != getPoseAnim(AnimName))
			singPoseTime = 0;
		currentAnim = AnimName;
		_lastPlayedAnimation = AnimName;

		if (animation.exists(AnimName))
			animation.play(AnimName, Force, Reversed, Frame);

		if (AnimName.startsWith('sing'))
		{
			singTimer = AnimName.endsWith('-loop') ? 0 : SING_POSE_DURATION;
			if (AnimName.endsWith('miss'))
				missFlashTimer = 0.15;
		}
		else if (isIdleAnim(AnimName))
		{
			currentAnim = 'idle';
		}
		else
		{
			singTimer = switch (AnimName)
			{
				case 'hey': HEY_POSE_DURATION;
				case 'hurt', 'hit': HIT_POSE_DURATION;
				default: 0.32;
			}
			if (AnimName == 'scared')
				singTimer = 0;
			if (AnimName == 'hurt' || AnimName == 'hit')
				missFlashTimer = HIT_POSE_DURATION;
		}

		if (hasAnimation(AnimName))
		{
			var daOffset = animOffsets.get(AnimName);
			offset.set(daOffset[0], daOffset[1]);
		}
	}

	override public function dance()
	{
		if (!debugMode && !skipDance && !specialAnim)
			playAnim('idle');
	}

	override public function hasAnimation(anim:String):Bool
		return animOffsets.exists(anim);

	override public function isAnimationFinished():Bool
		return currentAnim != 'scared' && !currentAnim.endsWith('-loop') && singTimer <= 0;

	function copyPartValues(spr:FlxSprite)
	{
		spr.cameras = cameras;
		spr.scrollFactor.copyFrom(scrollFactor);
		spr.offset.copyFrom(offset);
		spr.alpha = alpha;
		spr.visible = visible;
		spr.shader = shader;
	}

	override public function draw()
	{
		setActiveHead(currentAnim);

		for (p in allParts)
		{
			copyPartValues(p);
			p.draw();
		}
	}
}
