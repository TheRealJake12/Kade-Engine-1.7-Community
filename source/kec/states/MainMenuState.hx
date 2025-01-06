package kec.states;

import flixel.addons.display.FlxBackdrop;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import kec.backend.Controls.KeyboardScheme;
import kec.backend.chart.Song;
import lime.app.Application;
#if FEATURE_DISCORD
import kec.backend.Discord;
#end
#if FEATURE_MODCORE
import polymod.Polymod;
#end

class MainMenuState extends MusicBeatState
{
	public var curSelected:Int = 0;

	private final optionShit:Array<String> = ['story mode', 'freeplay', 'donate', 'discord', 'options'];

	private final colorArray:Array<FlxColor> = [
		FlxColor.fromRGB(148, 0, 211),
		FlxColor.fromRGB(75, 0, 130),
		FlxColor.fromRGB(0, 0, 200),
		FlxColor.fromRGB(0, 255, 0),
		FlxColor.fromRGB(200, 160, 0),
		FlxColor.fromRGB(200, 127, 0),
		FlxColor.fromRGB(160, 0, 0)
	];

	var magenta:FlxBackdrop;
	var bg:FlxBackdrop;
	var logo:FlxSprite;
	var menuItems:FlxTypedGroup<FlxSprite>;

	var myBalls:FlxText;

	override function create()
	{
		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		Discord.changePresence("In the Menus", null);
		#end

		#if FEATURE_MODCORE
		if (FlxG.save.data.loadMods)
			Polymod.loadOnlyMods(FlxG.save.data.enabledMods);
		#end

		FlxG.mouse.visible = true;
		#if desktop
		Application.current.window.title = '${Constants.kecVer} : In the Menus';
		#end

		if (!Constants.freakyPlaying)
		{
			FlxG.sound.playMusic(Paths.music("freakyMenu"));
			Constants.freakyPlaying = true;
			Conductor.bpm = 102;
		}

		persistentUpdate = persistentDraw = true;

		bg = new FlxBackdrop(Paths.image('menuDesat'), X, 0, 0);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		bg.velocity.set(240, 0);
		bg.moves = true;
		add(bg);

		magenta = new FlxBackdrop(Paths.image('menuDesat'), X, 0, 0);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.moves = true;
		magenta.velocity.set(240, 0);
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		for (num => i in optionShit)
		{
			var menuItem:FlxSprite = new FlxSprite(0, 0);
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + i);
			menuItem.animation.addByPrefix('idle', i + " basic", 24);
			menuItem.animation.addByPrefix('selected', i + " white", 24);
			menuItem.animation.play('idle');
			menuItem.ID = num;
			menuItems.add(menuItem);
			menuItem.antialiasing = FlxG.save.data.antialiasing;

			switch (num)
			{
				case 0:
					menuItem.setPosition(130, 50);
				case 1:
					menuItem.setPosition(300, 185);
				case 2:
					menuItem.setPosition(190, 320);
				case 3:
					menuItem.setPosition(420, 440);
				case 4:
					menuItem.setPosition(600, 570);
			}
		}

		logo = new FlxSprite(900, 0);
		logo.frames = Paths.getSparrowAtlas("KECLogoOrange");
		logo.scale.set(0.7, 0.7);
		logo.animation.addByPrefix("bump", "logo bumpin", 24);
		logo.updateHitbox();

