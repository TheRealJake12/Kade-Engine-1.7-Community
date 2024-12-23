package kec.states;

import flixel.graphics.FlxGraphic;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup;
import lime.app.Application;
#if FEATURE_DISCORD
import kec.backend.Discord;
#end
import kec.backend.WeekData;
import kec.objects.menu.CoolText;
import kec.objects.menu.MenuItem;
import kec.objects.menu.MenuCharacter;
import kec.backend.chart.Song;
import kec.backend.util.Highscore;
import kec.backend.PlayStateChangeables;
import kec.backend.Stats;

class StoryMenuState extends MusicBeatState
{
	var scoreText:CoolText;

	static var weeksID:Array<String> = null;

	var storyBackground:FlxSprite = null;

	public static function weekData():Array<WeekData>
	{
		var weeksToLoad:Array<WeekData> = [];

		for (week in weeksID)
		{
			var data = Week.loadJSONFile(week);
			weeksToLoad.push(data);
		}

		return weeksToLoad;
	}

	public static var weeksLoaded:Array<WeekData> = null;

	var curDifficulty:Int = 1;

	public static var weekUnlocked:Array<Bool> = [];

	var diffList:Array<String> = [];

	var txtWeekTitle:CoolText;

	var curWeek:Int = 0;

	var currentWeek:Int = 0;

	var txtTracklist:CoolText;

	var availableDiffs:String = '';

	var grpWeekText:FlxTypedGroup<MenuItem>;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;

	var grpLocks:FlxTypedGroup<FlxSprite>;

	var difficultySelectors:FlxGroup;
	var sprDifficulty:FlxSprite;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;
	var diffsThatExists:Array<String>;

	function unlockWeeks():Array<Bool>
	{
		var weeks:Array<Bool> = [];

		for (i in 0...weeksLoaded.length)
			weeks.push(true);
		return weeks;
	}

	override function create()
	{
		Paths.clearCache();

		weeksID = CoolUtil.coolTextFile(Paths.txt('data/weekList'));
		weeksLoaded = weekData();
		weekUnlocked = unlockWeeks();

		#if desktop
		Application.current.window.title = '${Constants.kecVer} : In the Menus';
		#end

		PlayState.SONG = null;

		PlayState.inDaPlay = false;
		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		Discord.changePresence("In the Story Mode Menu", null);
		#end

		if (!Constants.freakyPlaying)
		{
			FlxG.sound.playMusic(Paths.music("freakyMenu"));
			Constants.freakyPlaying = true;
			Conductor.bpm = 102;
		}

		persistentUpdate = persistentDraw = true;

		scoreText = new CoolText(10, 10, 32, 32, Paths.bitmapFont('fonts/vcr'));
		scoreText.autoSize = true;
		scoreText.antialiasing = FlxG.save.data.antialiasing;

		txtWeekTitle = new CoolText(FlxG.width * 0.7, 10, 32, 32, Paths.bitmapFont('fonts/vcr'));
		txtWeekTitle.autoSize = true;
		txtWeekTitle.alpha = 0.7;
		txtWeekTitle.antialiasing = FlxG.save.data.antialiasing;

		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		var yellowBG:FlxSprite = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		storyBackground = new FlxSprite(0, 56);

		grpWeekText = new FlxTypedGroup<MenuItem>();
		add(grpWeekText);

		grpLocks = new FlxTypedGroup<FlxSprite>();
		add(grpLocks);

		var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBarThingie);

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();

		trace("Line 70");

		for (i in 0...weeksLoaded.length)
		{
			var weekThing:MenuItem = new MenuItem(0, yellowBG.y + yellowBG.height + 10, weeksID[i]);
			weekThing.y += ((weekThing.height + 20) * i);
			weekThing.targetY = i;
			grpWeekText.add(weekThing);

			weekThing.screenCenter(X);
			weekThing.antialiasing = FlxG.save.data.antialiasing;
			// weekThing.updateHitbox();

			// Needs an offset thingie
			if (!weekUnlocked[i])
			{
				trace('locking week ' + i);
				var lock:FlxSprite = new FlxSprite(weekThing.width + 10 + weekThing.x);
				lock.frames = ui_tex;
				lock.animation.addByPrefix('lock', 'lock');
				lock.animation.play('lock');
				lock.ID = i;
				lock.antialiasing = FlxG.save.data.antialiasing;
				grpLocks.add(lock);
			}
		}

		trace("Line 96");

		var charArray:Array<String> = weeksLoaded[0].characters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		difficultySelectors = new FlxGroup();
		add(difficultySelectors);

		trace("Line 124");

