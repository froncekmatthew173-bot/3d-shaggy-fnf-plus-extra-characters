package objects;

class CharacterFactory
{
	public static function create(x:Float, y:Float, ?character:String = '', ?isPlayer:Bool = false):Character
	{
		var characterId = (character == null || character.length < 1) ? Character.DEFAULT_CHARACTER : character;
		return switch(characterId.toLowerCase())
		{
			case 'flareon' | 'flareon-png' | 'flareon-rig':
				new FlareonCharacter(x, y, characterId, isPlayer);
			default:
				new Character(x, y, characterId, isPlayer);
		}
	}
}