		var versionShit:FlxText = new FlxText(5, FlxG.height - 18, 0, '${Constants.keVer} / ${Constants.kecVer}', 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		add(versionShit);

		myBalls = new FlxText(3, FlxG.height - 35, 0, Constants.textArray[FlxG.random.int(0, Constants.textArray.length - 1)], 12);
		myBalls.scrollFactor.set();
		myBalls.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		add(myBalls);
		add(logo);

		changeItem();
		tweenColorShit();

		super.create();
	}

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);

		if (selectedSomethin)
			return;
		if (FlxG.keys.justPressed.UP || controls.UP_P)
			changeItem(-1);

		if (FlxG.keys.justPressed.DOWN || controls.DOWN_P)
			changeItem(1);

		if (controls.BACK || FlxG.mouse.justPressedRight)
		{
			selectedSomethin = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new TitleState());
		}

		if (FlxG.keys.justPressed.F7)
		{
			PlayState.storyDifficulty = 1;
			PlayState.SONG = Song.loadFromJson('salvation', '');
			PlayState.isStoryMode = false;
			MusicBeatState.switchState(new PlayState());
		}

		#if FEATURE_MODCORE
		if (FlxG.keys.justPressed.M)
			MusicBeatState.switchState(new ModMenuState());
		#end

		final shiftMult:Int = 1;

		#if !mobile
		if (FlxG.mouse.overlaps(menuItems, FlxG.camera))
		{
			menuItems.forEach(function(daSprite:FlxSprite)
			{
				if (FlxG.mouse.overlaps(daSprite) && curSelected != daSprite.ID)
				{
					curSelected = daSprite.ID;
					changeItem();
				}
			});
		}

		if (FlxG.mouse.wheel != 0)
			changeItem(-shiftMult * FlxG.mouse.wheel);
		#end

		if (FlxG.keys.justPressed.SEVEN)
			MusicBeatState.switchState(new SelectEditorsState());

		if (FlxG.mouse.overlaps(menuItems, FlxG.camera) && FlxG.mouse.justPressed || controls.ACCEPT)
		{
			if (optionShit[curSelected] == 'donate')
				fancyOpenURL("https://ninja-muffin24.itch.io/funkin");
			else if (optionShit[curSelected] == 'discord')
				fancyOpenURL("https://discord.gg/TKCzG5rVGf");
			else
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('confirmMenu'));

				if (FlxG.save.data.flashing)
					FlxFlicker.flicker(magenta, 1.1, 0.15, false);

				menuItems.forEach(function(spr:FlxSprite)
				{
					if (curSelected == spr.ID)
					{
						if (FlxG.save.data.flashing)
							FlxFlicker.flicker(spr, 0.75, 0.06, false, false, function(flick:FlxFlicker)
							{
								goToState();
							});
						else
							FlxTimer.wait(0.75, function()
							{
								goToState();
							});
						return;
					}

					createTween(spr, {alpha: 0}, 1.3, {
						ease: FlxEase.quadOut,
						onComplete: function(twn:FlxTween)
						{
							spr.kill();
						}
					});
				});
			}
		}
	}

	function goToState()
	{
		var daChoice:String = optionShit[curSelected];
		switch (daChoice)
		{
			case 'story mode':
				MusicBeatState.switchState(new StoryMenuState());
			case 'freeplay':
				MusicBeatState.switchState(new FreeplayState());
			case 'options':
				FlxTransitionableState.skipNextTransOut = true;
				MusicBeatState.switchState(new OptionsDirect());
		}
	}

	function changeItem(huh:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));

		curSelected += huh;

		if (curSelected >= menuItems.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = menuItems.length - 1;

		menuItems.forEach(function(spr:FlxSprite)
		{
			spr.animation.play('idle');
			spr.updateHitbox();

			if (spr.ID == curSelected)
			{
				spr.animation.play('selected');
				spr.centerOffsets();
			}
		});
	}

	override function beatHit(b:Int)
	{
		logo.animation.play('bump', true);
		super.beatHit(b);
	}

	function tweenColorShit()
	{
		var beforeInt = FlxG.random.int(0, 6);
		var randomInt = FlxG.random.int(0, 6);

		FlxTween.color(bg, 4, bg.color, colorArray[beforeInt], {
			onComplete: function(twn)
			{
				if (beforeInt != randomInt)
					beforeInt = randomInt;

				tweenColorShit();
			}
		});
		// thanks bolo lmao
	}
}