		leftArrow = new FlxSprite(grpWeekText.members[0].x + grpWeekText.members[0].width + 10, grpWeekText.members[0].y + 10);
		leftArrow.frames = ui_tex;
		leftArrow.animation.addByPrefix('idle', "arrow left");
		leftArrow.animation.addByPrefix('press', "arrow push left");
		leftArrow.animation.play('idle');
		leftArrow.antialiasing = FlxG.save.data.antialiasing;
		difficultySelectors.add(leftArrow);

		sprDifficulty = new FlxSprite(0, leftArrow.y);
		sprDifficulty.antialiasing = FlxG.save.data.antialiasing;

		difficultySelectors.add(sprDifficulty);

		rightArrow = new FlxSprite(leftArrow.x + sprDifficulty.width + 68, leftArrow.y);
		rightArrow.frames = ui_tex;
		rightArrow.animation.addByPrefix('idle', 'arrow right');
		rightArrow.animation.addByPrefix('press', "arrow push right", 24, false);
		rightArrow.animation.play('idle');
		rightArrow.antialiasing = FlxG.save.data.antialiasing;
		difficultySelectors.add(rightArrow);

		trace("Line 150");

		add(yellowBG);
		add(storyBackground);
		add(grpWeekCharacters);

		txtTracklist = new CoolText(FlxG.width * 0.05, yellowBG.x + yellowBG.height + 100, 32, 32, Paths.bitmapFont('fonts/vcr'));
		txtTracklist.autoSize = false;
		txtTracklist.fieldWidth = 500;
		txtTracklist.alignment = CENTER;
		txtTracklist.color = 0xFFe55777;
		txtTracklist.antialiasing = FlxG.save.data.antialiasing;
		add(txtTracklist);

		add(scoreText);
		add(txtWeekTitle);

		updateText();

		var bullShit:Int = 0;

		for (item in grpWeekText.members)
		{
			item.targetY = bullShit - curWeek;
			if (item.targetY == Std.int(0) && weekUnlocked[curWeek])
				item.alpha = 1;
			else
				item.alpha = 0.6;
			bullShit++;
		}

		changeWeek();
		changeDifficulty();

