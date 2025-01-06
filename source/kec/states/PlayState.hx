package kec.states;

import flixel.addons.effects.FlxTrail;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.ui.FlxBar;
import flixel.util.FlxSort;
import haxe.ds.StringMap;
import kec.backend.HitSounds;
import kec.backend.PlayStateChangeables;
import kec.backend.PlayerSettings;
import kec.backend.Ratings.RatingWindow;
import kec.backend.Ratings;
import kec.backend.Stats;
import kec.backend.chart.ChartData;
import kec.backend.chart.ChartNote;
import kec.backend.chart.Event;
import kec.backend.chart.Section;
import kec.backend.chart.Song.StyleData;
import kec.backend.chart.Song;
import kec.backend.chart.TimingStruct;
import kec.util.HelperFunctions;
import kec.util.Highscore;
import kec.util.NoteStyleHelper;
import kec.util.Sort;
import kec.objects.menu.Alphabet;
import kec.objects.game.Bar;
import kec.objects.game.Character;
import kec.objects.game.note.Note;
import kec.objects.game.note.NoteSplash;
import kec.objects.game.note.StaticArrow;
import kec.objects.game.ComboNumber;
import kec.objects.game.DialogueBox;
import kec.objects.game.HealthIcon;
import kec.objects.game.IntroSprite;
import kec.objects.game.Rating;
import kec.objects.game.UIComponent;
import kec.stages.Stage;
import kec.stages.TankmenBG;
import kec.states.MusicBeatState.transSubstate;
import kec.states.editors.ChartingState;
import kec.states.editors.StageDebugState;
import kec.substates.*;
import lime.app.Application;
import lime.utils.Assets as LimeAssets;
import openfl.Lib;
import openfl.events.KeyboardEvent;
import openfl.media.Sound;
import openfl.utils.Assets as OpenFlAssets;
#if FEATURE_LUAMODCHART
import kec.backend.lua.LuaClass;
import kec.backend.lua.ModchartState;
#end
#if FEATURE_FILESYSTEM
import Sys;
import sys.FileSystem;
import sys.io.File;
#end
#if FEATURE_DISCORD
import kec.backend.Discord;
#end
#if FEATURE_HSCRIPT
import kec.backend.script.Script;
import kec.backend.script.ScriptGroup;
import kec.backend.script.ScriptUtil;
#end
// Orginization Imports
#if VIDEOS
import hxvlc.flixel.FlxVideo as VideoHandler;
import hxvlc.flixel.FlxVideoSprite as VideoSprite;
import hxvlc.util.Handle;
#end

class PlayState extends MusicBeatState
{
	// PlayState But Static.
	public static var instance:PlayState = null;

	// SONG MULTIPLIER STUFF
	public var speedChanged:Bool = false;

	// Scroll Speed changes multiplier
	public var scrollSpeed(default, set):Float = 1.0;
	public var scrollMult:Float = 1.0;
	public var scrollTween:FlxTween;

	// Fake crochet for Sustain Notes
	public var fakeCrochet:Float = 0;
	public var fakeNoteStepCrochet:Float;

	// I shit my pants
	// Song Data. Very Useful Uses Like SONG.songId Or Some Shit.
	public static var SONG:ChartData;

	// Style Data. Like Pixel Or Default Or Something. Controls The UI Basically.
	public static var STYLE:StyleData;

	// Better To Use SONG.songId But Works Too Ig.
	private var curSong:String = "";

	// Story Shit, Not That Useful Aside From isStoryMode and storyDifficulty.
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;
	public static var weekSong:Int = 0;

	// Stores HUD Elements in a Group
	public var uiGroup:FlxSpriteGroup;

	// The Number Your Combo Is.
	private var combo:Int = 0;

	// Highest Your Combo Has Been.
	public static var highestCombo:Int = 0;

	// The Actual MS Timing.
	public var msTiming:Float;

	// Text For Accuracy, Score, Misses, Etc.
	var scoreTxt:FlxText;
	// How Many Marvs, Sicks, Etc.
	var judgementCounter:FlxText;

	#if FEATURE_HSCRIPT
	// Hscript Group (All Of The Loaded Scripts)
	public var scripts:ScriptGroup;
	#end

	// Lua Stuff. If There's A File, It'll Be True.
	public var executeModchart = false;

	// Character Animation Related
	var idleToBeat:Bool = true; // change if bf and dad would idle to the beat of the song
	var idleBeat:Int = 2; // how frequently bf and dad would play their idle animation(1 - every beat, 2 - every 2 beats and so on)
	var forcedToIdle:Bool = false; // change if bf and dad are forced to idle to every (idleBeat) beats of the song
	var allowedToHeadbang:Bool = true; // Will decide if gf is allowed to headbang depending on the song
	var allowedToCheer:Bool = false; // Will decide if gf is allowed to cheer depending on the song

	// BotPlay text
	public var addedBotplay:Bool = false;

	public var botPlayState:FlxText;

	// All The Notes
	public var notes:FlxTypedGroup<Note>;
	// Non Visible Notes.
	public var unspawnNotes:Array<Note> = [];

	// MS Timing For Notes?
	var notesHitArray:Array<Float> = [];

	// If The Arrows Are Generated / Shown.
	public var arrowsShown:Bool = false;

	// If Is In PlayState.
	public static var inDaPlay:Bool = false;

	// If You Can Skip To Where Notes Start In A Song (Freeplay Only.)
	var needSkip:Bool = false;
	var skipActive:Bool = false;
	var skipText:Alphabet;
	var skipTo:Float;

	// If You Did Skip Ahead.
	var usedTimeTravel:Bool = false;

	public var storyDifficultyText:String = "";

	#if FEATURE_DISCORD
	// Discord RPC variables
	var iconRPC:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	// Voices And Instrumental Sounds. Best Not To Mess With These Too Much.
	public static var vocals:FlxSound;
	public static var vocalsPlayer:FlxSound;
	public static var vocalsEnemy:FlxSound;
	public static var inst:FlxSound;

	// Notesplashes
	private var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	// Camera Zoom Related. zoomMultiplier Multiplies The Camera Zoom Amount (Every 4 Steps)
	public var zoomForTweens:Float = 0;
	public var zoomForHUDTweens:Float = 1;
	public var zoomMultiplier:Float = 1;

	// Characters, Very Useful.
	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var boyfriendMap:StringMap<Character>;
	public var dadMap:StringMap<Character>;
	public var gfMap:StringMap<Character>;

	public var boyfriendGroup:FlxTypedGroup<Character>;
	public var dadGroup:FlxTypedGroup<Character>;
	public var gfGroup:FlxTypedGroup<Character>;

	// The Stage.
	public var Stage:Stage = null;

	// Not Important. Ignore This.
	public var strumLine:FlxSprite;

	// The Actual Camera Position.
	private var camPos:FlxPoint;
	private var camFollow:FlxPoint;
	private var camFollowPos:FlxObject;

	// Last Camera Position (StoryMode)
	private static var prevCamFollow:FlxPoint;

	private var stageFollow:FlxPoint;

	private static var prevCamFollowPos:FlxObject;

	private var camNoteX:Float = 0;
	private var camNoteY:Float = 0;

	// Strumline (Static Notes)
	public static var strumLineNotes:FlxTypedGroup<StaticArrow> = null;
	public static var playerStrums:FlxTypedGroup<StaticArrow> = null;
	public static var cpuStrums:FlxTypedGroup<StaticArrow> = null;

	public var arrowLanes:FlxTypedGroup<FlxSprite> = null;

	// When The Camera Zooms On Beat
	private var camZooming:Bool = false;

	// No Idea.
	private var gfSpeed:Int = 1;

	// Health Stuff. Important. shownHealth Is Just Health But Allows Lerping (Smooth Healthbar. Don't Touch shownHealth.)
	public var health(default, set):Float = 1;
	public var shownHealth:Float = 1;

	// Icons For The Healthbar. Ignore The AnimArrays. It's Used For Animated Icons.
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	// Healthbar Related Stuff. Making Custom Ones Just Means Loading The Image Later In The Code 9/10 Times.
	private var healthBar:Bar;
	// Song Position Bar Stuff
	private var songPositionBar:Float = 0;

	public static var songPosBar:Bar;

	// Song Position Song Name.
	var songName:FlxText;

	// Self Explainitory.
	var songLength:Float = 0;

	// If The Song Has Been Generated.
	private var generatedMusic:Bool = false;
	// If The Song Has Started Playing.
	private var startingSong:Bool = false;

	// All The Cameras Used Ingame.
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var overlayCam:FlxCamera;

	// Can The Player Die. Only Used When Switching States Or Something.
	public var cannotDie = false;

	// Dialogue For Week 6 And Whatnot.
	public var dialogue:Array<String> = [];

	// Kinda The Same Thing.
	public var inCutscene:Bool = false;

	// From What I Can Tell, It's Just Used For StageDebugState.
	public static var stageTesting:Bool = false;

	// Will fire once to prevent debug spam messages and broken animations
	private var triggeredAlready:Bool = false;

	// Per song additive offset
	public static var songOffset:Float = 0;

	// Self Explainitory.
	public var isDead:Bool = false; // Don't mess with this on Lua!!!

	// Self Explainitory.
	public static var startTime = 0.0;

	#if VIDEOS
	// Week 7 Cutscenes. You Can Use It Your Own Way Too.
	public var cutscene:VideoHandler;
	#end

	// """Cheat Detection"""
	public static var usedBot:Bool = false;
	public static var wentToChartEditor:Bool = false;

	var tweenBoolshit = true;

	// Default Note X Positions (Non Middlescroll). Used For Modcharts If You Want.
	var notePositions:Array<Float> = [92, 204, 316, 428, 732, 844, 956, 1068];

	public var styleName = "default";

	private var currentTimingShown:FlxText = new FlxText(0, 0, 0, "0ms");
	private var introGroup:FlxTypedGroup<IntroSprite>;
	private var numGroup:FlxTypedGroup<ComboNumber>;
	private var ratingGroup:FlxTypedGroup<Rating>;
	private var events:Array<Event> = null;

	public var hitSound:FlxSound;

	// I'm tired of initStoryLength.
	public static var songsPlayed:Int = 0;

	var lastPos:Float = -5000;

	public var correctY = 698;

	private var desyncs:Int = 0;
	private var iDesyncs:Int = 0;

	// Adding Objects Using Lua
	public function addObject(object:FlxBasic)
		add(object);

	// Removing Objects Using Lua
	public function removeObject(object:FlxBasic)
		remove(object);

	override public function create()
	{
		var stamp:Float = haxe.Timer.stamp();

		FlxG.mouse.visible = FlxG.mouse.enabled = false;

		instance = this;

		// Load User's Keybinds.
		PlayerSettings.player1.controls.loadKeyBinds();

		// Change The Application Title To The Engine Version, Song Name, And Difficulty.
		Application.current.window.title = '${Constants.kecVer}: ${SONG.songName} - [${CoolUtil.difficulties[storyDifficulty]}]';

		initStyle();

		// Stop Freeplay / Story Menu Music.
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		inDaPlay = true;

		// Set Rating Amounts To 0.
		Stats.resetStats();

		highestCombo = 0;

		initGameplaySettings();

		usedBot = PlayStateChangeables.botPlay;

		// Search For Lua Modcharts
		#if (FEATURE_FILESYSTEM && FEATURE_LUAMODCHART)
		executeModchart = OpenFlAssets.exists(Paths.lua('songs/${PlayState.SONG.songId}/modchart')) && PlayStateChangeables.modchart;
		#end
		#if !FEATURE_LUAMODCHART
		executeModchart = false;
		#end

		// Use FileSystem on desktop for cool modcharts with no compile :>

		if (FlxG.save.data.gen)
			Debug.logInfo('Searching for Lua Modchart? ($executeModchart) at ${Paths.lua('songs/${PlayState.SONG.songId}/modchart')}');

		if (executeModchart)
			Conductor.rate = 1;
		// Setup The Cameras.

		// Game Camera (where stage and characters are)
		camGame = FlxG.camera;
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		overlayCam = new FlxCamera();
		overlayCam.bgColor.alpha = 0;

		// HUD Camera (Health Bar, scoreTxt, etc)
		FlxG.cameras.add(camHUD, false);

		// Overlay (Infront Of Everything)
		FlxG.cameras.add(overlayCam, false);

		camHUD.zoom = PlayStateChangeables.zoom;

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();

		persistentUpdate = true;
		persistentDraw = true;

		if (SONG == null)
			SONG = Song.loadFromJson('bopeebo', '');

		// if the song has dialogue, so we don't accidentally try to load a nonexistant file and crash the game
		if (Paths.fileExists('data/songs/${PlayState.SONG.songId}/dialogue.txt'))
			dialogue = CoolUtil.coolTextFile(Paths.txt('data/songs/${PlayState.SONG.songId}/dialogue'));

		introGroup = new FlxTypedGroup<IntroSprite>();
		for (i in 0...3)
			introGroup.add(new IntroSprite());

		numGroup = new FlxTypedGroup<ComboNumber>();
		for (i in 0...9)
		{
			var num:ComboNumber = new ComboNumber();
			num.setup();
			numGroup.add(num);
			num.kill();
		}
		ratingGroup = new FlxTypedGroup<Rating>();

		if (isStoryMode)
		{
			switch (storyWeek)
			{
				case 7:
					inCutscene = true;
				case 5:
					if (PlayState.SONG.songId == 'winter-horrorland')
						inCutscene = true;
			}
		}

		// defaults if no stage was found in chart
		var stageCheck:String = 'stage';

		// If the stage isn't specified in the chart, we use the story week value.
		if (SONG.stage == null)
		{
			switch (storyWeek)
			{
				case 0 | 1:
					stageCheck = 'stage';
				case 2:
					stageCheck = 'halloween';
				case 3:
					stageCheck = 'philly';
				case 4:
					stageCheck = 'limo';
				case 5:
					if (SONG.songId == 'winter-horrorland')
						stageCheck = 'mallEvil';
					else
						stageCheck = 'mall';
				case 6:
					if (SONG.songId == 'thorns')
						stageCheck = 'schoolEvil';
					else
						stageCheck = 'school';
				case 7:
					stageCheck = 'tank';
					// i should check if its stage (but this is when none is found in chart anyway)
			}
		}
		else
			stageCheck = SONG.stage;

		Stage = new Stage(stageCheck);
		Stage.initStageProperties();
		Stage.loadStageData(stageCheck);

		if (!Stage.doesExist)
		{
			Debug.logTrace('Stage Does Not Exist For ${Stage.curStage}. Loading Default Stage.');
			Stage.loadStageData('stage');
			Stage.initStageProperties();
		}

		Stage.inEditor = false;

		// pissed me off that having non existent stages just load black instead of default stage

		if (isStoryMode)
			Conductor.rate = 1;

		initCharacters();

		Stage.initCamPos();

		// Initialize Scripts For Real.

		var positions = Stage.positions[Stage.curStage];
		var charGroup:Array<Character> = [];

		if (gf != null)
			gfGroup.add(gf);

		dadGroup.add(dad);
		boyfriendGroup.add(boyfriend);

		for (g in gfGroup.members)
		{
			g.x += g.data.charPos[0];
			g.y += g.data.charPos[1];
			charGroup.push(g);
		}

		for (d in dadGroup.members)
		{
			d.x += d.data.charPos[0];
			d.y += d.data.charPos[1];
			charGroup.push(d);
		}

		for (b in boyfriendGroup.members)
		{
			b.x += b.data.charPos[0];
			b.y += b.data.charPos[1];
			charGroup.push(b);
		}

		if (positions != null)
		{
			for (char => pos in positions)
				for (person in charGroup)
					if (person.data.char == char)
						person.setPosition(pos[0], pos[1]);
		}

		if (FlxG.save.data.background)
		{
			for (i in Stage.toAdd)
				add(i);

			for (index => array in Stage.layInFront)
			{
				switch (index)
				{
					case 0:
						if (gf != null)
						{
							add(gfGroup);
							gf.scrollFactor.set(0.95, 0.95);
						}
						for (bg in array)
							add(bg);
					case 1:
						add(dadGroup);
						for (bg in array)
							add(bg);
					case 2:
						add(boyfriendGroup);
						for (bg in array)
							add(bg);
				}
			}
		}
		else
		{
			if (gf != null)
			{
				add(gfGroup);
				gf.scrollFactor.set(0.95, 0.95);
			}

			add(dadGroup);
			add(boyfriendGroup);
		}

		if (dad.data.trail)
		{
			if (FlxG.save.data.quality)
			{
				var evilTrail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069);
				add(evilTrail);
			}
		}

