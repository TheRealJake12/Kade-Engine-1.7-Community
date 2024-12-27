package kec.substates;

#if FEATURE_FILESYSTEM
import sys.io.File;
import Sys;
import sys.FileSystem;
#end
import kec.objects.menu.HitGraph;
import kec.objects.OFLSprite;
import kec.objects.game.note.Note;
import kec.backend.PlayStateChangeables;
import kec.backend.Ratings;
import kec.util.HelperFunctions;
import kec.util.Highscore;
import kec.backend.PlayerSettings;
import kec.backend.Stats;

class ResultsScreen extends MusicBeatSubstate
{
	public var background:FlxSprite;
	public var text:FlxText;

	public var graph:HitGraph;
	public var graphSprite:OFLSprite;

	public var comboText:FlxText;
	public var contText:FlxText;
	public var settingsText:FlxText;

	public var songText:FlxText;
	public var music:FlxSound;

	public var modifiers:String;

	public var activeMods:FlxText;

	public var superMegaConditionShit:Bool;

	public static var instance:ResultsScreen = null;

	private function refresh()
	{
	}

	public function new()
	{
		super();
		instance = this;

		openCallback = refresh;

		background = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		background.scrollFactor.set();

		music = new FlxSound().loadEmbedded(Paths.music('breakfast'), true, true);

		if (!PlayState.isStoryMode)
		{
			modifiers = 'Active Modifiers:\n${(PlayStateChangeables.mirrorMode ? '- Mirror Mode\n' : '')}${(PlayStateChangeables.practiceMode ? '- Practice Mode\n' : '')}${(PlayStateChangeables.skillIssue ? '- No Misses mode\n' : '')}${(!PlayStateChangeables.holds ? '- Hold Notes OFF\n' : '')}${(!PlayStateChangeables.modchart #if FEATURE_LUAMODCHART && FileSystem.exists(Paths.lua('songs/${PlayState.SONG.songId}/modchart')) #end ? '- Song modchart OFF\n' : '')}${(PlayStateChangeables.healthDrain ? '- Health Drain ON\n' : '')}${(HelperFunctions.truncateFloat(PlayStateChangeables.healthGain,2) != 1 ? '- HP Gain ${HelperFunctions.truncateFloat(PlayStateChangeables.healthGain, 2)}x\n': '')}${(HelperFunctions.truncateFloat(PlayStateChangeables.healthLoss,2) != 1 ? '- HP Loss ${HelperFunctions.truncateFloat(PlayStateChangeables.healthLoss, 2)}x\n':'')}';
			if (modifiers == 'Active Modifiers:\n')
				modifiers = 'Active Modifiers: None';
			activeMods = new FlxText(FlxG.width - 500, FlxG.height - 450, FlxG.width, modifiers);
			activeMods.size = 24;
			activeMods.font = Paths.font("vcr.ttf");
			activeMods.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2, 1);
			activeMods.scrollFactor.set();
		}