		super.create();
	}

	override function update(elapsed:Float)
	{
		// scoreText.setFormat('VCR OSD Mono', 32);
		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, 0.5));

		scoreText.text = "WEEK SCORE:" + lerpScore;
		scoreText.updateHitbox();

		txtWeekTitle.text = weeksLoaded[curWeek].weekName.toUpperCase();
		txtWeekTitle.updateHitbox();

		txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);

		difficultySelectors.visible = weekUnlocked[curWeek];

		grpLocks.forEach(function(lock:FlxSprite)
		{
			lock.y = grpWeekText.members[lock.ID].y;
		});

		if (!movedBack)
		{
			if (!selectedWeek)
			{
				if (FlxG.keys.justPressed.UP || controls.UP_P)
				{
					changeWeek(-1);
				}

				if (FlxG.keys.justPressed.DOWN || controls.DOWN_P)
				{
					changeWeek(1);
				}

				if (controls.RIGHT)
					rightArrow.animation.play('press')
				else
					rightArrow.animation.play('idle');

				if (controls.LEFT)
					leftArrow.animation.play('press');
				else
					leftArrow.animation.play('idle');

				if (controls.RIGHT_P)
					changeDifficulty(1);
				if (controls.LEFT_P)
					changeDifficulty(-1);
			}

			if (controls.ACCEPT || FlxG.mouse.justPressed)
			{
				selectWeek();
			}

			if (FlxG.mouse.justPressedRight)
			{
				changeDifficulty(1);
			}

			if (controls.BACK && !movedBack && !selectedWeek)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				movedBack = true;
				MusicBeatState.switchState(new MainMenuState());
			}

			if (FlxG.mouse.wheel != 0)
			{
				#if desktop
				changeWeek(-FlxG.mouse.wheel);
				#else
				if (FlxG.mouse.wheel < 0) // HTML5 BRAIN'T
					changeWeek(1);
				else if (FlxG.mouse.wheel > 0)
					changeWeek(-1);
				#end
			}
		}

		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);
	}

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;

	function selectWeek()
	{
		if (selectedWeek)
		{
			selectedWeek = false;
			return;
		}

		if (weekUnlocked[curWeek])
		{
			FlxG.sound.play(Paths.sound('confirmMenu'));
			grpWeekText.members[curWeek].startFlashing();
			grpWeekCharacters.members[1].animation.play('confirm');
			selectedWeek = true;
			try
			{
				var diffString = weeksLoaded[curWeek].difficulties[curDifficulty];
				var diff:String = CoolUtil.getSuffixFromDiff(diffString);
				PlayState.storyPlaylist = weeksLoaded[curWeek].songs;
				PlayState.isStoryMode = true;
				Conductor.rate = 1;
				PlayState.storyWeek = curWeek;
				PlayState.storyDifficulty = CoolUtil.difficulties.indexOf(diffString);

				Stats.resetStats();
				Stats.resetCampaignStats();
				PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0], diff);
				FlxTimer.wait(1, function()
				{
					MusicBeatState.switchState(new PlayState());
				});
			}
			catch (e)
			{
				Debug.logError(e);
				return;
			}
		}
	}

	var tweenDifficulty:FlxTween;

	function changeDifficulty(change:Int = 0):Void
	{
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = Std.int(weeksLoaded[curWeek].difficulties.length - 1);
		if (curDifficulty > weeksLoaded[curWeek].difficulties.length - 1)
			curDifficulty = 0;

		var graphicName = weeksLoaded[curWeek].difficulties[curDifficulty].toLowerCase();

		var newImage:FlxGraphic = Paths.image('menuDifficulties/$graphicName');

		if (sprDifficulty.graphic != newImage)
		{
			sprDifficulty.loadGraphic(newImage);
			sprDifficulty.x = leftArrow.x + 60;
			sprDifficulty.alpha = 0;
			sprDifficulty.y = leftArrow.y - 15;

			if (tweenDifficulty != null)
				tweenDifficulty.cancel();
			tweenDifficulty = createTween(sprDifficulty, {y: leftArrow.y + 15, alpha: 1}, 0.07, {
				onComplete: function(twn:FlxTween)
				{
					tweenDifficulty = null;
				}
			});
		}

		sprDifficulty.alpha = 0;

		rightArrow.x = leftArrow.x + sprDifficulty.width + 68;

		var diffString = weeksLoaded[curWeek].difficulties[curDifficulty];

		var abDiff = CoolUtil.difficulties.indexOf(diffString); // USING THESE WEIRD VALUES SO THAT IT DOESNT FLOAT UP
		sprDifficulty.y = leftArrow.y - 15;
		intendedScore = Highscore.getWeekScore(curWeek, abDiff, 1);
		createTween(sprDifficulty, {y: leftArrow.y + 15, alpha: 1}, 0.07);
	}

	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	function changeWeek(change:Int = 0):Void
	{
		curWeek += change;

		if (curWeek >= weeksLoaded.length)
			curWeek = 0;
		if (curWeek < 0)
			curWeek = weeksLoaded.length - 1;

		if (weeksLoaded[curWeek].difficulties == null || weeksLoaded[curWeek].difficulties.length == 0)
			weeksLoaded[curWeek].difficulties = CoolUtil.defaultDifficulties;

		if (weeksLoaded[curWeek].background != null)
		{
			storyBackground.loadGraphic(Paths.image('storymenu/bg/${weeksLoaded[curWeek].background}'));
			storyBackground.alpha = 1;
		}
		else
			storyBackground.alpha = 0;

		changeDifficulty();

		var bullShit:Int = 0;

		for (item in grpWeekText.members)
		{
			item.targetY = bullShit - curWeek;
			if (item.targetY == Std.int(0) && weekUnlocked[curWeek])
				item.alpha = 1;
			else
				item.alpha = 0.6;
			bullShit++;
		}

		FlxG.sound.play(Paths.sound('scrollMenu'));

		updateText();
	}

	function updateText()
	{
		var weekArray:Array<String> = weeksLoaded[curWeek].characters;
		for (i in 0...grpWeekCharacters.length)
		{
			grpWeekCharacters.members[i].changeCharacter(weekArray[i]);
		}

		var stringThing:Array<String> = weeksLoaded[curWeek].songs;
		txtTracklist.text = "Tracks\n\n";

		for (i in stringThing)
		{
			var actual = i.replace("-", " ");
			txtTracklist.text += "\n" + actual;
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.updateHitbox();

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;
		intendedScore = Highscore.getWeekScore(curWeek, curDifficulty, 1);
	}

	public static function unlockNextWeek(week:Int):Void
	{
		if (week <= weeksLoaded.length - 1 /*&& FlxG.save.data.weekUnlocked == week*/) // fuck you, unlocks all weeks
		{
			weekUnlocked.push(true);
			trace('Week ' + week + ' beat (Week ' + (week + 1) + ' unlocked)');
		}

		FlxG.save.data.weekUnlocked = weekUnlocked.length - 1;
		FlxG.save.flush();
	}
}