		// Camera Positioning.
		camPos = new FlxPoint(0, 0);

		camPos.x = Stage.camPosition[0];
		camPos.y = Stage.camPosition[1];

		if (dad.data.replacesGF && gf != null)
		{
			if (!stageTesting)
				dad.setPosition(gf.x, gf.y);
			gf.visible = false;
			zoomForTweens = 1.3;
		}

		#if FEATURE_HSCRIPT
		initScripts();

		scripts.executeAllFunc("create");
		#end

		var doof = null;

		if (isStoryMode)
		{
			doof = new DialogueBox(false, dialogue);
			doof.scrollFactor.set();
			doof.finishThing = startCountdown;
		}

		stageFollow = FlxPoint.get();
		camFollow = FlxPoint.get();

		camFollowPos = new FlxObject(0, 0, 1, 1);
		camFollowPos.active = false;

		snapCamFollowToPos(camPos.x, camPos.y);

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		if (prevCamFollowPos != null)
		{
			camFollowPos = prevCamFollowPos;
			prevCamFollowPos = null;
		}

		add(camFollowPos);

		camGame.scroll.set();
		camGame.target = null;
		zoomForTweens = Stage.camZoom;

		camGame.follow(camFollowPos, LOCKON, 0.05);
		camGame.zoom = zoomForTweens;
		camGame.focusOn(camFollow);

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		FlxG.fixedTimestep = false;

		arrowLanes = new FlxTypedGroup<FlxSprite>();
		arrowLanes.camera = camHUD;

		add(arrowLanes);

		add(uiGroup = new FlxSpriteGroup());

		Conductor.elapsedPosition = -5000;

		if (PlayStateChangeables.useDownscroll)
			correctY = 135;
		else
			correctY = 698;

		strumLine = new FlxSprite(0, 50).makeGraphic(FlxG.width + 50, 10, FlxColor.WHITE);
		strumLine.scrollFactor.set();

		if (PlayStateChangeables.useDownscroll)
			strumLine.y = FlxG.height - 165;

		strumLineNotes = new FlxTypedGroup<StaticArrow>();
		add(strumLineNotes);

		playerStrums = new FlxTypedGroup<StaticArrow>();
		cpuStrums = new FlxTypedGroup<StaticArrow>();

		Constants.notesplashSprite = NoteStyleHelper.notesplashArray[FlxG.save.data.notesplash];

		switch (STYLE.style.toLowerCase())
		{
			case 'pixel':
				Constants.noteskinPixelSprite = NoteStyleHelper.generatePixelSprite(FlxG.save.data.noteskin);
				Constants.noteskinPixelSpriteEnds = NoteStyleHelper.generatePixelSprite(FlxG.save.data.noteskin, true);
				Constants.notesplashSprite = "Pixel";
			case 'default':
				Constants.noteskinSprite = NoteStyleHelper.generateNoteskinSprite(FlxG.save.data.noteskin);
				Constants.cpuNoteskinSprite = NoteStyleHelper.generateNoteskinSprite(FlxG.save.data.cpuNoteskin);
		}

		tweenBoolshit = SONG.songId != 'tutorial' && SONG.songId != 'roses';

		generateStaticArrows();
		appearStaticArrows(tweenBoolshit);

		// If A Song Doesn't Have Events, It Makes One Automatically.

		generateSong(SONG.songId);

		if (FlxG.save.data.gen)
		{
			if (SONG.songId == null)
				Debug.logInfo('SongID Is Null.');
			else
				Debug.logInfo('Succesfully Loaded ' + SONG.songName);
		}

		if (unspawnNotes.length > 0)
		{
			var firstStrumTime = unspawnNotes[0].strumTime;

			if (firstStrumTime > 5000)
			{
				needSkip = true;
				skipTo = (firstStrumTime - 1000);
			}
		}
		else
			needSkip = false;

		#if FEATURE_DISCORD
		// Making difficulty text for Discord Rich Presence.
		storyDifficultyText = CoolUtil.difficultyFromInt(storyDifficulty);

