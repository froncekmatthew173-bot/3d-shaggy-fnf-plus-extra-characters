// At the top of PlayState.hx
var devAutoplay:Bool = false; // Developer-only autoplay toggle

// Inside your update() function
override public function update(elapsed:Float):Void
{
	super.update(elapsed);
	/*
		botplay.hx
		Runtime autoplay script for exported builds. Forces perfect hits by temporarily
		setting the song position around each hit (best-effort).
	 */

	class botplay
	{
		public static var enabled:Bool = true;
		public static var hitWindow:Float = 160;

		public static function onCreatePost():Void
		{
			trace("botplay: loaded");
		}

		public static function onUpdate(elapsed:Float):Void
		{
			if (!enabled)
				return;

			var notes:Dynamic = null;
			try
				notes = getProperty("notes");
			catch (_)
			{
			}
			if (notes == null)
				return;

			var songPos:Float = 0;
			try
				songPos = getSongPosition();
			catch (_)
			{
				try
					songPos = getProperty("songPosition");
				catch (_)
				{
					return;
				}
			}

			for (i in 0...Std.int(notes.length))
			{
				var note:Dynamic = notes[i];
				if (note == null)
					continue;
				if (!Reflect.hasField(note, "mustPress") || !note.mustPress)
					continue;
				if (Reflect.hasField(note, "hit") && note.hit == true)
					continue;

				var strumTime:Float = Reflect.hasField(note, "strumTime") ? note.strumTime : 0;
				var diff:Float = Math.abs(strumTime - songPos);
				if (diff <= hitWindow)
				{
					// best-effort: try to set the song position so goodNoteHit judges a perfect hit
					var prevPos:Float = songPos;
					var didSet:Bool = false;
					try
					{
						setProperty("songPosition", strumTime);
						didSet = true;
					}
					catch (_)
					{
					}
					try
					{
						goodNoteHit(note.noteData, i, note.noteType, note.isSustainNote);
					}
					catch (e:Dynamic)
					{
						try
							note.hit = true;
						catch (_)
						{
						}
					}
					if (didSet)
					{
						try
							setProperty("songPosition", prevPos);
						catch (_)
						{
						}
					}
				}
			}
		}
	}
}