		text = new FlxText(20, -55, 0, "Song Cleared!");
		text.size = 34;
		text.font = Paths.font("vcr.ttf");
		text.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2, 1);
		text.color = FlxColor.WHITE;
		text.scrollFactor.set();

		if (PlayState.isStoryMode)
		{
			text.text = 'Week Cleared on ${PlayState.instance.storyDifficultyText.toUpperCase()}!';
		}
		comboText = new FlxText(20, -75, 0, '');
		comboText.font = Paths.font("vcr.ttf");

		if (!PlayState.isStoryMode)
		{
			songText = new FlxText(20, -65, FlxG.width,
				'Played on ${PlayState.SONG.songName} - ${CoolUtil.difficultyFromInt(PlayState.storyDifficulty).toUpperCase()}');
			songText.size = 34;
			songText.font = Paths.font("vcr.ttf");
			songText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2, 1);
			songText.color = FlxColor.WHITE;
			songText.scrollFactor.set();
		}

		comboText.size = 28;
		comboText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2, 1);
		comboText.color = FlxColor.WHITE;
		comboText.scrollFactor.set();

		contText = new FlxText(FlxG.width - 525, FlxG.height + 50, 0, 'Click or Press ENTER to continue.');
		contText.font = Paths.font("vcr.ttf");
		contText.size = 24;
		contText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2, 1);
		contText.color = FlxColor.WHITE;
		contText.scrollFactor.set();

		if (FlxG.save.data.inputShow)
			graph = new HitGraph(FlxG.width - 600, 45, 525, 180);

		settingsText = new FlxText(20, FlxG.height + 50, 0, '');
		settingsText.font = Paths.font("vcr.ttf");
		settingsText.size = 16;
		settingsText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2, 1);
		settingsText.color = FlxColor.WHITE;
		settingsText.scrollFactor.set();
	}

	var mean:Float = 0;

	override function create()
	{
		add(background);
		music.volume = 0;
		music.play(false, FlxG.random.int(0, Std.int(music.length / 2)));
		FlxG.sound.list.add(music);

		add(activeMods);

		background.alpha = 0;

		add(text);

		if (!PlayState.isStoryMode)
			add(songText);

		var score:Int = Stats.songScore;
		var acc:Float = Stats.accuracy;

		if (PlayState.isStoryMode)
		{
			acc = Stats.campaignAccuracy / PlayState.songsPlayed;
			score = Stats.campaignScore;
		}

		var marvs = PlayState.isStoryMode ? Stats.campaignMarvs : Stats.marvs;
		var sicks = PlayState.isStoryMode ? Stats.campaignSicks : Stats.sicks;
		var goods = PlayState.isStoryMode ? Stats.campaignGoods : Stats.goods;
		var bads = PlayState.isStoryMode ? Stats.campaignBads : Stats.bads;
		var shits = PlayState.isStoryMode ? Stats.campaignShits : Stats.shits;

		comboText.text = 'Judgements:\nMarvs - ${marvs}\nSicks - ${sicks}\nGoods - ${goods}\nBads - ${bads}\n\nCombo Breaks: ${(PlayState.isStoryMode ? Stats.campaignMisses : Stats.misses)}\nHighest Combo: ${PlayState.highestCombo + 1}\nScore: $score\n${(PlayState.isStoryMode ? 'Average Accuracy' : 'Accuracy')}: ${HelperFunctions.truncateFloat(acc, 2)}% ( ${(FlxG.save.data.accuracyMod == 0 ? 'Accurate' : 'Complex')} )\n\n${Ratings.GenerateComboRank(Stats.accuracy)} ${Ratings.GenerateLetterRank(Stats.accuracy)}\nRate: ${HelperFunctions.truncateFloat(Conductor.rate, 2)}x\n\n\nF1 - Replay song';

		add(comboText);

		add(contText);

		if (FlxG.save.data.inputShow)
		{
			graph.update();

			graphSprite = new OFLSprite(graph.xPos, graph.yPos, Std.int(graph._width), Std.int(graph._rectHeight), graph);
			FlxSpriteUtil.drawRect(graphSprite, 0, 0, graphSprite.width, graphSprite.height, FlxColor.TRANSPARENT, {thickness: 1.5, color: FlxColor.WHITE});

			graphSprite.scrollFactor.set();
			graphSprite.alpha = 0;

			add(graphSprite);
		}

		var sicks = HelperFunctions.truncateFloat(Stats.sicks / Stats.goods, 1);
		var goods = HelperFunctions.truncateFloat(Stats.goods / Stats.bads, 1);

		if (sicks == Math.POSITIVE_INFINITY)
			sicks = 0;
		if (goods == Math.POSITIVE_INFINITY)
			goods = 0;

		if (sicks == Math.POSITIVE_INFINITY || sicks == Math.NaN)
			sicks = 0;
		if (goods == Math.POSITIVE_INFINITY || goods == Math.NaN)
			goods = 0;

		var legitTimings:Bool = true;
		for (rating in Ratings.timingWindows)
		{
			if (rating.timingWindow != rating.defaultTimingWindow)
			{
				legitTimings = false;
				break;
			}
		}

		superMegaConditionShit = legitTimings
			&& !PlayState.usedBot
			&& !FlxG.save.data.practice
			&& PlayStateChangeables.holds
			&& !PlayState.wentToChartEditor
			&& HelperFunctions.truncateFloat(PlayStateChangeables.healthGain, 2) <= 1
			&& HelperFunctions.truncateFloat(PlayStateChangeables.healthLoss, 2) >= 1;

		if (superMegaConditionShit)
		{
			Highscore.saveScore(PlayState.SONG.songId, Math.round(Stats.songScore), PlayState.storyDifficulty, Conductor.rate);
			Highscore.saveCombo(PlayState.SONG.songId, Ratings.GenerateLetterRank(Stats.accuracy), PlayState.storyDifficulty, Conductor.rate);
			Highscore.saveAcc(PlayState.SONG.songId, HelperFunctions.truncateFloat(Stats.accuracy, 2), PlayState.storyDifficulty, Conductor.rate);
			Highscore.saveLetter(PlayState.SONG.songId, Ratings.GenerateLetterRank(Stats.accuracy), PlayState.storyDifficulty, Conductor.rate);
		}

		// Debug.logTrace('$legitTimings ${!PlayState.usedBot} ${!FlxG.save.data.practice} ${PlayStateChangeables.holds} ${!PlayState.wentToChartEditor} ${HelperFunctions.truncateFloat(PlayStateChangeables.healthGain, 2) <= 1} ${HelperFunctions.truncateFloat(PlayStateChangeables.healthLoss, 2) >= 1}');

		mean = HelperFunctions.truncateFloat(mean / PlayState.instance.playerNotes, 2);
		var acceptShit:String = (superMegaConditionShit ? '| Accepted' : '| Rejected');

		if (!PlayStateChangeables.modchart #if FEATURE_LUAMODCHART
			&& FileSystem.exists(Paths.lua('songs/${PlayState.SONG.songId}/modchart')) #end)
			acceptShit = '| Rejected';

		#if debug
		acceptShit = '| Debug';
		#end

		if (PlayState.isStoryMode)
			acceptShit = '';

		settingsText.text = 'Mean: ${mean}ms (';
		var reverseWins = Ratings.timingWindows.copy();
		reverseWins.reverse();
		for (i in 0...reverseWins.length)
		{
			var timing = reverseWins[i];
			settingsText.text += '${timing.name.toUpperCase()}:${timing.timingWindow}ms';
			if (i != reverseWins.length - 1)
				settingsText.text += ',';
		}
		settingsText.text += ') $acceptShit';

		add(settingsText);

		createTween(background, {alpha: 0.5}, 0.5);
		if (!PlayState.isStoryMode)
		{
			createTween(songText, {y: 65}, 0.5, {ease: FlxEase.expoInOut});
			createTween(activeMods, {y: FlxG.height - 400}, 0.5, {ease: FlxEase.expoInOut});
		}
		createTween(text, {y: 20}, 0.5, {ease: FlxEase.expoInOut});
		createTween(comboText, {y: 145}, 0.5, {ease: FlxEase.expoInOut});
		createTween(contText, {y: FlxG.height - 45}, 0.5, {ease: FlxEase.expoInOut});
		createTween(settingsText, {y: FlxG.height - 35}, 0.5, {ease: FlxEase.expoInOut});
		if (FlxG.save.data.inputShow)
			createTween(graphSprite, {alpha: 1}, 1, {ease: FlxEase.expoInOut});

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		super.create();
	}

	public function registerHit(note:Note, isMiss:Bool = false)
	{
		if (FlxG.save.data.inputShow)
		{
			var noteRating = note.rating;

			var noteDiff = note.strumTime - (Conductor.songPosition / Conductor.rate);

			if (isMiss)
				noteDiff = Ratings.timingWindows[0].timingWindow;

			if (PlayStateChangeables.botPlay)
				noteDiff = 0;
			// judgement

			var strumTime = note.strumTime;

			if (noteDiff != Ratings.timingWindows[0].timingWindow)
				mean += noteDiff;

			graph.addToHistory(noteDiff, noteRating, strumTime);
		}
	}

	var frames = 0;

	override function update(elapsed:Float)
	{
		#if !cpp
		if (music != null)
			if (music.volume < 0.5)
				Math.min(music.volume + 0.5 * elapsed, 0.5);
		#end

		if ((controls.ACCEPT && !FlxG.keys.pressed.ALT) || FlxG.mouse.pressed)
		{
			if (music != null)
				music.fadeOut(0.3);

			Constants.freakyPlaying = false;

			if (PlayState.isStoryMode)
			{
				MusicBeatState.switchState(new StoryMenuState());
				Stats.resetCampaignStats();
			}
			else
			{
				Conductor.bpm = 102;
				MusicBeatState.switchState(new FreeplayState());
			}
		}

		if (FlxG.keys.justPressed.F1)
		{
			if (music != null)
				music.fadeOut(0.3);

			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = PlayState.storyDifficulty;
			MusicBeatState.switchState(new PlayState());
		}

		super.update(elapsed);
	}

	override function destroy()
	{
		if (graph != null && graphSprite != null)
		{
			graph.destroy();
			graph = null;
			graphSprite.destroy();
		}
		instance = null;
		super.destroy();
	}
}