		iconRPC = SONG.player2;
		// To avoid having duplicate images in Discord assets
		switch (iconRPC)
		{
			case 'senpai-angry':
				iconRPC = 'senpai';
			case 'monster-christmas':
				iconRPC = 'monster';
			case 'mom-car':
				iconRPC = 'mom';
		}

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode)
			detailsText = "Story Mode: Week " + storyWeek;
		else
			detailsText = "Freeplay";

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;

		// Updating Discord Rich Presence.
		Discord.changePresence(detailsText
			+ " "
			+ SONG.songName
			+ " ("
			+ storyDifficultyText
			+ ") "
			+ Ratings.GenerateLetterRank(Stats.accuracy),
			"\nAcc: "
			+ HelperFunctions.truncateFloat(Stats.accuracy, 2)
			+ "% | Score: "
			+ Stats.songScore
			+ " | Misses: "
			+ Stats.misses, iconRPC);
		#end

		#if FEATURE_LUAMODCHART
		if (executeModchart)
		{
			luaModchart = ModchartState.createModchartState();
			luaModchart.executeState('onCreate', [null]);
		}
		#end

		#if FEATURE_LUAMODCHART
		if (executeModchart)
		{
			new LuaCamera(camGame, "camGame").Register(ModchartState.lua);
			new LuaCamera(camHUD, "camHUD").Register(ModchartState.lua);
			new LuaCharacter(dad, "dad").Register(ModchartState.lua);
			if (gf != null)
				new LuaCharacter(gf, "gf").Register(ModchartState.lua);

			new LuaCharacter(boyfriend, "boyfriend").Register(ModchartState.lua);
		}
		#end

		var index = 0;

		var toBeRemoved = [];
		for (i in 0...unspawnNotes.length)
		{
			var dunceNote:Note = unspawnNotes[i];
			if (dunceNote.strumTime < startTime)
				toBeRemoved.push(dunceNote);
		}

		for (i in toBeRemoved)
			unspawnNotes.remove(i);
		if (FlxG.save.data.gen)
			Debug.logTrace("Removed " + toBeRemoved.length + " cuz of start time");

		createBar();

		judgementCounter = new FlxText(20, 0, 0, "", 20);
		judgementCounter.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		judgementCounter.borderSize = 2;
		judgementCounter.borderQuality = 2;
		judgementCounter.scrollFactor.set();
		judgementCounter.cameras = [camHUD];
		judgementCounter.screenCenter(Y);
		judgementCounter.text = 'Marvelous: ${Stats.marvs}\nSicks: ${Stats.sicks}\nGoods: ${Stats.goods}\nBads: ${Stats.bads}\nShits: ${Stats.shits}\nMisses: ${Stats.misses}';
		if (FlxG.save.data.judgementCounter)
			uiGroup.add(judgementCounter);

		botPlayState = new FlxText(565, correctY + (PlayStateChangeables.useDownscroll ? 25 : -175), 0, "BOTPLAY", 20);
		botPlayState.setFormat(Paths.font("vcr.ttf"), 42, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botPlayState.scrollFactor.set();
		botPlayState.borderSize = 2;
		botPlayState.borderQuality = 1;
		botPlayState.alpha = 0.5;
		botPlayState.cameras = [camHUD];

		if (PlayStateChangeables.botPlay)
			uiGroup.add(botPlayState);

		addedBotplay = PlayStateChangeables.botPlay;
		reloadHealthBarColors();

		iconP1 = new HealthIcon(boyfriend.data.icon, true);
		iconP1.y = healthBar.y - (iconP1.height * 0.5);

		iconP2 = new HealthIcon(dad.data.icon, false);
		iconP2.y = healthBar.y - (iconP2.height * 0.5);

		if (FlxG.save.data.healthBar)
		{
			uiGroup.add(iconP1);
			uiGroup.add(iconP2);
		}

		scoreTxt = new FlxText(FlxG.width * 0.5 - 235, correctY, 0, "", 16);
		scoreTxt.screenCenter(X);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderQuality = 2;
		scoreTxt.antialiasing = true; // Should use the save data but its too annoying.
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.text = Ratings.CalculateRanking(Stats.songScore, nps, maxNPS, Stats.accuracy);
		uiGroup.add(scoreTxt);
		updateScoreText();

		for (i in 0...8)
			grpNoteSplashes.add(new NoteSplash(0, 0, '', i % 4)).kill();

		strumLineNotes.camera = camHUD;
		grpNoteSplashes.camera = camHUD;
		notes.camera = camHUD;

		uiGroup.camera = camHUD;
		introGroup.camera = camHUD;
		numGroup.camera = camHUD;
		ratingGroup.camera = camHUD;
		currentTimingShown.camera = camHUD;
		// sfjl

		if (isStoryMode)
			doof.camera = camHUD;
		characterBopper(0);

		if (isStoryMode)
		{
			switch (StringTools.replace(curSong, " ", "-").toLowerCase())
			{
				case "winter-horrorland":
					var blackScreen:FlxSprite = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
					add(blackScreen);
					blackScreen.scrollFactor.set();
					camHUD.visible = false;

					FlxTimer.wait(0.1, function()
					{
						remove(blackScreen);
						FlxG.sound.play(Paths.sound('Lights_Turn_On'));
						snapCamFollowToPos(camFollow.x + 200, -2050);
						camGame.zoom = 1.5;

						FlxTimer.wait(1, function()
						{
							camHUD.visible = true;
							remove(blackScreen);
							createTween(camGame, {zoom: Stage.camZoom}, 2.5, {
								ease: FlxEase.quadInOut,
								onComplete: function(twn:FlxTween)
								{
									inCutscene = false;
									startCountdown();
									camHUD.visible = true;
								}
							});
						});
					});
				case 'senpai':
					schoolIntro(doof);
				case 'roses':
					FlxG.sound.play(Paths.sound('ANGRY'));
					schoolIntro(doof);
				case 'thorns':
					schoolIntro(doof);
				case 'ugh', 'guns', 'stress':
					#if VIDEOS
					playCutscene('${SONG.songId.toLowerCase()}Cutscene.webm', false);
					#end
				default:
					createTimer(0.5, function(timer)
					{
						startCountdown();
					});
			}
		}
		else
			createTimer(0.5, function(timer)
			{
				startCountdown();
			});

		for (i in 1...3)
			precacheThing('styles/$styleName/missnote$i', 'sound');

		startingSong = true;

		// This allow arrow key to be detected by flixel. See https://github.com/HaxeFlixel/flixel/issues/2190
		FlxG.keys.preventDefaultKeys = [];

		Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, handleInput);
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_UP, releaseInput);

		super.create();

		if (FlxG.save.data.quality && FlxG.save.data.background)
		{
			if (Stage.curStage == 'tank' && gf != null && gf.data.char == 'pico-speaker')
			{
				if (FlxG.save.data.quality)
				{
					var firstTank:TankmenBG = new TankmenBG(20, 500, true);
					firstTank.resetShit(20, 1500, true);
					firstTank.strumTime = 10;
					if (Stage.swagBacks['tankmanRun'] != null)
					{
						Stage.swagBacks['tankmanRun'].add(firstTank);

						for (i in 0...TankmenBG.animationNotes.length)
						{
							if (FlxG.random.bool(16))
							{
								var tankBih = Stage.swagBacks['tankmanRun'].recycle(TankmenBG);
								tankBih.strumTime = TankmenBG.animationNotes[i].time;
								tankBih.resetShit(500, 200 + FlxG.random.int(50, 100), TankmenBG.animationNotes[i].data < 2);
								Stage.swagBacks['tankmanRun'].add(tankBih);
							}
						}
					}
				}
			}
		}

		if (PlayStateChangeables.skillIssue)
		{
			var redVignette:FlxSprite = new FlxSprite().loadGraphic(Paths.image('nomisses_vignette'));
			redVignette.screenCenter();
			redVignette.cameras = [overlayCam];
			add(redVignette);
		}

		precacheThing('alphabet', 'image');
		precacheThing('breakfast', 'music');

		hitSound = new FlxSound();
		if (FlxG.save.data.hitSound > 0)
			hitSound.loadEmbedded(Paths.sound('hitsounds/${HitSounds.getSoundByID(FlxG.save.data.hitSound).toLowerCase()}'));

		FlxG.sound.list.add(hitSound);
		createSongPosBar();

		if (FlxG.save.data.showMs)
		{
			insert(members.indexOf(notes), currentTimingShown);
			currentTimingShown.alpha = 0;
		}

		if (FlxG.save.data.showRating)
			insert(members.indexOf(notes), ratingGroup);

		if (FlxG.save.data.showNum)
			insert(members.indexOf(notes), numGroup);

		pushSub(new PauseSubState());
		pushSub(new ResultsScreen());
		pushSub(new GameOverSubstate());
		pushSub(new OptionsMenu(true));

		#if FEATURE_LUAMODCHART
		if (executeModchart)
		{
			luaModchart.executeState('onCreatePost', [null]);
		}
		#end

		#if FEATURE_HSCRIPT
		scripts.executeAllFunc("createPost");
		#end

		Debug.logTrace("Took " + Std.string(FlxMath.roundDecimal(haxe.Timer.stamp() - stamp, 3)) + " Seconds To Load.");
	}

	public function createBar()
	{
		healthBar = new Bar(0, 0, 'healthBar', function() return shownHealth, 0, 2);
		healthBar.screenCenter(X);
		healthBar.goesToRight = false;
		if (FlxG.save.data.healthBar)
			uiGroup.add(healthBar);

		if (PlayStateChangeables.useDownscroll)
			healthBar.y = FlxG.height * 0.11;
		else
			healthBar.y = FlxG.height * 0.89;

		healthBar.scrollFactor.set();

		reloadHealthBarColors();

		// This Function Makes It Easier To Change HealthBar Styles And Shit.
	}

	public function createSongPosBar()
	{
		songPosBar = new Bar(0, FlxG.height - 710, 'healthBar', function() return songPositionBar, 0, 1);
		songPosBar.screenCenter(X);
		songPosBar.goesToRight = true;
		if (PlayStateChangeables.useDownscroll)
			songPosBar.y = FlxG.height - 37;

		uiGroup.add(songPosBar);
		songPosBar.scrollFactor.set();
		songPosBar.setColors(dad.data.barColor, FlxColor.BLACK);
		songPosBar.alpha = 0;

		songName = new FlxText(0, songPosBar.y, 0, SONG.songName, 16);
		songName.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		songName.scrollFactor.set();
		songName.text = SONG.songName + ' (' + FlxStringUtil.formatTime(songLength, false) + ')';
		songName.alpha = 0;
		uiGroup.add(songName);
		songName.screenCenter(X);

		songName.visible = FlxG.save.data.songPosition;
		songPosBar.visible = FlxG.save.data.songPosition;
	}

	function schoolIntro(?dialogueBox:DialogueBox):Void
	{
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		black.screenCenter();
		add(black);

		var red:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFFff1b31);
		red.scrollFactor.set();
		red.screenCenter();
		var senpaiEvil:FlxSprite = new FlxSprite();
		senpaiEvil.frames = Paths.getSparrowAtlas('stages/school/senpaiCrazy');
		senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
		senpaiEvil.antialiasing = false;
		senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * CoolUtil.daPixelZoom));
		senpaiEvil.scrollFactor.set();
		senpaiEvil.updateHitbox();
		senpaiEvil.screenCenter();

		if (PlayState.SONG.songId == 'roses' || PlayState.SONG.songId == 'thorns')
		{
			remove(black);

			if (PlayState.SONG.songId == 'thorns')
			{
				add(red);
				camHUD.visible = false;
			}
		}
		createTween(black, {alpha: 0}, 1.5, {
			onComplete: function(t)
			{
				if (dialogueBox != null)
				{
					inCutscene = true;

					if (PlayState.SONG.songId == 'thorns')
					{
						add(senpaiEvil);
						senpaiEvil.alpha = 0;
						FlxTimer.wait(1.25, function():Void
						{
							createTween(senpaiEvil, {alpha: 1}, 1.5, {
								onComplete: function(t)
								{
									senpaiEvil.animation.play('idle');
									FlxG.sound.play(Paths.sound('Senpai_Dies'), 1, false, null, true, function()
									{
										remove(senpaiEvil);
										remove(red);

										camGame.fade(FlxColor.WHITE, 0.01, true, function()
										{
											add(dialogueBox);
											camHUD.visible = true;
										}, true);
									});
									FlxTimer.wait(2.45, function():Void
									{
										camGame.fade(FlxColor.WHITE, 2, false);
										camGame.shake(0.04, 5);
									});
								}
							});
						});
					}
					else
					{
						add(dialogueBox);
					}
				}
				else
				{
					startCountdown();
				}

				remove(black);
			}
		});
	}

	var startTimer:FlxTimer;

	#if FEATURE_LUAMODCHART
	public static var luaModchart:ModchartState = null;
	#end

	function set_scrollSpeed(value:Float):Float // STOLEN FROM PSYCH ENGINE ONLY SPRITE SCALING PART.
	{
		// speedChanged = true;
		if (generatedMusic)
		{
			var ratio:Float = value / scrollSpeed;
			for (note in notes)
			{
				if (note.animation.curAnim != null)
					if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
					{
						note.scale.y *= ratio;
						note.updateHitbox();
					}
			}
			for (note in unspawnNotes)
			{
				if (note.animation.curAnim != null)
					if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
					{
						note.scale.y *= ratio;
						note.updateHitbox();
					}
			}
		}
		scrollSpeed = value;
		return value;
	}

	public function startCountdown():Void
	{
		#if FEATURE_HSCRIPT
		if (ScriptUtil.hasPause(scripts.executeAllFunc("startCountdown")))
			return;
		#end

		inCutscene = false;

		if (!arrowsShown)
			appearStaticArrows(true);

		Conductor.elapsedPosition = -(Math.floor(Conductor.crochet * 5));
		startedCountdown = true;

		add(introGroup);

		startTimer = createTimer((Conductor.crochet * 0.001), function(t:FlxTimer)
		{
			characterBopper(0);

			switch (t.loopsLeft)
			{
				case 3:
					FlxG.sound.play(Paths.sound('styles/$styleName/intro3'), 0.6);
				case 2:
					FlxG.sound.play(Paths.sound('styles/$styleName/intro2'), 0.6);
					introGroup.members[0].appear(0);
				case 1:
					FlxG.sound.play(Paths.sound('styles/$styleName/intro1'), 0.6);
					introGroup.members[1].appear(1);
				case 0:
					FlxG.sound.play(Paths.sound('styles/$styleName/introGo'), 0.6);
					introGroup.members[2].appear(2);
			}
			#if FEATURE_HSCRIPT
			scripts.executeAllFunc("countTick", [-t.loopsLeft]);
			#end
		}, 4);
	}

	var keys = [false, false, false, false];
	var binds:Array<String> = [
		FlxG.save.data.leftBind,
		FlxG.save.data.downBind,
		FlxG.save.data.upBind,
		FlxG.save.data.rightBind
	];

	private function releaseInput(evt:KeyboardEvent):Void // handles releases
	{
		if (PlayStateChangeables.botPlay)
			return;

		@:privateAccess
		final key = FlxKey.toStringMap.get(evt.keyCode);

		var data = -1;

		data = getKeyFromKeyCode(evt.keyCode);

		switch (evt.keyCode) // arrow keys
		{
			case 37:
				data = 0;
			case 40:
				data = 1;
			case 38:
				data = 2;
			case 39:
				data = 3;
		}

		if (data == -1)
			return;

		keys[data] = false;
		keyReleased(data);
	}

	private function keyReleased(key:Int)
	{
		if (PlayStateChangeables.botPlay || !startedCountdown || paused || key < 0 || key >= playerStrums.length)
			return;

		#if FEATURE_LUAMODCHART
		if (luaModchart != null)
			luaModchart.executeState('onKeyReleased', [key]);
		#end

		final spr:StaticArrow = playerStrums.members[key];
		if (spr != null)
		{
			spr.localAngle = 0;
			spr.playAnim('static');
			spr.resetAnim = 0;
		}

		#if FEATURE_LUAMODCHART
		if (luaModchart != null)
		{
			luaModchart.executeState('onKeyReleased', [key]);
		};
		#end
	}

	private function getKeyFromKeyCode(key:FlxKey):Int
	{
		if (key != NONE)
		{
			for (i in 0...binds.length)
			{
				if (key == binds[i])
				{
					return i;
				}
			}
		}
		return -1;
	}

	private function handleInput(evt:KeyboardEvent):Void
	{ // this actually handles press inputs

		if (PlayStateChangeables.botPlay || paused || !songStarted)
			return;

		// first convert it from openfl to a flixel key code
		// then use FlxKey to get the key's name based off of the FlxKey dictionary
		// this makes it work for special characters

		final eventKey = evt.keyCode;
		final keyName = FlxKey.toStringMap.get(eventKey);
		var key:Int = getKeyFromKeyCode(eventKey);

		switch (eventKey) // arrow keys
		{
			case 37:
				key = 0;
			case 40:
				key = 1;
			case 38:
				key = 2;
			case 39:
				key = 3;
		}

		if (key <= -1)
			return;
		#if debug
		// Prevents crash specifically on debug without needing to try catch shit
		@:privateAccess if (!FlxG.keys._keyListMap.exists(eventKey))
			return;
		#end

		if (FlxG.keys.checkStatus(eventKey, JUST_PRESSED))
			handleHits(key);
	}

	private function handleHits(key:Int)
	{
		final lastConductorTime:Float = Conductor.elapsedPosition;
		keys[key] = true;

		final closestNotes:Array<Note> = notes.members.filter(function(aliveNote:Note)
		{
			return aliveNote != null && aliveNote.alive && aliveNote.canBeHit && aliveNote.mustPress && !aliveNote.wasGoodHit && !aliveNote.isSustainNote
				&& aliveNote.noteData == key;
		});

		final defNotes:Array<Note> = [for (v in closestNotes) v];

		haxe.ds.ArraySort.sort(defNotes, Sort.sortNotes);

		if (closestNotes.length != 0)
		{
			final coolNote = defNotes[0];
			if (defNotes.length > 1) // stacked notes or really close ones
			{
				for (i in 0...defNotes.length)
				{
					if (i == 0) // skip the first note
						continue;

					var note = defNotes[i];

					if (!note.isSustainNote && ((note.strumTime - coolNote.strumTime) < 2) && note.noteData == key)
						destroyNote(note);
				}
			}

			goodNoteHit(coolNote);
		}
		else if (!FlxG.save.data.ghost && songStarted)
			noteMissPress(key);

		#if FEATURE_LUAMODCHART
		if (luaModchart != null)
			luaModchart.executeState('onKeyPressed', [key]);
		#end

		final spr:StaticArrow = playerStrums.members[key];
		if (spr != null
			&& spr.animation.curAnim.name != 'confirm'
			&& spr.animation.curAnim.name != 'pressed'
			&& !spr.animation.curAnim.name.startsWith('dirCon'))
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
		}

		#if FEATURE_LUAMODCHART
		if (luaModchart != null)
		{
			luaModchart.executeState('onKeyPressed', [key]);
		};
		#end

		Conductor.elapsedPosition = lastConductorTime;

		if (FlxG.save.data.hitSound != 0)
		{
			if (FlxG.save.data.strumHit)
			{
				hitSound.stop();
				hitSound.time = 0;
				hitSound.volume = FlxG.save.data.hitVolume;
				hitSound.play();
			}
		}
	}

	private function handleHolds(note:Note)
	{
		// HOLDS, check for sustain notes
		if (keys.contains(true) && generatedMusic)
		{
			goodNoteHit(note);
		}
	}

	private function handleBotplay(note:Note)
	{
		if (note.mustPress && Conductor.elapsedPosition >= note.strumTime && note.botplayHit)
		{
			// Force good note hit regardless if it's too late to hit it or not as a fail safe

			goodNoteHit(note);
		}
	}

	public function characterBopper(beat:Int):Void
	{
		for (b in boyfriendGroup)
		{
			if (b == null)
				continue;
			final doBeat = beat % b.beatsBetween == 0;
			if (doBeat && !b.animation.curAnim.name.startsWith('sing'))
				b.dance(forcedToIdle);
		}

		for (g in gfGroup)
		{
			if (!allowedToHeadbang)
				break;
			if (g == null)
				continue;
			final doBeat = beat % Math.round(gfSpeed * g.beatsBetween) == 0;
			if (doBeat && !g.animation.curAnim.name.startsWith('sing'))
				g.dance();
		}

		for (d in dadGroup)
		{
			if (d == null)
				continue;
			final doBeat = beat % d.beatsBetween == 0;
			if (doBeat && !d.animation.curAnim.name.startsWith('sing'))
				d.dance(forcedToIdle);
		}
	}

	public function playerDance():Void
	{
		for (b in boyfriendGroup)
		{
			if (b == null)
				continue;
			final anim:String = b.animation.curAnim.name;
			if (b.holdTimer > Conductor.stepCrochet * (0.0011 / Conductor.rate) * b.data.holdLength && anim.startsWith('sing') && !anim.endsWith('miss'))
				b.dance();
		}
	}

	function noteMissPress(direction:Int = 1):Void
	{
		if (FlxG.save.data.ghost)
			return;

		health -= 0.08 * PlayStateChangeables.healthLoss;

		if (PlayStateChangeables.skillIssue)
			health = 0;
		if (combo > 5 && gf != null && gf.offsets.exists('sad'))
		{
			gf.playAnim('sad');
		}
		combo = 0;

		Stats.songScore -= 10;
		if (!endingSong)
		{
			Stats.misses++;
		}
		Stats.totalNotesHit -= 1;
		Stats.totalPlayed += 1;

		var char:Character = boyfriend;

		if (char.offsets.exists(Constants.singAnimations[direction] + 'miss'))
			char.playAnim(Constants.singAnimations[direction] + 'miss', true);

		if (FlxG.save.data.missSounds)
		{
			final num = FlxG.random.int(1, 3);
			FlxG.sound.play(Paths.sound('styles/$styleName/missnote$num'), FlxG.random.float(0.1, 0.2));
		}
		if (!SONG.splitVoiceTracks)
			vocals.volume = 0;
		else
		{
			vocalsPlayer.volume = 0;
		}
		updateAccuracy();
		updateScoreText();

		#if FEATURE_HSCRIPT
		scripts.executeAllFunc("ghostTap", [direction]);
		#end
	}

	public var songStarted = false;

	function startSong():Void
	{
		startingSong = false;
		songStarted = true;

		Discord.changePresence(detailsText
			+ " "
			+ SONG.songName
			+ " ("
			+ storyDifficultyText
			+ ") "
			+ Ratings.GenerateLetterRank(Stats.accuracy),
			"\nAcc: "
			+ HelperFunctions.truncateFloat(Stats.accuracy, 2)
			+ "% | Score: "
			+ Stats.songScore
			+ " | Misses: "
			+ Stats.misses, iconRPC, true,
			songLength);

		#if FEATURE_HSCRIPT
		if (ScriptUtil.hasPause(scripts.executeAllFunc("startSong")))
			return;
		#end

		Conductor.elapsedPosition = startTime;
		music(true);

		// Song check real quick
		switch (SONG.songId)
		{
			case 'bopeebo' | 'philly' | 'blammed' | 'cocoa' | 'eggnog':
				allowedToCheer = true;
			default:
				allowedToCheer = false;
		}

		#if FEATURE_LUAMODCHART
		if (executeModchart)
			luaModchart.executeState("onSongStart", [null]);
		#end

		if (inst != null)
			inst.time = startTime;
		if (!SONG.splitVoiceTracks)
		{
			if (vocals != null)
				vocals.time = startTime;
		}
		else
		{
			if (vocalsPlayer != null && vocalsEnemy != null)
			{
				vocalsPlayer.time = startTime;
				vocalsEnemy.time = startTime;
			}
		}

		if (FlxG.save.data.songPosition)
		{
			createTween(songName, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
			createTween(songPosBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		}

		if (needSkip)
		{
			skipActive = true;
			skipText = new Alphabet(0, 550, "Press Space To Skip Intro.", true);
			skipText.setScale(0.5, 0.5);
			skipText.changeX = false;
			skipText.changeY = false;
			if (PlayStateChangeables.useDownscroll)
				skipText.y = 150;
			skipText.snapToPosition();
			skipText.screenCenter(X);
			skipText.alpha = 0;
			createTween(skipText, {alpha: 1}, 0.2);
			skipText.cameras = [camHUD];
			add(skipText);
		}
	}

	var debugNum:Int = 0;

	public var playerNotes = 0;

	var songNotesCount = 0;

	var opponentNotes = 0;

	public function generateSong(dataPath:String):Void
	{
		final chartStamp = haxe.Timer.stamp();
		final songData = SONG;
		try
		{
			if (!SONG.splitVoiceTracks)
			{
				if (SONG.needsVoices)
					vocals = new FlxSound().loadEmbedded(Paths.voices(SONG.audioFile));
				else
					vocals = new FlxSound();
				if (FlxG.save.data.gen)
					trace('loaded vocals');

				FlxG.sound.list.add(vocals);
				vocals.play();
				vocals.pause();
			}
			else
			{
				if (SONG.needsVoices)
				{
					vocalsPlayer = new FlxSound().loadEmbedded(Paths.voices(SONG.audioFile, 'P'));
					vocalsEnemy = new FlxSound().loadEmbedded(Paths.voices(SONG.audioFile, 'E'));
				}
				else
				{
					vocalsEnemy = new FlxSound();
					vocalsPlayer = new FlxSound();
				}

				if (FlxG.save.data.gen)
					trace('loaded vocals');

				FlxG.sound.list.add(vocalsPlayer);
				FlxG.sound.list.add(vocalsEnemy);
				vocalsPlayer.play();
				vocalsPlayer.pause();
				vocalsEnemy.play();
				vocalsEnemy.pause();
			}
		}

		inst = new FlxSound().loadEmbedded(Paths.inst(PlayState.SONG.audioFile));

		initEvents();
		inst.play();
		inst.pause();

		FlxG.sound.list.add(inst);
		curSong = songData.songId;
		activeSong = SONG;

		TimingStruct.setSongTimings(SONG);
		Song.checkforSections(SONG, inst.length);
		Song.recalculateAllSectionTimes(SONG);
		setInitVars();

		Conductor.bpm = SONG.bpm * Conductor.rate;
		var anotherCrochet:Float = Conductor.crochet;
		var anotherStepCrochet:Float = anotherCrochet * 0.25;

		fakeCrochet = Conductor.crochet;
		fakeNoteStepCrochet = fakeCrochet * 0.25;

		songLength = (inst.length / Conductor.rate);

		#if FEATURE_HSCRIPT
		scripts.setAll("bpm", Conductor.bpm);
		#end

		add(grpNoteSplashes);

		notes = new FlxTypedGroup<Note>();
		add(notes);

		final chartNotes:Array<Section> = songData.notes;

		for (section in chartNotes)
		{
			for (i in 0...section.sectionNotes.length)
			{
				final songNotes:ChartNote = section.sectionNotes[i];
				var spawnTime:Float = (songNotes.time - FlxG.save.data.offset - SONG.offset) / Conductor.rate;
				if (spawnTime < 0)
					spawnTime = 0;
				final noteData:Int = Std.int(songNotes.data);
				final noteType:String = songNotes.type;
				final beat = TimingStruct.getBeatFromTime(spawnTime) * Conductor.rate;
				var holdLength:Float = (PlayStateChangeables.holds ? songNotes.length / Conductor.rate : 0);
				var playerNote:Bool = (noteData > 3);

				if (Math.isNaN(holdLength))
					holdLength = 0.0;

				var oldNote:Note;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[unspawnNotes.length - 1];
				else
					oldNote = null;

				var swagNote = new Note(spawnTime, noteData % 4, oldNote, false, false, playerNote, beat);
				swagNote.rawNoteData = noteData;
				swagNote.noteType = noteType;
				swagNote.sustainLength = (PlayStateChangeables.holds ? holdLength : 0);
				swagNote.mustPress = playerNote;

				swagNote.scrollFactor.set(0, 0);
				unspawnNotes.push(swagNote);

				var type = 0;
				final roundSus:Int = Std.int(Math.max((holdLength / anotherStepCrochet), 2));

				if (holdLength > 0)
				{
					swagNote.isParent = true;
					for (susNote in 0...roundSus)
					{
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
						var sustainNote = new Note(spawnTime + (anotherStepCrochet * susNote) + anotherStepCrochet, noteData % 4, oldNote, true, false,
							playerNote, 0);
						sustainNote.rawNoteData = noteData;
						sustainNote.noteType = noteType;
						sustainNote.scrollFactor.set();
						unspawnNotes.push(sustainNote);

						sustainNote.mustPress = playerNote;

						sustainNote.parent = swagNote;
						swagNote.children.push(sustainNote);
						sustainNote.spotInLine = type;
						type++;
					}
				}

				if (swagNote.mustPress && !swagNote.isSustainNote)
					playerNotes++;
				else if (!swagNote.mustPress)
					opponentNotes++;

				songNotesCount++;
			}
		}

		inst.pitch = Conductor.rate;
		if (!SONG.splitVoiceTracks)
			vocals.pitch = Conductor.rate;
		else
		{
			vocalsPlayer.pitch = Conductor.rate;
			vocalsEnemy.pitch = Conductor.rate;
		}

		unspawnNotes.sort(Sort.sortNotes);

		generatedMusic = true;
		if (FlxG.save.data.gen)
			Debug.logInfo('Generated Chart With A Time Of ' + Std.string(FlxMath.roundDecimal(haxe.Timer.stamp() - chartStamp, 3)) + " Seconds.");
	}

	public function spawnNoteSplash(x:Float, y:Float, note:Note)
	{
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.noteType = note.noteType;
		splash.setupNoteSplash(x, y, note);
		grpNoteSplashes.add(splash);
	}

	function spawnNoteSplashOnNote(note:Note)
	{
		var strum:StaticArrow = playerStrums.members[note.noteData];
		if (!note.mustPress)
			strum = cpuStrums.members[note.noteData];
		if (strum != null)
		{
			spawnNoteSplash(strum.x, strum.y, note);
		}
	}

	private function generateStaticArrows():Void
	{
		final seX:Float = (PlayStateChangeables.middleScroll ? -278 : 42);
		final seY:Float = strumLine.y;
		for (i in 0...8)
		{
			final isPlayer:Bool = i > 3;
			final id:Int = i % 4;
			var babyArrow:StaticArrow = new StaticArrow(seX, seY, id, isPlayer);
			babyArrow.downScroll = PlayStateChangeables.useDownscroll;
			babyArrow.alpha = 0;
			babyArrow.ID = i;
			babyArrow.loadLane();
			arrowLanes.add(babyArrow.bgLane);

			if (isPlayer)
				playerStrums.add(babyArrow);
			else
			{
				if (PlayStateChangeables.middleScroll)
				{
					babyArrow.x += 310;
					if (i > 1)
					{ // Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				cpuStrums.add(babyArrow);
			}

			babyArrow.x += Note.swagWidth * id;
			babyArrow.x += 50;
			babyArrow.x += ((FlxG.width / 2) * (isPlayer ? 1 : 0));

			strumLineNotes.add(babyArrow);
		}
	}

	private function appearStaticArrows(t:Bool = true):Void
	{
		if (inCutscene || arrowsShown)
			return;
		var index:Int = 0;
		strumLineNotes.forEachAlive(function(n:StaticArrow)
		{
			var targetAlpha:Float = 1;
			if (index < 4)
			{
				if (PlayStateChangeables.middleScroll)
					targetAlpha = 0.4;
			}

			if (t)
			{
				n.y -= 10;
				n.modAlpha = 0;
				createTween(n, {y: n.y + 10, modAlpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * index % 4)});
			}
			else
			{
				n.modAlpha = targetAlpha;
				n.bgLane.alpha = FlxG.save.data.laneTransparency * n.modAlpha;
			}

			index++;
		});

		arrowsShown = true;
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (paused)
		{
			music(false);

			#if FEATURE_DISCORD
			Discord.changePresence("PAUSED on "
				+ SONG.songName
				+ " ("
				+ storyDifficultyText
				+ ") "
				+ Ratings.GenerateLetterRank(Stats.accuracy),
				"\nAcc: "
				+ HelperFunctions.truncateFloat(Stats.accuracy, 2)
				+ "% | Score: "
				+ Stats.songScore
				+ " | Misses: "
				+ Stats.misses, iconRPC);
			#end
			if (!startTimer.finished)
				startTimer.active = false;
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (PauseSubState.goToOptions)
		{
			if (PauseSubState.goBack)
			{
				PauseSubState.goToOptions = false;
				PauseSubState.goBack = false;
				openSubState(subStates[0]);
			}
			else
				openSubState(subStates[3]);
		}
		else if (paused)
		{
			if (!startTimer.finished)
				startTimer.active = true;
			paused = false;

			#if FEATURE_DISCORD
			Discord.changePresence(detailsText
				+ " "
				+ SONG.songName
				+ " ("
				+ storyDifficultyText
				+ ") "
				+ Ratings.GenerateLetterRank(Stats.accuracy),
				"\nAcc: "
				+ HelperFunctions.truncateFloat(Stats.accuracy, 2)
				+ "% | Score: "
				+ Stats.songScore
				+ " | Misses: "
				+ Stats.misses, iconRPC, true,
				songLength
				- Conductor.elapsedPosition);
			#end

			if (songStarted)
			{
				music(true);
				checkMusicSync();
			}
		}

		super.closeSubState();
	}

	public var paused:Bool = false;

	var startedCountdown:Bool = false;
	var canPause:Bool = true;

	public var nps:Int = 0;
	public var maxNPS:Int = 0;

	var currentLuaIndex = 0;

	override public function update(elapsed:Float)
	{
		setConductorTime();
		if (unspawnNotes[0] != null)
		{
			var shit:Float = 2000;
			if (SONG.speed < 1 || scrollSpeed < 1)
				shit /= scrollSpeed == 1 ? SONG.speed : scrollSpeed;
			var time:Float = shit * Conductor.rate;
			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.elapsedPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];

				notes.insert(0, dunceNote);

				#if FEATURE_LUAMODCHART
				if (executeModchart)
				{
					new LuaNote(dunceNote, currentLuaIndex);
					dunceNote.luaID = currentLuaIndex;
				}
				#end

				unspawnNotes.shift();
				currentLuaIndex++;

				notes.sort(FlxSort.byY, (PlayStateChangeables.useDownscroll ? FlxSort.ASCENDING : FlxSort.DESCENDING));
			}
		}

		#if FEATURE_HSCRIPT
		if (scripts != null)
			scripts.executeAllFunc("update", [elapsed]);
		#end

		#if VIDEOS
		if ((cutscene != null && cutscene.isPlaying && inCutscene) && controls.ACCEPT)
			cutscene.onEndReached.dispatch();
		#end

		if (FlxG.save.data.background)
			Stage.update(elapsed);

		if (inst.playing)
			executeEventCheck();

		if (PlayStateChangeables.botPlay && FlxG.keys.justPressed.F1)
			camHUD.visible = !camHUD.visible;

		#if FEATURE_LUAMODCHART
		if (executeModchart && luaModchart != null)
		{
			luaModchart.setVar('songPos', Conductor.elapsedPosition);
			luaModchart.setVar('hudZoom', camHUD.zoom);
			luaModchart.setVar('curBeat', HelperFunctions.truncateFloat(curDecimalBeat, 3));
			luaModchart.setVar('cameraZoom', camGame.zoom);
			luaModchart.executeState('onUpdate', [elapsed]);

			PlayStateChangeables.useDownscroll = luaModchart.getVar("downscroll", "bool");

			PlayStateChangeables.middleScroll = luaModchart.getVar("middleScroll", "bool");

			camGame.angle = luaModchart.getVar('cameraAngle', 'float');
			camHUD.angle = luaModchart.getVar('camHudAngle', 'float');

			var p1 = luaModchart.getVar("strumLine1Visible", 'bool');
			var p2 = luaModchart.getVar("strumLine2Visible", 'bool');

			for (i in 0...4)
			{
				strumLineNotes.members[i].visible = p1;
				if (i <= playerStrums.length)
					playerStrums.members[i].visible = p2;
			}
		}
		#end

		// reverse iterate to remove oldest notes first and not invalidate the iteration
		// stop iteration as soon as a note is not removed
		// all notes should be kept in the correct order and this is optimal, safe to do every frame/update
		if (notesHitArray.length > 0)
		{
			final data = Date.now().getTime();
			var balls = notesHitArray.length - 1;
			while (balls >= 0)
			{
				var cock:Float = notesHitArray[balls];

				if (cock + 1000 < data)
					notesHitArray.remove(cock);
				else
					break;
				balls--;
			}
			nps = notesHitArray.length;
			if (nps > maxNPS)
				maxNPS = nps;
			updateScoreText();
		}

		if (FlxG.keys.justPressed.NINE)
			iconP1.swapOldIcon();

		if (controls.PAUSE && startedCountdown && canPause && !cannotDie)
		{
			persistentUpdate = false;
			persistentDraw = true;
			paused = true;
			openSubState(subStates[0]);
			for (note in playerStrums)
				if (note.animation.curAnim != null && note.animation.curAnim.name != 'static')
				{
					note.localAngle = 0;
					note.playAnim('static');
					note.resetAnim = 0;
				}
		}

		if (FlxG.keys.justPressed.SEVEN)
		{
			wentToChartEditor = true;
			if (PlayStateChangeables.mirrorMode)
				PlayStateChangeables.mirrorMode = !PlayStateChangeables.mirrorMode;
			executeModchart = false;
			cannotDie = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new ChartingState());
		}

		if (FlxG.keys.justPressed.EIGHT && FlxG.save.data.background)
		{
			paused = true;
			StageDebugState.Stage = Stage;
			StageDebugState.fromEditor = false;
			MusicBeatState.switchState(new StageDebugState(Stage.curStage, if (gf != null) gf.data.char else "gf", boyfriend.data.char, dad.data.char));
			#if FEATURE_LUAMODCHART
			if (luaModchart != null)
			{
				luaModchart.die();
				luaModchart = null;
			}
			#end
		}

		if (FlxG.keys.justPressed.TWO && songStarted && FlxG.save.data.developer)
		{
			if (!usedTimeTravel && Conductor.elapsedPosition + 10000 < inst.length / Conductor.rate)
			{
				usedTimeTravel = true;
				Conductor.elapsedPosition += 10000;
				notes.forEachAlive(function(daNote:Note)
				{
					if (daNote.strumTime - 500 < Conductor.elapsedPosition)
					{
						daNote.active = false;
						daNote.visible = false;

						destroyNote(daNote);
					}
				});

				FlxTimer.wait(0.5, function()
				{
					usedTimeTravel = false;
				});
			}
		}

		if (skipActive && Conductor.elapsedPosition >= skipTo)
		{
			remove(skipText);
			skipActive = false;
		}

		if (FlxG.keys.justPressed.SPACE && skipActive)
		{
			lastPos = skipTo;
			Conductor.elapsedPosition = skipTo;
			Conductor.songPosition = skipTo;
			checkMusicSync();
			createTween(skipText, {alpha: 0}, 0.2);
			skipActive = false;
		}

		FlxG.watch.addQuick("curBPM", Conductor.bpm);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("stepShit", curStep);

		if (health <= 0 && !cannotDie && !PlayStateChangeables.practiceMode)
		{
			if (!usedTimeTravel)
			{
				persistentUpdate = false;
				persistentDraw = false;
				paused = true;
				cannotDie = true;
				if (!SONG.splitVoiceTracks)
					vocals.stop();
				else
				{
					vocalsPlayer.stop();
					vocalsEnemy.stop();
				}
				inst.stop();

				if (FlxG.save.data.InstantRespawn)
					MusicBeatState.resetState();
				else
					openSubState(subStates[2]);

				isDead = true;

				#if FEATURE_DISCORD
				// Game Over doesn't get his own variable because it's only used here
				Discord.changePresence("GAME OVER -- "
					+ SONG.songName
					+ " ("
					+ storyDifficultyText
					+ ") "
					+ Ratings.GenerateLetterRank(Stats.accuracy),
					"\nAcc: "
					+ HelperFunctions.truncateFloat(Stats.accuracy, 2)
					+ "% | Score: "
					+ Stats.songScore
					+ " | Misses: "
					+ Stats.misses, iconRPC);
				#end
			}
			else
				health = 1;
		}
		if (!inCutscene && FlxG.save.data.resetButton)
		{
			var resetBind = FlxKey.fromString(FlxG.save.data.resetBind);

			if ((FlxG.keys.anyJustPressed([resetBind])))
			{
				persistentUpdate = false;
				persistentDraw = false;
				paused = true;
				if (!SONG.splitVoiceTracks)
					vocals.stop();
				else
				{
					vocalsPlayer.stop();
					vocalsEnemy.stop();
				}
				inst.stop();
				if (FlxG.save.data.InstantRespawn)
					MusicBeatState.resetState();
				else
					openSubState(subStates[2]);
				isDead = true;

				#if FEATURE_DISCORD
				Discord.changePresence("GAME OVER -- "
					+ SONG.songName
					+ " ("
					+ storyDifficultyText
					+ ") "
					+ Ratings.GenerateLetterRank(Stats.accuracy),
					"\nAcc: "
					+ HelperFunctions.truncateFloat(Stats.accuracy, 2)
					+ "% | Score: "
					+ Stats.songScore
					+ " | Misses: "
					+ Stats.misses, iconRPC);
				#end
			}
		}

		super.update(elapsed);

		if (FlxG.save.data.smoothHealthbar)
			shownHealth = CoolUtil.fpsLerp(shownHealth, health, 0.15, 60 * Conductor.rate);
		else
			shownHealth = health;

		iconP1.updateHealthIcon(health);
		iconP2.updateHealthIcon(2 - health);

		// Camera Related Stuff.

		playerDance();

		if (!paused)
		{
			var bpmRatio = Conductor.bpm * 0.01;
			var lerpVal:Float = CoolUtil.boundTo(1 - (elapsed * 3.125 * bpmRatio * zoomMultiplier), 0, 1);
			camGame.zoom = FlxMath.lerp(zoomForTweens, camGame.zoom, lerpVal);
			camHUD.zoom = FlxMath.lerp(PlayStateChangeables.zoom * zoomForHUDTweens, camHUD.zoom, lerpVal);
			camFollowPos.setPosition(camFollow.x, camFollow.y);
		}

		if (generatedMusic && !inCutscene)
		{
			// hell
			// note scroll code (mostly)

			notes.forEachAlive(function(daNote:Note)
			{
				if (daNote.noteData == -1)
				{
					Debug.logWarn('Weird Note detected! Note Data = "${daNote.rawNoteData}" is not valid, deleting...');
					destroyNote(daNote);
				}

				if (!daNote.active)
				{
					destroyNote(daNote);
					return;
				}

				final strum:StaticArrow = daNote.mustPress ? playerStrums.members[daNote.noteData] : cpuStrums.members[daNote.noteData];

				#if FEATURE_HSCRIPT
				if (!ScriptUtil.hasPause(scripts.executeAllFunc("notesUpdate", [daNote])))
				{
					scripts.executeAllFunc("notesUpdate", [daNote]);
				};
				#end

				daNote.followStaticArrow(strum);
				daNote.clipToStaticArrow(strum);

				if (!daNote.mustPress)
				{
					if (Conductor.elapsedPosition >= daNote.strumTime && daNote.botplayHit)
						opponentNoteHit(daNote);
				}
				else
				{
					if (PlayStateChangeables.botPlay)
						handleBotplay(daNote);
					else if (!PlayStateChangeables.botPlay && daNote.isSustainNote && daNote.canBeHit && daNote.mustPress && keys[daNote.noteData]
						&& daNote.sustainActive)
						handleHolds(daNote);
				}

				if (daNote.exists)
				{
					if (Conductor.elapsedPosition > Ratings.timingWindows[0].timingWindow + daNote.strumTime)
					{
						if (daNote != null)
						{
							if (daNote.isSustainNote)
							{
								destroyNote(daNote);
								return;
							}

							if (daNote.mustPress && daNote.tooLate && !daNote.canBeHit)
							{
								switch (daNote.noteType.toLowerCase())
								{
									case 'hurt':
									default:
										if (daNote.isParent && daNote.visible)
										{
											// Debug.logTrace("User failed Sustain note at the start of sustain.");
											for (i in daNote.children)
											{
												i.sustainActive = false;
												i.clipRect = null;
											}
											health -= (daNote.missHealth * PlayStateChangeables.healthLoss);
											noteMiss(daNote.noteData, daNote);
										}
										else
										{
											if (!daNote.wasGoodHit && daNote.causesMisses)
											{
												health -= (daNote.missHealth * PlayStateChangeables.healthLoss);
												// Debug.logTrace("User failed note.");
												noteMiss(daNote.noteData, daNote);
											}
										}
								}
								destroyNote(daNote);
							}
						}
					}

					if (!PlayStateChangeables.botPlay)
						if (daNote != null)
							if (daNote.mustPress)
							{
								if (!daNote.wasGoodHit && daNote.isSustainNote && daNote.sustainActive && !daNote.isSustainEnd && daNote.causesMisses
									&& !keys[daNote.noteData])
								{
									// Debug.logTrace("User released key while playing a sustain at: " + daNote.spotInLine);
									for (i in daNote.parent.children)
									{
										i.sustainActive = false;
										i.clipRect = null;
									}

									health -= (daNote.missHealth * PlayStateChangeables.healthLoss);
									noteMiss(daNote.noteData, daNote);
								}
							}
				}
			});
		}

		if (FlxG.keys.justPressed.ONE && FlxG.save.data.developer)
			endSong();

		var iconOffset:Int = 26;

		iconP1.x = healthBar.imageCenter + (150 * iconP1.size.x - 150) * 0.5 - iconOffset;
		iconP2.x = healthBar.imageCenter - (150 * iconP2.size.x) * 0.5 - iconOffset * 2;

		#if FEATURE_LUAMODCHART
		if (executeModchart && luaModchart != null)
		{
			luaModchart.executeState('onUpdatePost', [elapsed]);
		}
		#end
		#if FEATURE_HSCRIPT
		if (scripts != null)
			scripts.executeAllFunc("updatePost", [elapsed]);
		#end
	}

	function checkMusicSync()
	{
		if (!generatedMusic || paused || !songStarted || endingSong)
			return;
		if (Math.abs(Conductor.songPosition - inst.time) > 75)
			resyncInstToPosition();
		if (SONG.needsVoices)
		{
			var checkVocals = [vocals];
			if (SONG.splitVoiceTracks)
				checkVocals = [vocalsPlayer, vocalsEnemy];
			for (voc in checkVocals)
			{
				if (voc.playing)
					if (Math.abs(inst.time - voc.time) > 20)
						if (Conductor.songPosition <= voc.length)
						{
							voc.time = inst.time;
							voc.pitch = inst.pitch;
							// desyncs++;
							// Debug.logTrace('Vocal Desyncs $desyncs');
						}
			}
		}
	}

	function resyncInstToPosition()
	{
		inst.time = Conductor.songPosition;
		inst.pitch = Conductor.rate;
		// iDesyncs++;
		// Debug.logTrace('Inst Desyncs $iDesyncs');
	}

	function endSong():Void
	{
		camZooming = false;
		endingSong = true;
		inDaPlay = false;
		Lib.current.stage.removeEventListener(KeyboardEvent.KEY_DOWN, handleInput);
		Lib.current.stage.removeEventListener(KeyboardEvent.KEY_UP, releaseInput);

		#if FEATURE_LUAMODCHART
		if (luaModchart != null)
		{
			luaModchart.die();
			luaModchart = null;
		}
		#end

		canPause = false;
		inst.volume = 0;
		if (!SONG.splitVoiceTracks)
		{
			vocals.volume = 0;
			vocals.stop();
		}
		else
		{
			vocalsPlayer.volume = 0;
			vocalsPlayer.stop();
			vocalsEnemy.volume = 0;
			vocalsEnemy.stop();
		}
		inst.stop();

		var legitTimings:Bool = true;
		for (rating in Ratings.timingWindows)
		{
			if (rating.timingWindow != rating.defaultTimingWindow)
			{
				legitTimings = false;
				break;
			}
		}

		var superMegaConditionShit:Bool = legitTimings
			&& !usedBot
			&& !FlxG.save.data.practice
			&& PlayStateChangeables.holds
			&& !PlayState.wentToChartEditor
			&& HelperFunctions.truncateFloat(PlayStateChangeables.healthGain, 2) <= 1
			&& HelperFunctions.truncateFloat(PlayStateChangeables.healthLoss, 2) >= 1;

		if (superMegaConditionShit)
		{
			Highscore.saveScore(PlayState.SONG.songId, Math.round(Stats.songScore), storyDifficulty, Conductor.rate);
			Highscore.saveCombo(PlayState.SONG.songId, Ratings.GenerateComboRank(Stats.accuracy), storyDifficulty, Conductor.rate);
			Highscore.saveAcc(PlayState.SONG.songId, HelperFunctions.truncateFloat(Stats.accuracy, 2), storyDifficulty, Conductor.rate);
			Highscore.saveLetter(PlayState.SONG.songId, Ratings.GenerateLetterRank(Stats.accuracy), storyDifficulty, Conductor.rate);
		}

		storyPlaylist.shift();
		Conductor.songPosition = inst.length - 1;

		#if FEATURE_HSCRIPT
		if (ScriptUtil.hasPause(scripts.executeAllFunc("endSong")))
			return;
		#end
		fadeOutHUD();

		FlxTimer.wait(1.2, function()
		{
			if (isStoryMode)
			{
				Stats.addCampaignStats();
				#if FEATURE_LUAMODCHART
				if (luaModchart != null)
				{
					luaModchart.die();
					luaModchart = null;
				}
				#end

				paused = true;
				inst.stop();

				if (!SONG.splitVoiceTracks)
					vocals.stop();
				else
				{
					vocalsPlayer.stop();
					vocalsEnemy.stop();
				}

				if (storyPlaylist.length <= 0)
				{
					if (SONG.validScore)
						Highscore.saveWeekScore(storyWeek, Stats.campaignScore, storyDifficulty, 1);

					if (FlxG.save.data.scoreScreen)
					{
						persistentUpdate = false;
						openSubState(subStates[1]);
					}
					else
					{
						Constants.freakyPlaying = false;
						MusicBeatState.switchState(new StoryMenuState());
						Stats.resetCampaignStats();
					}
				}
				else
				{
					var diff:String = CoolUtil.getSuffixFromDiff(CoolUtil.difficulties[storyDifficulty]);

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					Debug.logInfo('Loading Next Story Song ${PlayState.storyPlaylist[0]}${diff}');

					PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0], diff);
					inst.stop();

					MusicBeatState.switchState(new PlayState());
				}
			}
			else
			{
				paused = true;
				inst.stop();
				if (!SONG.splitVoiceTracks)
					vocals.stop();
				else
				{
					vocalsPlayer.stop();
					vocalsEnemy.stop();
				}
				if (FlxG.save.data.scoreScreen)
				{
					persistentUpdate = false;
					openSubState(subStates[1]);
				}
				else
				{
					Constants.freakyPlaying = false;
					MusicBeatState.switchState(new FreeplayState());
				}
			}
		});
	}

	private function fadeOutHUD()
	{
		if (!isStoryMode || storyPlaylist.length <= 0)
		{
			if (FlxG.save.data.songPosition)
			{
				createTween(songName, {alpha: 0}, 1, {ease: FlxEase.circIn});
				createTween(songPosBar, {alpha: 0}, 1, {ease: FlxEase.circIn});
			}
			createTween(judgementCounter, {alpha: 0}, 1, {ease: FlxEase.circIn});
			createTween(scoreTxt, {alpha: 0}, 1, {ease: FlxEase.circIn});
			createTween(healthBar, {alpha: 0}, 1, {ease: FlxEase.circIn});
			createTween(iconP1, {alpha: 0}, 1, {ease: FlxEase.circIn});
			createTween(iconP2, {alpha: 0}, 1, {ease: FlxEase.circIn});
			for (note in 0...strumLineNotes.length)
				createTween(strumLineNotes.members[note], {y: strumLineNotes.members[note].y - 10, alpha: 0}, 0.4, {
					ease: FlxEase.circOut,
					startDelay: 0.2 + (0.1 * note),
				});
		}
	}

	public var endingSong:Bool = false;

	public function getRatesScore(rate:Float, score:Float):Float
	{
		var rateX:Float = 1;
		var lastScore:Float = score;
		var pr = rate - 0.05;
		if (pr < 1.00)
			pr = 1;

		while (rateX <= pr)
		{
			if (rateX > pr)
				break;
			lastScore = score + ((lastScore * rateX) * 0.022);
			rateX += 0.05;
		}

		var actualScore = Math.round(score + (Math.floor((lastScore * pr)) * 0.022));

		return actualScore;
	}

	private function popUpScore(daNote:Note):Void
	{
		var noteDiff:Float = (daNote.strumTime - Conductor.elapsedPosition);
		if (PlayStateChangeables.botPlay)
			noteDiff = 0;
		var noteDiffAbs = Math.abs(noteDiff);
		var daRating:RatingWindow = Ratings.judgeNote(noteDiff);

		var wife:Float = 0;
		if (!daNote.isSustainNote)
			wife = kec.util.EtternaFunctions.wife3(noteDiffAbs);

		if (!SONG.splitVoiceTracks)
			vocals.volume = 1;
		else
			vocalsPlayer.volume = 1;

		var score:Float = 0;

		if (FlxG.save.data.accuracyMod == 1)
			Stats.totalNotesHit += wife;
		else
			Stats.totalNotesHit += daRating.accuracyBonus;

		Stats.totalPlayed += 1;

		daNote.rating = daRating;

		switch (daRating.name.toLowerCase())
		{
			case 'shit':
				Stats.shits += 1;
			case 'bad':
				Stats.bads += 1;
			case 'good':
				Stats.goods += 1;
			case 'sick':
				Stats.sicks += 1;
			case 'marv':
				Stats.marvs += 1;
		}

		if (!daNote.isSustainNote)
			ResultsScreen.instance.registerHit(daNote);

		if (daRating.causeMiss)
		{
			Stats.misses++;
			combo = 0;
		}

		score = daRating.scoreBonus;
		var result = 0.06;
		switch (daNote.noteType.toLowerCase())
		{
			case 'must press':
				result = 0.8;
			default:
				result = daRating.healthBonus > 0 ? daRating.healthBonus * PlayStateChangeables.healthGain : daRating.healthBonus * PlayStateChangeables.healthLoss;
		}

		health += result;

		daRating.count++;

		if ((daRating.doNoteSplash && daNote.canNoteSplash)
			&& (!PlayStateChangeables.botPlay || FlxG.save.data.cpuStrums)
			&& FlxG.save.data.notesplashes)
		{
			spawnNoteSplashOnNote(daNote);
		}

		if (FlxG.save.data.scoreMod == 1)
			score = kec.util.EtternaFunctions.getMSScore(noteDiffAbs);
		else if (Conductor.rate >= 1.05)
			score = getRatesScore(Conductor.rate, score);

		Stats.songScore += Math.round(score);

		if (FlxG.save.data.showMs)
		{
			msTiming = HelperFunctions.truncateFloat(noteDiff, 2);
			if (PlayStateChangeables.botPlay)
				msTiming = 0;
		}

		var seperatedScore:Array<Int> = [];

		var comboSplit:Array<String> = (combo + "").split('');

		if (combo > highestCombo)
			highestCombo = combo - 1;

		// make sure we have 3 digits to display (looks weird otherwise lol)
		if (comboSplit.length == 1)
		{
			seperatedScore.push(0);
			seperatedScore.push(0);
		}
		else if (comboSplit.length == 2)
			seperatedScore.push(0);

		for (i in 0...comboSplit.length)
		{
			var str:String = comboSplit[i];
			seperatedScore.push(Std.parseInt(str));
		}

		var daLoop:Int = 0;
		if (!PlayStateChangeables.botPlay)
		{
			var rating:Rating = ratingGroup.recycle(Rating);
			rating.setup();
			rating.x = FlxG.save.data.changedHitX;
			rating.y = FlxG.save.data.changedHitY;
			rating.loadRating(daRating.name.toLowerCase());

			if (FlxG.save.data.showMs)
			{
				currentTimingShown.alpha = 1;
				tweenManager.cancelTweensOf(currentTimingShown);
				currentTimingShown.alpha = 1;
			}
			tweenManager.completeTweensOf(rating);
			currentTimingShown.color = daRating.displayColor;
			currentTimingShown.font = Paths.font('vcr.ttf');
			currentTimingShown.borderStyle = OUTLINE_FAST;
			currentTimingShown.borderSize = 1;
			currentTimingShown.borderColor = FlxColor.BLACK;
			currentTimingShown.text = msTiming + "ms";
			currentTimingShown.size = 20;
			currentTimingShown.screenCenter();
			currentTimingShown.x = rating.x + 100;
			currentTimingShown.alignment = FlxTextAlign.RIGHT;
			currentTimingShown.y = rating.y + 100;

			if (STYLE.style == 'Pixel')
			{
				currentTimingShown.x -= 15;
				currentTimingShown.y -= 15;
			}
			currentTimingShown.updateHitbox();

			for (i in seperatedScore)
			{
				var num:ComboNumber = numGroup.recycle(ComboNumber);
				tweenManager.cancelTweensOf(num);
				num.setup();
				num.loadNum(i);
				num.x = rating.x + (43 * daLoop) - ((num.width * seperatedScore.length) * 0.5) + 25;
				num.y = rating.y + 100;
				num.fadeOut();
				daLoop++;
			}
			numGroup.sort(Sort.sortUI, -1);
			ratingGroup.sort(Sort.sortUI, -1);
			rating.fadeOut();
			createTween(currentTimingShown, {alpha: 0}, 0.25, {
				startDelay: (Conductor.crochet * 0.0005)
			});
		}
	}

	var upHold:Bool = false;
	var downHold:Bool = false;
	var rightHold:Bool = false;
	var leftHold:Bool = false;

	public function changeScrollSpeed(mult:Float, time:Float, ease):Void
	{
		var newSpeed = 1 * mult;
		if (time <= 0)
		{
			scrollSpeed = newSpeed;
		}
		else
		{
			scrollTween = createTween(this, {scrollSpeed: newSpeed}, time, {
				ease: ease,
				onUpdate: function(twn:FlxTween)
				{
					mult = scrollSpeed / FlxG.save.data.scrollSpeed;
					scrollMult = mult;
				},
				onComplete: function(twn:FlxTween)
				{
					scrollTween = null;
				}
			});
		}

		speedChanged = true;

		scrollMult = mult;
	}

	function noteMiss(direction:Int = 1, ?daNote:Note):Void
	{
		if (daNote.causesMisses)
		{
			if (gf != null && combo > 5 && gf.offsets.exists('sad'))
				gf.playAnim('sad');
			if (combo != 0)
				combo = 0;

			if (!endingSong)
				Stats.misses++;

			daNote.rating = Ratings.timingWindows[0];

			Stats.totalNotesHit -= 1;
			Stats.totalPlayed += 1;

			Stats.songScore -= 10;

			if (FlxG.save.data.missSounds)
			{
				final num = FlxG.random.int(1, 3);
				FlxG.sound.play(Paths.sound('styles/$styleName/missnote$num'), FlxG.random.float(0.1, 0.2));
			}

			var char:Character = boyfriend;

			if (char.offsets.exists(Constants.singAnimations[direction] + 'miss'))
				char.playAnim(Constants.singAnimations[direction] + 'miss', true);

			#if FEATURE_LUAMODCHART
			if (luaModchart != null)
				luaModchart.executeState('playerOneMiss', [direction, Conductor.elapsedPosition]);
			#end
			#if FEATURE_HSCRIPT
			scripts.executeAllFunc("noteMiss", [daNote]);
			#end

			health -= (daNote.missHealth * PlayStateChangeables.healthLoss);

			if (PlayStateChangeables.skillIssue)
				health = 0;
			if (!SONG.splitVoiceTracks)
				vocals.volume = 0;
			else
				vocalsPlayer.volume = 0;
			updateAccuracy();
			updateScoreText();
		}
	}

	function updateAccuracy()
	{
		#if FEATURE_HSCRIPT
		if (ScriptUtil.hasPause(scripts.executeAllFunc("updateAccuracy")))
			return;
		#end

		Stats.accuracy = Math.max(0, Stats.totalNotesHit / Stats.totalPlayed * 100);
		Stats.accuracyDefault = Math.max(0, Stats.totalNotesHitDefault / Stats.totalPlayed * 100);

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence (with Time Left)
		Discord.changePresence(detailsText
			+ " "
			+ SONG.songName
			+ " ("
			+ storyDifficultyText
			+ ") "
			+ Ratings.GenerateLetterRank(Stats.accuracy),
			"\nAcc: "
			+ HelperFunctions.truncateFloat(Stats.accuracy, 2)
			+ "% | Score: "
			+ Stats.songScore
			+ " | Misses: "
			+ Stats.misses, iconRPC, true,
			songLength
			- Conductor.elapsedPosition);
		#end

		judgementCounter.text = '';

		var timingWins = Ratings.timingWindows.copy();
		timingWins.reverse();

		for (rating in timingWins)
			judgementCounter.text += '${rating.name}s: ${rating.count}\n';

		judgementCounter.text += 'Misses: ${Stats.misses}';

		judgementCounter.updateHitbox();
	}

	function updateScoreText()
	{
		#if FEATURE_HSCRIPT
		if (ScriptUtil.hasPause(scripts.executeAllFunc("updateScoreText")))
			return;
		#end

		scoreTxt.text = Ratings.CalculateRanking(Stats.songScore, nps, maxNPS,
			(FlxG.save.data.roundAccuracy ? FlxMath.roundDecimal(Stats.accuracy, 0) : Stats.accuracy));
		scoreTxt.screenCenter(X);
		scoreTxt.updateHitbox();
	}

	function opponentNoteHit(daNote:Note):Void
	{
		if (SONG.songId != 'tutorial')
			camZooming = FlxG.save.data.camzoom;
		var altAnim:String = "";

		if (daNote.noteType.toLowerCase() == 'alt')
		{
			altAnim = '-alt';
		}
		if (!daNote.wasGoodHit)
		{
			noteCamera(daNote);
			if (daNote.isParent)
				for (i in daNote.children)
					i.sustainActive = true;

			if (PlayStateChangeables.healthDrain)
			{
				if (!daNote.isSustainNote)
				{
					updateScoreText();
					health -= 0.04 * PlayStateChangeables.healthLoss;
					if (health <= 0.01)
					{
						health = 0.01;
					}
				}
			}

			if (!daNote.isSustainEnd)
			{
				final singData:Int = daNote.noteData;

				if (daNote.canPlayAnims)
				{
					var char:Character = dad;

					if (daNote.noteType.toLowerCase() == 'gf' && gf != null)
						char = gf;
					var animToPlay:String = Constants.singAnimations[daNote.noteData] + altAnim;
					if (daNote.isSustainNote)
					{
						var holdAnim:String = animToPlay + '-hold';
						if (char.offsets.exists(holdAnim))
							animToPlay = holdAnim;
					}
					char.playAnim(animToPlay, true);
					char.holdTimer = 0;
				}

				if (FlxG.save.data.cpuStrums)
				{
					pressArrow(cpuStrums.members[daNote.noteData], daNote, fakeNoteStepCrochet * 1.25 * 0.001);
				}

				if (SONG.needsVoices)
				{
					if (!SONG.splitVoiceTracks)
						vocals.volume = 1;
					else
						vocalsEnemy.volume = 1;
				}
			}

			if (!daNote.isSustainNote)
			{
				if (FlxG.save.data.cpuStrums)
				{
					if (FlxG.save.data.cpuSplash && daNote.canNoteSplash)
					{
						spawnNoteSplashOnNote(daNote);
					}
				}
			}

			#if FEATURE_LUAMODCHART
			if (luaModchart != null)
				luaModchart.executeState('opponentNoteHit', [Math.abs(daNote.noteData), Conductor.elapsedPosition]);
			#end

			#if FEATURE_HSCRIPT
			scripts.executeAllFunc("opponentNoteHit", [daNote]);
			#end

			if (!daNote.isSustainNote)
				destroyNote(daNote);

			daNote.wasGoodHit = true;
		}
	}

	function goodNoteHit(note:Note):Void
	{
		// add newest note to front of notesHitArray
		// the oldest notes are at the end and are removed first

		if (!note.isSustainNote)
		{
			var noteDate:Date = Date.now();
			notesHitArray.unshift(noteDate.getTime());
		}

		if (note.wasGoodHit)
			return;

		noteCamera(note);
		if (!note.isSustainNote)
		{
			if (FlxG.save.data.hitSound != 0)
			{
				if (!FlxG.save.data.strumHit)
				{
					hitSound.stop();
					hitSound.time = 0;
					hitSound.volume = FlxG.save.data.hitVolume;
					hitSound.play();
				}
			}
			/* Enable Sustains to be hit. 
				// This is to prevent hitting sustains if you hold a strum before the note is coming without hitting the note parent. 
				(I really hope I made me understand lol.) */
			if (note.isParent)
				for (i in note.children)
					i.sustainActive = true;

			if (note.canRate)
			{
				combo += 1;
				popUpScore(note);
			}
		}

		if (!note.isSustainEnd)
		{
			var char:Character = boyfriend;

			switch (note.noteType.toLowerCase())
			{
				case 'hurt':
					if (FlxG.save.data.notesplashes && !note.isSustainNote)
					{
						spawnNoteSplashOnNote(note);
					}
					Stats.totalPlayed += 1;
					note.rating = Ratings.timingWindows[0];
					health -= 0.8;
					char.playAnim('hurt');
			}

			var altAnim:String = "";
			if (note.noteType.toLowerCase() == 'alt')
				altAnim = '-alt';

			if (note.canPlayAnims)
			{
				if (note.noteType.toLowerCase() == 'gf' && gf != null)
					char = gf;

				var animToPlay:String = Constants.singAnimations[note.noteData] + altAnim;
				if (note.isSustainNote)
				{
					var holdAnim:String = animToPlay + '-hold';
					if (char.offsets.exists(holdAnim))
						animToPlay = holdAnim;
				}
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}

			#if FEATURE_LUAMODCHART
			if (luaModchart != null)
				luaModchart.executeState('goodNoteHit', [Math.abs(note.noteData), Conductor.elapsedPosition]);
			#end

			#if FEATURE_HSCRIPT
			scripts.executeAllFunc("goodNoteHit", [note]);
			#end

			if (PlayStateChangeables.botPlay && FlxG.save.data.cpuStrums)
				pressArrow(playerStrums.members[note.noteData], note, fakeNoteStepCrochet * 1.25 * 0.001);
			else if (!PlayStateChangeables.botPlay)
			{
				var spr = playerStrums.members[note.noteData];
				if (spr != null)
					if (!FlxG.save.data.stepMania)
						spr.playAnim('confirm', true);
					else
					{
						spr.localAngle = note.originAngle;
						spr.playAnim('dirCon' + note.originColor, true);
					}
			}
		}

		if (!note.isSustainNote)
		{
			destroyNote(note);
			updateAccuracy();
			updateScoreText();
		}

		if (!SONG.splitVoiceTracks)
			vocals.volume = 1;
		else
			vocalsPlayer.volume = 1;

		note.wasGoodHit = true;
	}

	function pressArrow(spr:StaticArrow, daNote:Note, time:Float)
	{
		if (spr != null)
		{
			if (!FlxG.save.data.stepMania)
				spr.playAnim('confirm', true);
			else
			{
				spr.localAngle = daNote.originAngle;
				spr.playAnim('dirCon' + daNote.originColor, true);
			}
			spr.resetAnim = time;
		}
	}

	var danced:Bool = false;

	override function stepHit(curStep:Int)
	{
		super.stepHit(curStep);
		if (curStep < 0)
			return;

		iconP1.onStepHit(curStep);
		iconP2.onStepHit(curStep);

		// HARDCODING FOR MILF ZOOMS!
		if (PlayState.SONG.songId == 'milf' && curStep >= 672 && curStep < 800 && camZooming)
		{
			zoomMultiplier += 0.02;
			if (curStep % 4 == 0)
			{
				camGame.zoom += 0.015 * zoomMultiplier;
				camHUD.zoom += 0.05 * zoomMultiplier;
			}
		}
		if (PlayState.SONG.songId == 'milf' && curStep >= 800)
			zoomMultiplier = 1;

		#if FEATURE_LUAMODCHART
		if (executeModchart && luaModchart != null)
		{
			luaModchart.setVar('curStep', curStep);
			luaModchart.executeState('stepHit', [curStep]);
		}
		#end

		#if FEATURE_HSCRIPT
		scripts.setAll("curStep", curStep);
		scripts.executeAllFunc("stepHit", [curStep]);
		#end

		if (isStoryMode)
		{
			if (SONG.songId == 'eggnog' && curStep == 938 * Conductor.rate)
			{
				camGame.visible = false;
				camHUD.visible = false;

				FlxG.sound.play(Paths.sound('Lights_Shut_off'));
				createTimer(3, function(tmr)
				{
					endSong();
				});
			}
		}

		if (curStep % 32 == 28 && curStep != 316 && SONG.songId == 'bopeebo')
		{
			boyfriend.playAnim('hey', true);
			if (gf != null)
				gf.playAnim('cheer', true);
		}
		if ((curStep == 190 * Conductor.rate || curStep == 446 * Conductor.rate) && SONG.songId == 'bopeebo')
		{
			boyfriend.playAnim('hey', true);
			if (gf != null)
				gf.playAnim('cheer', true);
		}
	}

	override function beatHit(curBeat:Int)
	{
		super.beatHit(curBeat);
		#if FEATURE_LUAMODCHART
		if (executeModchart && luaModchart != null)
		{
			luaModchart.executeState('beatHit', [curBeat]);
		}
		#end

		#if FEATURE_HSCRIPT
		scripts.setAll("curBeat", curBeat);
		scripts.executeAllFunc("beatHit", [beatHit]);
		#end
		characterBopper(curBeat);
	}

	override function sectionHit():Void
	{
		super.sectionHit();

		if (curSection < 0)
			return;
		if (camZooming && camGame.zoom < 1.35)
		{
			camGame.zoom += 0.015;
			camHUD.zoom += 0.03;
		}

		#if FEATURE_HSCRIPT
		scripts.setAll("curSection", curSection);
		scripts.executeAllFunc("sectionHit", [curSection]);
		#end
		var char:Character = boyfriend;

		if (currentSection != null)
		{
			switch (currentSection.mustHitSection)
			{
				case true:
					#if FEATURE_LUAMODCHART
					if (luaModchart != null)
						luaModchart.executeState('playerOneTurn', []);
					#end

					#if FEATURE_HSCRIPT
					scripts.executeAllFunc("playerOneTurn");
					#end
				case false:
					#if FEATURE_LUAMODCHART
					if (luaModchart != null)
						luaModchart.executeState('playerTwoTurn', []);
					#end

					#if FEATURE_HSCRIPT
					scripts.executeAllFunc("playerTwoTurn");
					#end
					char = dad;
			}
		}
		changeCameraFocus(char);
	}

	function changeCameraFocus(char:Character)
	{
		if (Stage.staticCam || char == null)
			return;

		var point = char.getMidpoint();
		camFollow.set(point.x + char.data.camPos[0] / char.scrollFactor.x, point.y + char.data.camPos[1] / char.scrollFactor.y);
		point.put();

		camFollow.x += camNoteX;
		camFollow.y += camNoteY;
	}

	public function cacheChar(newCharacter:String, type:Int)
	{
		switch (type)
		{
			case 0:
				if (!dadMap.exists(newCharacter))
				{
					var newDad:Character = new Character(0, 0, newCharacter, false, false);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					newDad.alpha = 0.00001;
				}

			case 1:
				if (!boyfriendMap.exists(newCharacter))
				{
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true, false);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
				}
			case 2:
				if (!gfMap.exists(newCharacter))
				{
					var newGf:Character = new Character(0, 0, newCharacter, false, true);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					newGf.alpha = 0.00001;
				}
		}
	}

	public function changeChar(value:String, type:Int, x:Float = 0, y:Float = 0)
	{
		Debug.logTrace('$value $type');
		switch (type)
		{
			case 0:
				if (dad.data.char != value)
				{
					var lastAlpha:Float = dad.alpha;
					dad.alpha = 0.00001;
					dad = dadMap.get(value);
					dad.setPosition(x, y);
					dad.alpha = lastAlpha;
					iconP2.changeIcon(dad.data.icon);
				}
			case 1:
				if (boyfriend.data.char != value)
				{
					var lastAlpha:Float = boyfriend.alpha;
					boyfriend.alpha = 0.00001;
					boyfriend = boyfriendMap.get(value);
					boyfriend.setPosition(x, y);
					boyfriend.alpha = lastAlpha;
					iconP1.changeIcon(boyfriend.data.icon);
				}
			case 2:
				if (gf.data.char != value)
				{
					var lastAlpha = gf.alpha;
					gf.alpha = 0.00001;
					gf = gfMap.get(value);
					gf.setPosition(x, y);
					gf.alpha = lastAlpha;
				}
		}
		reloadHealthBarColors();
	}

	override function destroy()
	{
		#if FEATURE_HSCRIPT
		if (scripts != null)
		{
			scripts.active = false;
			scripts.destroy();
			scripts = null;
		}
		#end

		Lib.current.stage.removeEventListener(KeyboardEvent.KEY_DOWN, handleInput);
		Lib.current.stage.removeEventListener(KeyboardEvent.KEY_UP, releaseInput);

		#if FEATURE_LUAMODCHART
		if (luaModchart != null)
		{
			luaModchart.die();
			luaModchart = null;
		}

		Constants.noteskinSprite = null;
		Constants.cpuNoteskinSprite = null;

		LuaStorage.ListOfCameras.resize(0);

		LuaStorage.objectProperties.clear();

		LuaStorage.objects.clear();
		#end

		@:privateAccess
		Note._lastValidChecked = null;

		cleanPlayObjects();
		clearSubs();

		super.destroy();
	}

	public inline function updateSettings():Void
	{
		FlxG.stage.window.borderless = FlxG.save.data.borderless;
		PlayStateChangeables.botPlay = FlxG.save.data.botplay;
		PlayStateChangeables.noteCamera = FlxG.save.data.noteCamera;

		for (i in uiGroup)
		{
			i.kill();
			uiGroup.remove(i);
		}

		songName.revive();
		songPosBar.revive();
		uiGroup.add(songPosBar);
		uiGroup.add(songName);
		songName.visible = FlxG.save.data.songPosition;
		songPosBar.visible = FlxG.save.data.songPosition;

		if (songStarted)
		{
			if (FlxG.save.data.songPosition)
			{
				songName.alpha = 1;
				songPosBar.alpha = 1;
			}
		}

		if (PlayStateChangeables.botPlay)
		{
			botPlayState.revive();
			uiGroup.add(botPlayState);
			usedBot = true;
		}

		if (FlxG.save.data.judgementCounter)
		{
			judgementCounter.revive();
			uiGroup.add(judgementCounter);
		}

		if (FlxG.save.data.healthBar)
		{
			reloadHealthBarColors();
			healthBar.revive();
			iconP1.revive();
			iconP2.revive();
			uiGroup.add(healthBar);
			uiGroup.add(iconP1);
			uiGroup.add(iconP2);
		}

		if (PlayStateChangeables.useDownscroll)
			correctY = 135;
		else
			correctY = 698;

		scoreTxt.revive();
		uiGroup.add(scoreTxt);
		updateScoreText();
		for (note in strumLineNotes)
			note.bgLane.alpha = FlxG.save.data.laneTransparency * note.alpha;
	}

	#if FEATURE_HSCRIPT
	function initScripts()
	{
		scripts = new ScriptGroup();
		scripts.onAddScript.push(onAddScript);
		if (scripts == null)
			return;

		var scriptData:Map<String, String> = [];

		var files:Array<String> = [];
		var extensions = ["hx", "hscript", "hsc", "hxs"];
		var rawFiles:Array<String> = CoolUtil.readAssetsDirectoryFromLibrary('assets/shared/data/songs/${SONG.songId}', 'TEXT', 'default', false);

		for (sub in rawFiles)
		{
			for (ext in extensions)
				if (sub.contains(ext)) // Dont want the charts in there lmfao who made this function
					files.push(sub);
		}

		for (_ in CoolUtil.readAssetsDirectoryFromLibrary('assets/shared/data/scripts', 'TEXT', 'default', false))
		{
			for (ext in extensions)
				if (_.contains(ext))
					files.push(_);
		}

		if (FlxG.save.data.gen && files.length > 0)
			Debug.logTrace(files);

		for (file in files)
		{
			var hx:Null<String> = null;

			if (OpenFlAssets.exists(file, TEXT))
				hx = OpenFlAssets.getText(file);

			if (hx != null)
			{
				var scriptName:String = CoolUtil.getFileStringFromPath(file);

				if (!scriptData.exists(scriptName))
					scriptData.set(scriptName, hx);
			}
		}

		for (scriptName => hx in scriptData)
		{
			if (scripts.getScriptByTag(scriptName) == null)
				scripts.addScript(scriptName).executeString(hx);
			else
				scripts.getScriptByTag(scriptName).error("Duplicate Script Error!", '$scriptName: Duplicate Script');
		}
	}

	function onAddScript(script:Script)
	{
		script.set("PlayState", PlayState);
		script.set("game", PlayState.instance);
		script.set("Debug", Debug);
		script.set("health", health);
		script.set("CoolUtil", CoolUtil);
		script.set("SONG", SONG);
		script.set("PlayStateChangeables", PlayStateChangeables);
		script.set("downScroll", PlayStateChangeables.useDownscroll);
		script.set("middleScroll", PlayStateChangeables.middleScroll);

		// FUNCTIONS

		//  CREATION FUNCTIONS
		script.set("create", function()
		{
		});
		script.set("createPost", function()
		{
		});

		//  COUNTDOWN
		script.set("countdown", function()
		{
		});
		script.set("countTick", function(?tick:Int)
		{
		});
		script.set("rate", Conductor.rate);

		//  SONG FUNCTIONS
		script.set("startSong", function()
		{
		}); // ! HAS PAUSE
		script.set("endSong", function()
		{
		}); // ! HAS PAUSE
		script.set("beatHit", function(?beat:Int)
		{
		});
		script.set("stepHit", function(?step:Int)
		{
		});

		script.set("sectionHit", function(?section:Int)
		{
		});

		script.set("goodNoteHit", function(?note:Note)
		{
		});
		script.set("opponentNoteHit", function(?note:Note)
		{
		});
		script.set("noteMiss", function(?note:Note)
		{
		});

		script.set("playerOneTurn", function(?note:Note)
		{
		});
		script.set("playerTwoTurn", function(?note:Note)
		{
		});

		script.set("createTween", function(Object:Dynamic, Values:Dynamic, Duration:Float, ?Options:TweenOptions)
		{
			var tween:FlxTween = tweenManager.tween(Object, Values, Duration, Options);
			tween.manager = tweenManager;
			return tween;
			// actually bullshit. WHY CAN'T YOU DO CREATETWEEN NORMALLY???? (crashes doing it normally)
		});

		script.set("createTimer", function(Time:Float = 1, ?OnComplete:FlxTimer->Void, Loops:Int = 1)
		{
			var timer:FlxTimer = new FlxTimer();
			timer.manager = timerManager;
			return timer.start(Time, OnComplete, Loops);
			// actually bullshit. WHY CAN'T YOU DO CREATETIMER NORMALLY???? (crashes doing it normally)
		});

		script.set("createTweenNum", function(FromValue:Float, ToValue:Float, Duration:Float = 1, ?Options:TweenOptions, ?TweenFunction:Float->Void)
		{
			var tween:FlxTween = tweenManager.num(FromValue, ToValue, Duration, Options, TweenFunction);
			tween.manager = tweenManager;
			return tween;
			// actually bullshit. WHY CAN'T YOU DO CREATETWEENNUM NORMALLY???? (crashes doing it normally)
		});
		// sex
		script.set("notesUpdate", function()
		{
		}); // ! HAS PAUSE

		script.set("ghostTap", function(?direction:Int)
		{
		});

		//  PAUSING / RESUMING
		script.set("pause", function()
		{
		}); // ! HAS PAUSE
		script.set("resume", function()
		{
		}); // ! HAS PAUSE

		//  GAMEOVER
		script.set("gameOver", function()
		{
		}); // ! HAS PAUSE

		script.set("updateScoreText", function()
		{
		});

		script.set("updateAccuracy", function()
		{
		});

		//  MISC
		script.set("update", function(elapsed:Float)
		{
		});
		script.set("updatePost", function(elapsed:Float)
		{
		});

		script.set("cacheChar", function(char:String, type:Int)
		{
			cacheChar(char, type);
		});

		script.set("changeChar", function(char:String, type:Int, x:Float, y:Float)
		{
			changeChar(char, type, x, y);
		});

		// VARIABLES

		script.set("curStep", 0);
		script.set("curSection", 0);
		script.set("curBeat", 0);
		script.set("bpm", Conductor.bpm);

		// OBJECTS
		script.set("camGame", camGame);
		script.set("camHUD", camHUD);
		script.set("overlayCam", camHUD);
		script.set("camFollow", camFollow);
		script.set("camZoom", zoomForTweens);

		// CHARACTERS
		script.set("boyfriend", boyfriend);
		script.set("dad", dad);
		script.set("gf", gf);

		// NOTES
		script.set("notes", notes);
		script.set("strumLineNotes", strumLineNotes);
		script.set("playerStrums", playerStrums);
		script.set("cpuStrums", cpuStrums);

		script.set("unspawnNotes", unspawnNotes);

		// MISC
		script.set("add", function(obj:FlxBasic, ?front:Bool = false)
		{
			if (front)
				getInstance().add(obj);
			else
			{
				if (PlayState.instance.isDead)
					GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.bf), obj);
				else
				{
					var position:Int = PlayState.instance.members.indexOf(PlayState.instance.gfGroup);
					if (PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup) < position)
						position = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
					else if (PlayState.instance.members.indexOf(PlayState.instance.dadGroup) < position)
						position = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);
					PlayState.instance.insert(position, obj);
				}
			}
		});
	}
	#end

	public static inline function getInstance()
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;

	public inline function precacheThing(target:String, type:String)
	{
		switch (type)
		{
			case 'image':
				Paths.image(target);
			case 'sound':
				Paths.sound(target);
			case 'music':
				Paths.music(target);
		}
	}

	public function hideHUD(hidden:Bool)
	{
		healthBar.visible = hidden;
		iconP1.visible = hidden;
		iconP2.visible = hidden;
		scoreTxt.visible = hidden;
		songName.visible = (hidden) ? FlxG.save.data.songPosition : false;
		songPosBar.visible = (hidden) ? FlxG.save.data.songPosition : false;
		judgementCounter.visible = (hidden) ? FlxG.save.data.judgementCounter : false;
	}

	function changeNoteSkins(isPlayer:Bool, texture:String)
	{
		switch (isPlayer)
		{
			case true:
				for (i in 0...playerStrums.length)
					playerStrums.members[i].texture = 'noteskins/' + texture;
				for (note in unspawnNotes)
					if (note.mustPress && (note.noteType == null || note.noteType.toLowerCase() == 'normal'))
						note.texture = 'noteskins/' + texture;
				for (note in notes)
					if (note.mustPress && (note.noteType == null || note.noteType.toLowerCase() == 'normal'))
						note.texture = 'noteskins/' + texture;
			case false:
				for (i in 0...cpuStrums.length)
					cpuStrums.members[i].texture = 'noteskins/' + texture;
				for (note in unspawnNotes)
					if (!note.mustPress && (note.noteType == null || note.noteType.toLowerCase() == 'normal'))
						note.texture = 'noteskins/' + texture;
				for (note in notes)
					if (!note.mustPress && (note.noteType == null || note.noteType.toLowerCase() == 'normal'))
						note.texture = 'noteskins/' + texture;
		}
	}

	private function destroyNote(note:Note)
	{
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	private function cleanPlayObjects()
	{
		while (unspawnNotes.length > 0)
		{
			var note = unspawnNotes[0];
			unspawnNotes.remove(note);

			if (!note.isParent && !note.isSustainNote)
			{
				#if FEATURE_LUAMODCHART
				note.LuaNote = null;
				#end

				note = null;

				return;
			}

			if (note.isSustainNote)
			{
				for (susDef in note.parent.children)
				{
					#if FEATURE_LUAMODCHART
					susDef.LuaNote = null;
					#end
					susDef = null;
				}
				#if FEATURE_LUAMODCHART
				note.parent.LuaNote = null;
				#end
				note.parent = null;

				return;
			}
		}

		for (i in uiGroup)
		{
			i.kill();
			uiGroup.remove(i);
		}
		uiGroup.clear();

		for (i in introGroup)
		{
			i.destroy();
			introGroup.remove(i);
		}
		for (i in numGroup)
		{
			i.destroy();
			numGroup.remove(i);
		}
		for (i in ratingGroup)
		{
			i.destroy();
			ratingGroup.remove(i);
		}

		hitSound.autoDestroy = true;
		hitSound.stop();

		introGroup.clear();
		numGroup.clear();
		ratingGroup.clear();
		boyfriendGroup.clear();
		dadGroup.clear();
		if (gfGroup != null)
			gfGroup.clear();

		FlxDestroyUtil.destroy(boyfriend);
		FlxDestroyUtil.destroy(dad);
		FlxDestroyUtil.destroy(gf);

		Stage.destroy();
		Stage = null;
		instance = null;
	}

	public function startAndEnd()
	{
		if (endingSong)
			endSong();
		else
			startCountdown();
	}

	function playCutscene(name:String, ?atend:Bool)
	{
		#if VIDEOS
		inCutscene = true;
		var diff:String = CoolUtil.getSuffixFromDiff(CoolUtil.difficulties[storyDifficulty]);
		cutscene = new VideoHandler();
		OpenFlAssets.loadBytes(Paths.video(name)).onComplete(function(bytes:openfl.utils.ByteArray):Void
		{
			if (cutscene.load(bytes))
			{
				FlxTimer.wait(0.001, function():Void
				{
					cutscene.play();
				});
				FlxG.addChildBelowMouse(cutscene);
			}
			else
			{
				Debug.logWarn("Video File Not Found. Check Your Video Path And Extension.");
				inCutscene = false;
				if (atend == true)
				{
					if (storyPlaylist.length <= 0)
						MusicBeatState.switchState(new StoryMenuState());
					else
					{
						SONG = Song.loadFromJson(storyPlaylist[0].toLowerCase(), diff);
						MusicBeatState.switchState(new PlayState());
					}
				}
				else
				{
					createTimer(0.5, function(timer)
					{
						startCountdown();
					});
				}
			}
		});
		inst.stop();
		cutscene.onEndReached.add(function()
		{
			inCutscene = false;
			if (atend == true)
			{
				if (storyPlaylist.length <= 0)
					MusicBeatState.switchState(new StoryMenuState());
				else
				{
					SONG = Song.loadFromJson(storyPlaylist[0].toLowerCase(), diff);
					MusicBeatState.switchState(new PlayState());
				}
			}
			else
			{
				createTimer(0.5, function(timer)
				{
					startCountdown();
				});
			}

			cutscene.dispose();
			FlxG.removeChild(cutscene);
		});
		#else
		FlxG.log.warn("Platform Not Supported.");
		#end
	}

	private function updateCamFollow()
		camFollow.set(stageFollow.x, stageFollow.y);

	private function snapCamFollowToPos(x:Float, y:Float)
	{
		camFollow.set(x, y);
		camFollowPos.setPosition(x, y);
		stageFollow.set(x, y);
	}

	private function noteCamera(note:Note)
	{
		if (!PlayStateChangeables.noteCamera)
			return;
		var camNoteExtend:Float = 20;

		camNoteX = 0;
		camNoteY = 0;

		if (!note.isSustainNote)
		{
			if (Stage.staticCam)
				updateCamFollow();

			switch (note.noteData)
			{
				case 0:
					camNoteX -= camNoteExtend;
				case 1:
					camNoteY += camNoteExtend;
				case 2:
					camNoteY -= camNoteExtend;
				case 3:
					camNoteX += camNoteExtend;
			}

			if (camNoteX > camNoteExtend)
				camNoteX = camNoteExtend;

			if (camNoteX < -camNoteExtend)
				camNoteX = -camNoteExtend;

			if (camNoteY > camNoteExtend)
				camNoteY = camNoteExtend;

			if (camNoteY < -camNoteExtend)
				camNoteY = -camNoteExtend;

			camFollow.x += camNoteX;
			camFollow.y += camNoteY;
		}
	}

	private function initEvents()
	{
		events = [];
		if (SONG.eventObjects == null)
			SONG.eventObjects = [
				{
					name: "Init BPM",
					beat: 0,
					args: [SONG.bpm, 1],
					type: "BPM Change"
				}
			];

		for (i in SONG.eventObjects)
		{
			events.push({
				name: i.name,
				beat: i.beat,
				args: i.args,
				type: i.type
			});

			if (i.type == "Change Character")
			{
				cacheChar(Std.string(i.args[0]), Std.int(i.args[1]));
				Debug.logInfo("Caching Character From Event");
			}
		}
		// Debug.logTrace(events);
	}

	private function initGameplaySettings()
	{
		// Initialize PlayStateChangeables Options For Later.
		PlayStateChangeables.useDownscroll = FlxG.save.data.downscroll;
		PlayStateChangeables.middleScroll = FlxG.save.data.middleScroll;
		if (FlxG.save.data.scrollSpeed == 1)
			scrollSpeed = SONG.speed;
		else
			scrollSpeed = FlxG.save.data.scrollSpeed;
		PlayStateChangeables.zoom = FlxG.save.data.zoom;
		PlayStateChangeables.botPlay = FlxG.save.data.botplay;
		PlayStateChangeables.noteCamera = FlxG.save.data.noteCamera;

		PlayStateChangeables.modchart = !isStoryMode ? FlxG.save.data.modcharts : true;
		// PlayStateChangeables.opponentMode = !isStoryMode ? FlxG.save.data.opponent : false;
		PlayStateChangeables.mirrorMode = !isStoryMode ? FlxG.save.data.mirror : false;
		PlayStateChangeables.holds = !isStoryMode ? FlxG.save.data.sustains : true;
		PlayStateChangeables.healthDrain = !isStoryMode ? FlxG.save.data.hdrain : false;
		PlayStateChangeables.healthGain = !isStoryMode ? FlxG.save.data.hgain : 1.0;
		PlayStateChangeables.healthLoss = !isStoryMode ? FlxG.save.data.hloss : 1.0;
		PlayStateChangeables.practiceMode = !isStoryMode ? FlxG.save.data.practice : false;
		PlayStateChangeables.skillIssue = !isStoryMode ? FlxG.save.data.noMisses : false;
	}

	private function initStyle()
	{
		STYLE = Style.loadJSONFile(SONG.style.toLowerCase());

		if (STYLE == null || SONG.style == "")
		{
			STYLE = Style.loadJSONFile('default');
			Debug.logTrace("No Style Found. Loading Default.");
		}
		STYLE.style = SONG.style;
		styleName = STYLE.style.toLowerCase();
		UIComponent.style = STYLE;
		RatingWindow.createRatings(STYLE.style);
	}

	private function initCharacters()
	{
		dadMap = new StringMap();
		boyfriendMap = new StringMap();
		gfMap = new StringMap();
		// defaults if no gf was found in chart
		var gfCheck:String = 'gf';

		if (SONG.gfVersion == null)
		{
			switch (storyWeek)
			{
				case 4:
					gfCheck = 'gf-car';
				case 5:
					gfCheck = 'gf-christmas';
				case 6:
					gfCheck = 'gf-pixel';
				case 7:
					gfCheck = 'gfTank';
			}
		}
		else
		{
			gfCheck = SONG.gfVersion;
		}

		gfGroup = new FlxTypedGroup<Character>();
		boyfriendGroup = new FlxTypedGroup<Character>();
		dadGroup = new FlxTypedGroup<Character>();

		// Load Characters.
		if (Stage.hasGF)
		{
			gf = new Character(400, 130, gfCheck, false, true);

			if (gf.frames == null)
			{
				#if debug
				FlxG.log.warn(["Couldn't load gf: " + gfCheck + ". Loading default gf"]);
				#end
				gf = new Character(400, 130, 'gf', false, true);
			}
		}
		else
			gf = null;

		boyfriend = new Character(770, 450, SONG.player1, true, false);

		if (boyfriend.frames == null)
		{
			#if debug
			FlxG.log.warn(["Couldn't load boyfriend: " + SONG.player1 + ". Loading default boyfriend"]);
			#end
			boyfriend = new Character(770, 450, 'bf', true, false);
		}

		dad = new Character(100, 100, SONG.player2, false, false);

		if (dad.frames == null)
		{
			#if debug
			FlxG.log.warn(["Couldn't load opponent: " + SONG.player2 + ". Loading default opponent"]);
			#end
			dad = new Character(100, 100, 'dad', false, false);
		}
		dadMap.set(dad.data.char, dad);
		boyfriendMap.set(boyfriend.data.char, boyfriend);
		if (Stage.hasGF)
			gfMap.set(gf.data.char, gf);
	}

	private function executeEventCheck()
	{
		while (events.length > 0)
		{
			final eventTime = events[0].beat; // decimal beat
			if (TimingStruct.getBeatFromTime(Conductor.elapsedPosition) < eventTime)
				return;
			executeEvent(events[0]);
			events.shift();
		}
	}

	public function executeEvent(event:Event)
	{
		Debug.logTrace("Executing Event : " + event.name);
		switch (event.type)
		{
			case "Scroll Speed Change":
				final newScroll = Std.parseFloat(event.args[0]);
				if (newScroll != 0)
				{
					changeScrollSpeed(newScroll, Std.parseFloat(event.args[1]), FlxEase.linear);
					Debug.logTrace("SCROLL SPEED CHANGE to " + newScroll + " WITH A TIME OF " + event.args[1]);
					speedChanged = true;
				}
			case "Play Animation":
				var char:Character = dad;
				switch (Std.string(event.args[0]).toLowerCase())
				{
					case 'dad' | 'opponent':
						char = dad;
					case 'bf' | 'boyfriend' | 'player':
						char = boyfriend;
					case 'gf' | 'girlfriend' | 'speaker':
						if (gf != null) char = gf;
					default:
						char = dad;
				}

				if (char != null)
					char.playAnim(Std.string(event.args[1]), true);
			case "Change Camera Zoom":
				switch (Std.string(event.args[0]).toLowerCase())
				{
					case 'hud' | 'camhud':
						zoomForHUDTweens += Std.parseFloat(event.args[1]);
					case 'game' | 'main' | 'camgame':
						zoomForTweens += Std.parseFloat(event.args[1]);
					default:
						zoomForTweens += Std.parseFloat(event.args[1]);
				}
			case "Change Character":
				final char = Std.string(event.args[0]);
				final type = event.args[1];
				switch (type)
				{
					case 0:
						changeChar(char, type, dad.x, dad.y);
					// dad
					case 1:
						changeChar(char, type, boyfriend.x, boyfriend.y);
					// bf
					case 2:
						changeChar(char, type, gf.x, gf.y);
				}
			case "Camera Focus":
				final charToFocus = Std.string(event.args[0]);
				var char:Character = boyfriend;
				switch (charToFocus)
				{
					case 'bf' | 'boyfriend' | 'player':
						char = boyfriend;
					case 'dad' | 'opponent':
						char = dad;
					case 'gf' | 'girlfriend' | 'speaker':
						char = gf;
				}
				changeCameraFocus(char);
		}
	}

	/**
	 * Handy little function to pause or play music
	 * @param play 
	 */
	private inline function music(play:Bool = false)
	{
		if (play)
		{
			inst.play();
			if (!SONG.splitVoiceTracks)
			{
				if (vocals != null)
					vocals.play();
			}
			else
			{
				if (vocalsPlayer != null)
					vocalsPlayer.play();
				if (vocalsEnemy != null)
					vocalsEnemy.play();
			}
		}
		else
		{
			inst.pause();
			if (!SONG.splitVoiceTracks)
			{
				if (vocals != null)
					vocals.pause();
			}
			else
			{
				if (vocalsPlayer != null)
					vocalsPlayer.pause();
				if (vocalsEnemy != null)
					vocalsEnemy.pause();
			}
		}
	}

	private function setConductorTime()
	{
		if (!startedCountdown)
			return;

		if (endingSong)
			return;

		Conductor.elapsedPosition += FlxG.elapsed * 1000;

		if (Conductor.elapsedPosition > 0 && startingSong)
			startSong();

		if (songStarted && !endingSong && (inst.length / Conductor.rate) - Conductor.elapsedPosition <= 0)
			endSong();
		Conductor.songPosition = Conductor.elapsedPosition * Conductor.rate;
		final curTime:Float = Math.max(0, Conductor.songPosition) / Conductor.rate;
		songPositionBar = CoolUtil.fpsLerp(songPositionBar, (curTime / songLength), 0.15, 60 * Conductor.rate);
		final songCalc:Float = (songLength - curTime);
		var secondsTotal:Int = Math.floor(songCalc * 0.001);
		if (secondsTotal < 0)
			secondsTotal = 0;
		songName.text = SONG.songName + ' (' + FlxStringUtil.formatTime(secondsTotal, false) + ')';
		checkMusicSync();
	}

	private function set_health(v:Float)
	{
		if (v <= 0)
			v = 0;
		else if (v >= 2)
			v = 2;
		health = v;
		return v;
	}

	public function reloadHealthBarColors()
	{
		if (FlxG.save.data.colour)
			healthBar.setColors(dad.data.barColor, boyfriend.data.barColor);
		else
			healthBar.setColors(0xFFFF0000, 0xFF66FF33);
	}
}
