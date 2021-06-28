//
//  MenuScene.m
//  Pizarro
//
//  Created by Sveinbjorn Thordarson on 1/20/11.
//  Copyright 2011 Corrino Software. All rights reserved.
//

#import "MainMenuScene.h"
#import "Constants.h"
#import "PizarroGameScene.h"
#import "Common.c"
#import "SimpleAudioEngine.h"
#import "Instrument.h"
#import "GParams.h"
#import "CCNode+Cleanup.h"


#define kAnimationInterval                  1.0f / 2.0f
#define kBackgroundMovementInterval         1.0f / 20.0f

#pragma mark -

@implementation MainMenuScene
@synthesize pausedScene, paused;

- (void)dealloc {
	CCLOG(@"Deallocing main menu scene");
    
	[letters release];
	[piano release];
	[self removeAllChildrenWithCleanup:YES];
	[super dealloc];
}

+ (id)scene {
	CCScene *scene = [CCScene node];
    
	MainMenuScene *layer = [[[MainMenuScene alloc] initWithPause:NO] autorelease];
    
	[scene addChild:layer];
    
	// return the scene
	return scene;
}

+ (id)scenePausedForScene:(CCScene *)gameScene;
{
	CCScene *scene = [CCScene node];
    
	MainMenuScene *layer = [[[MainMenuScene alloc] initWithPause:YES] autorelease];
	layer.pausedScene = gameScene;
    
	[scene addChild:layer];
    
	return scene;
}

- (id)initWithPause:(BOOL)p {
	if ((self = [super init])) {
		CCLOG(@"Creating main menu scene");
        
		self.isTouchEnabled = YES;
		self.paused = p;
        
		// Create and set up all sprite objects and menus
		[self createMainMenu];
		[self createBackground];
		[self createLetterAndLogo];
        
		// Tickers
//		[self schedule:@selector(tick:) interval:kAnimationInterval];
//		[self schedule:@selector(bgMovetick:) interval:kBackgroundMovementInterval];
        
		// Background music
		if (!paused)
			[[SimpleAudioEngine sharedEngine] playBackgroundMusic:kMainMenuMusicFile];
        
		// Create instrument
		piano = [[Instrument alloc] initWithName:@"piano" numberOfNotes:7 tempo:0.07];
		piano.delegate = self;
		piano.selector = @selector(notePressed:);
        
		if (!paused)
			[self shiftIn];
		else
			[self showPausedMenu];
        
		//
		//[piano playSequence: @"1,2, ,3,4, ,5,6,7"];
        
		//[piano playSequence: @"7, , ,7, ,6, ,5, ,4, , , , ,3, , ,2, , ,1, , ,2, ,1, ,2, ,1"];
        
		//[piano playSequence: @"7, ,6,5, ,4,3, ,2,1, ,2,1, ,2,1, ,3,4"];
	}
	return self;
}

#pragma mark -
#pragma mark Set up menu scene

- (void)createMainMenu {
	// Menu at bottom
	[CCMenuItemFont setFontName:kMainMenuFont];
	[CCMenuItemFont setFontSize:[GParams mainMenuFontSize]];
    
	NSString *playStr = paused ? @"New" : @"Play";
    
	CCMenuItemFont *menuItem1 = [CCMenuItemFont itemFromString:playStr target:self selector:@selector(onPlay:)];
	CCMenuItemFont *menuItem2 = [CCMenuItemFont itemFromString:@"Settings" target:self selector:@selector(onSettings:)];
	CCMenuItemFont *menuItem3 = [CCMenuItemFont itemFromString:@"Credits" target:self selector:@selector(onCredits:)];
	menuItem1.color = kBlackColor;
	menuItem2.color = kBlackColor;
	menuItem3.color = kBlackColor;
    
	menu = [CCMenu menuWithItems:menuItem1, menuItem2, menuItem3, nil];
	[menu alignItemsHorizontallyWithPadding:[GParams mainMenuPadding]];
	[self addChild:menu z:1000];
    
	menu.position = [GParams mainMenuStartingPoint];
    
	CCMenuItemSprite *scoresMenuItem = [CCMenuItemSprite itemFromNormalSprite:[CCSprite spriteWithFile:[GParams spriteFileName:kScoresButtonOffSprite]]
	                                                           selectedSprite:[CCSprite spriteWithFile:[GParams spriteFileName:kScoresButtonOnSprite]]
	                                                                   target:[[UIApplication sharedApplication] delegate]
                                                                     selector:nil];
	if (!paused) {
		scoresMenu = [CCMenu menuWithItems:scoresMenuItem, nil];
		scoresMenu.position = [GParams scoresMenuStartPosition];
		[self addChild:scoresMenu];
	}
}

- (void)createBackground {
	// Moving background
	bg1 = [CCSprite spriteWithFile:[GParams spriteFileName:kMainMenuBackgroundSprite]];
	bg1.position = [GParams mainMenuBackgroundStartPosition];
	[self addChild:bg1];
    
	bg2 = [CCSprite spriteWithFile:[GParams spriteFileName:kMainMenuBackgroundSprite]];
	CGPoint p = [GParams mainMenuBackgroundStartPosition];
	p.x += kGameScreenWidth;
	bg2.position = p;
	[self addChild:bg2];
}

- (void)createLetterAndLogo {
	// Shifting letters and icon
	letters = [[NSMutableArray alloc] initWithCapacity:[kGameName length]];
	for (int i = 0; i < [kGameName length]; i++) {
		NSString *letter = [NSString stringWithFormat:@"%c", [kGameName characterAtIndex:i]];
		MMLetterLabel *n = [MMLetterLabel labelWithString:letter fontName:kMainMenuFont fontSize:[GParams mainMenuTitleFontSize]];
        
		CGPoint pos = [GParams mainMenuFirstLetterPoint];
		pos.x += [GParams mainMenuLetterSpacing] * i;
        
		CGPoint p = [GParams mainMenuLetterShiftVector];
		p.x -= i * 13;
		CGPoint dest = ccpAdd(pos, p);
        
		n.position = dest;
		n.originalPosition = dest;
        
		[letters addObject:n];
		[self addChild:n];
	}
    
	icon = [MMLetterSprite spriteWithFile:[GParams spriteFileName:kGameIconSprite]];
	icon.position = [GParams mainMenuIconPoint];
	icon.originalPosition = [GParams mainMenuIconPoint];
    
	[self addChild:icon];
	[letters addObject:icon];
}

#pragma mark -
#pragma mark Timers

- (void)tick:(ccTime)dt {
	for (MMLetterLabel *letter in letters) {
		if ([letter numberOfRunningActions] != 0)
			continue;
        
		CGPoint moveVector = CGPointMake(RandomBetween(-1, 1), RandomBetween(-1, 1));
		float angle = RandomBetween(-1, 1);
        
		// Make sure we don't rotate too far
		if (letter.rotation > 15)
			angle = -1;
		if (letter.rotation < -15)
			angle = 1;
        
		if (ccpDistance(letter.originalPosition, letter.position) > 7) {
			CGPoint mVec = ccpSub(letter.originalPosition, letter.position);
			mVec.x /= 4;
			mVec.y /= 4;
			moveVector = mVec;
		}
        
		[letter runAction:[CCMoveBy actionWithDuration:kAnimationInterval position:moveVector]];
		[letter runAction:[CCRotateBy actionWithDuration:kAnimationInterval angle:angle]];
	}
}

- (void)bgMovetick:(ccTime)dt {
	float y = bg1.position.y;
    
	CGPoint bgCenterPt = [GParams mainMenuBackgroundPoint];
	if (bg1.position.x == bgCenterPt.x - kGameScreenWidth) {
		bgCenterPt.y = y;
		bgCenterPt.x += kGameScreenWidth;
		bg1.position = bgCenterPt;
	}
	else {
		CGPoint bg1Pt = bg1.position;
		bg1Pt.x -= 1;
		bg1.position = bg1Pt;
	}
    
    
	bgCenterPt = [GParams mainMenuBackgroundPoint];
	if (bg2.position.x == bgCenterPt.x - kGameScreenWidth) {
		bgCenterPt.y = y;
		bgCenterPt.x += kGameScreenWidth;
		bg2.position = bgCenterPt;
	}
	else {
		CGPoint bg2Pt = bg2.position;
		bg2Pt.x -= 1;
		bg2.position = bg2Pt;
	}
}

#pragma mark -
#pragma mark Main menu button actions

- (void)onPlay:(id)sender {
	if (inTransition)
		return;
    
    [self startGame:NO];
}

- (void)onSinglePlayer:(id)sender {
	[self startGame:NO];
}

- (void)onMultiPlayer:(id)sender {
	if (inTransition)
		return;
    
	[self startGame:YES];
}

- (void)onSettings:(id)sender {
	if (inTransition)
		return;
    
	inTransition = YES;
	state = kSettingsState;
    
	[piano playSequence:@"1,3,2,4,3,5,7"];
    
	[self performSelector:@selector(trumpetPressed) withObject:nil afterDelay:0.5];
	[self shiftOut];
	[self showSettings];
}

- (void)onCredits:(id)sender {
	if (inTransition)
		return;
    
	inTransition = YES;
	state = kCreditsState;
    
	[piano playSequence:@"1,2,3,4,5,6,7"];
    
	[self performSelector:@selector(trumpetPressed) withObject:nil afterDelay:0.5];
	[self shiftOut];
	[self showCredits];
}

- (void)onResume:(id)sender {
	if (inTransition)
		return;
    
	inTransition = YES;
	[self performSelector:@selector(trumpetPressed) withObject:nil afterDelay:0.3];
	[self shiftOut];
	//[[CCDirector sharedDirector] popSceneWithTransition:[CCTransitionSlideInR class] duration:0.35f];
    [[CCDirector sharedDirector] popScene];
}

- (void)onTutorial:(id)sender {
	[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:kShowTutorial];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self onSinglePlayer:sender];
}

- (void)onGetFullVersion:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kGameFullVersionURL] options:@{} completionHandler:nil];
}

#pragma mark -
#pragma mark Shift In/Out transitions

- (void)shiftOutWithDuration:(NSTimeInterval)duration {
	inTransition = YES;
    
	if (!paused) {
		for (int i = 0; i < [kGameName length]; i++) {
			MMLetterLabel *letter = [letters objectAtIndex:i];
            
			CGPoint p = [GParams mainMenuLetterShiftVector];
			p.x -= i * 13;
			CGPoint dest = ccpAdd(letter.originalPosition, p);
            
			[letter stopAllActions];
			[letter runAction:[CCMoveBy actionWithDuration:duration position:p]];
			[letter runAction:[CCScaleTo actionWithDuration:duration scale:0.8]];
			letter.originalPosition = dest;
			//[letter runAction: [CCRepeatForever actionWithAction: [CCDelayTime actionWithDuration: 1.0]]];
		}
		[scoresMenu runAction:[CCMoveTo actionWithDuration:duration position:[GParams scoresMenuShiftOutPosition]]];

	}
	else {
		[resumeMenu runAction:[CCFadeOut actionWithDuration:0.25]];
		[resumeMenu setIsTouchEnabled:NO];
	}
    
	[bg1 runAction:[CCMoveBy actionWithDuration:duration position:[GParams mainMenuShiftOutVector]]];
	[bg2 runAction:[CCMoveBy actionWithDuration:duration position:[GParams mainMenuShiftOutVector]]];
	[menu runAction:[CCMoveBy actionWithDuration:duration position:[GParams mainMenuShiftOutVector]]];
    
	[self runAction:[CCAction action:[CCCallFunc actionWithTarget:self selector:@selector(endTransition)] withDelay:duration + 0.2]];
}

- (void)shiftOut {
	[self shiftOutWithDuration:0.3];
}

- (void)shiftInWithDuration:(NSTimeInterval)duration {
	inTransition = YES;
    
	if (!paused) {
		for (int i = 0; i < [kGameName length]; i++) {
			MMLetterLabel *letter = [letters objectAtIndex:i];
            
			CGPoint p = [GParams mainMenuLetterShiftVector];
			p.x = (-1) * p.x;
			p.y = (-1) * p.y;
			p.x += i * 13;
			CGPoint dest = ccpAdd(letter.originalPosition, p);
            
			[letter stopAllActions];
			[letter runAction:[CCMoveBy actionWithDuration:duration position:p]];
			[letter runAction:[CCScaleTo actionWithDuration:duration scale:1.0]];
			letter.originalPosition = dest;
			//[letter runAction: [CCRepeatForever actionWithAction: [CCDelayTime actionWithDuration: 1.0]]];
		}
		[scoresMenu runAction:[CCMoveTo actionWithDuration:duration position:[GParams scoresMenuPosition]]];
	}
	else {
		[resumeMenu runAction:[CCFadeIn actionWithDuration:0.25]];
		[resumeMenu setIsTouchEnabled:YES];
	}
	[bg1 runAction:[CCMoveBy actionWithDuration:duration position:[GParams mainMenuShiftInVector]]];
	[bg2 runAction:[CCMoveBy actionWithDuration:duration position:[GParams mainMenuShiftInVector]]];
	[menu runAction:[CCMoveBy actionWithDuration:duration position:[GParams mainMenuShiftInVector]]];
    
    
	piano.tempo = 0.07;
	[piano playSequence:@"7,6,5,4,3,2,1"];
	[self performSelector:@selector(trumpetPressed) withObject:nil afterDelay:duration + 0.2];
    
	[self runAction:[CCAction action:[CCCallFunc actionWithTarget:self selector:@selector(endTransition)] withDelay:duration + 0.2]];
}

- (void)shiftIn {
	[self shiftInWithDuration:0.3];
}

- (void)endTransition {
	inTransition = NO;
}

#pragma mark -
#pragma mark Start game

- (void)startGame:(BOOL)multiPlayer {
	if (inTransition)
		return;
    
	inTransition = YES;
    
	//	[self performSelector: @selector(trumpetPressed) withObject: nil afterDelay: 0.63];
    
	if (paused) {
		[pausedScene cleanup];
        
		// tell CCDirector to remove the GameScene from the stack
		[[CCDirector sharedDirector] popScene];
	}
    
	[self shiftOut];
	[[CCDirector sharedDirector] replaceScene:[CCTransitionSlideInR transitionWithDuration:0.35 scene:[PizarroGameScene scene:multiPlayer]]];
    
	//	[self runAction: [CCSequence actions:
	//
	//					  [CCCallFunc actionWithTarget: self selector: @selector(shiftOut)],
	//					  //[CCDelayTime actionWithDuration: 0.15],
	//					  [CCCallFuncO actionWithTarget: [CCDirector sharedDirector]
	//										   selector: @selector(replaceScene:)
	//											 object: [CCTransitionSlideInR transitionWithDuration: 0.35 scene: [PizarroGameScene scene: multiPlayer]]],
	//					  nil]];
}

#pragma mark -
#pragma mark Paused menu

- (void)showPausedMenu {
	[CCMenuItemFont setFontName:kMainMenuFont];
	[CCMenuItemFont setFontSize:[GParams resumeGameFontSize]];
    
	CCMenuItemFont *menuItem1 = [CCMenuItemFont itemFromString:@"RESUME GAME" target:self selector:@selector(onResume:)];
	resumeMenu = [CCMenu menuWithItems:menuItem1, nil];
	[self addChild:resumeMenu z:1000];
	resumeMenu.position = ccpAdd([GParams resumeGameMenuPoint], ccp(-340, 0));
    
	[resumeMenu runAction:[CCEaseIn actionWithAction:[CCMoveTo actionWithDuration:0.35 position:[GParams resumeGameMenuPoint]] rate:4.0f]];
    
	[bg1 runAction:[CCMoveBy actionWithDuration:0.3 position:[GParams mainMenuShiftInVector]]];
	[bg2 runAction:[CCMoveBy actionWithDuration:0.3 position:[GParams mainMenuShiftInVector]]];
	[menu runAction:[CCMoveBy actionWithDuration:0.3 position:[GParams mainMenuShiftInVector]]];
}

#pragma mark -
#pragma mark Game type menu

- (void)showGameModeSelection {
	// kManSilhouetteSprite
	[CCMenuItemFont setFontName:kMainMenuFont];
	[CCMenuItemFont setFontSize:[GParams gameModeFontSize]];
    
	CCMenuItemFont *menuItem1 = [CCMenuItemFont itemFromString:@"Single Player" target:self selector:@selector(onSinglePlayer:)];
	CCMenuItemFont *menuItem2 = [CCMenuItemFont itemFromString:@"Two Player" target:self selector:@selector(onMultiPlayer:)];
	menuItem1.color = kWhiteColor;
	menuItem2.color = kWhiteColor;
    
	singlePlayerMenu = [CCMenu menuWithItems:menuItem1, nil];
	multiPlayerMenu = [CCMenu menuWithItems:menuItem2, nil];
    
	singlePlayerMenu.position = [GParams singlePlayerLabelStartingPoint];
	multiPlayerMenu.position = [GParams multiPlayerLabelStartingPoint];
    
	[self addChild:singlePlayerMenu z:1001];
	[self addChild:multiPlayerMenu z:1001];
    
	[singlePlayerMenu runAction:[CCMoveTo actionWithDuration:0.33 position:[GParams singlePlayerLabelPoint]]];
	[multiPlayerMenu runAction:[CCMoveTo actionWithDuration:0.33 position:[GParams multiPlayerLabelPoint]]];
}

- (void)hideGameModeSelection {
	[singlePlayerMenu runAction:[CCSequence actions:[CCMoveTo actionWithDuration:0.25 position:[GParams singlePlayerLabelStartingPoint]],
	                             [CCCallFunc actionWithTarget:singlePlayerMenu selector:@selector(disposeOfIt)], nil]];
    
	[multiPlayerMenu runAction:[CCSequence actions:[CCMoveTo actionWithDuration:0.25 position:[GParams multiPlayerLabelStartingPoint]],
	                            [CCCallFunc actionWithTarget:multiPlayerMenu selector:@selector(disposeOfIt)], nil]];
}

#pragma mark -
#pragma mark Settings

- (void)showSettings {
	musicLabel = [CCLabelTTF labelWithString:@"Music" fontName:kMainMenuFont fontSize:[GParams settingsFontSize]];
	musicLabel.position = [GParams firstSettingsStartingPoint];
	[self addChild:musicLabel z:1001];
	[musicLabel runAction:[CCMoveTo actionWithDuration:0.5 position:[GParams firstSettingsPoint]]];
    
	soundLabel = [CCLabelTTF labelWithString:@"Sound" fontName:kMainMenuFont fontSize:[GParams settingsFontSize]];
	CGPoint p = [GParams firstSettingsStartingPoint];
	p.y -= [GParams settingsSpacing];
	soundLabel.position = p;
	[self addChild:soundLabel z:1001];
	[soundLabel runAction:[CCMoveTo actionWithDuration:0.4 position:[GParams secondSettingsPoint]]];
    
	gameCenterLabel = [CCLabelTTF labelWithString:@"Game Center" fontName:kMainMenuFont fontSize:[GParams settingsFontSize]];
	p = [GParams firstSettingsStartingPoint];
	p.y -= [GParams settingsSpacing] * 2;
	gameCenterLabel.position = p;
	[self addChild:gameCenterLabel z:1001];
	[gameCenterLabel runAction:[CCMoveTo actionWithDuration:0.3 position:[GParams thirdSettingsPoint]]];
    
	CCMenuItem *musicOnItem = [CCMenuItemImage itemFromNormalImage:[GParams spriteFileName:kCheckBoxOnSprite]
	                                                 selectedImage:[GParams spriteFileName:kCheckBoxOnSprite]
	                                                        target:nil
	                                                      selector:nil];
    
	CCMenuItem *musicOffItem = [CCMenuItemImage itemFromNormalImage:[GParams spriteFileName:kCheckBoxOffSprite]
	                                                  selectedImage:[GParams spriteFileName:kCheckBoxOffSprite]
	                                                         target:nil
	                                                       selector:nil];
    
	CCMenuItem *soundOnItem = [CCMenuItemImage itemFromNormalImage:[GParams spriteFileName:kCheckBoxOnSprite]
	                                                 selectedImage:[GParams spriteFileName:kCheckBoxOnSprite]
	                                                        target:nil
	                                                      selector:nil];
    
	CCMenuItem *soundOffItem = [CCMenuItemImage itemFromNormalImage:[GParams spriteFileName:kCheckBoxOffSprite]
	                                                  selectedImage:[GParams spriteFileName:kCheckBoxOffSprite]
	                                                         target:nil
	                                                       selector:nil];
    
	CCMenuItem *gameCenterOnItem = [CCMenuItemImage itemFromNormalImage:[GParams spriteFileName:kCheckBoxOnSprite]
	                                                      selectedImage:[GParams spriteFileName:kCheckBoxOnSprite]
	                                                             target:nil
	                                                           selector:nil];
    
	CCMenuItem *gameCenterOffItem = [CCMenuItemImage itemFromNormalImage:[GParams spriteFileName:kCheckBoxOffSprite]
	                                                       selectedImage:[GParams spriteFileName:kCheckBoxOffSprite]
	                                                              target:nil
	                                                            selector:nil];
    
	ExpandingMenuItemToggle *toggleSound = [ExpandingMenuItemToggle itemWithTarget:[[UIApplication sharedApplication] delegate] selector:@selector(toggleSound) items:
	                                        soundOffItem,
	                                        soundOnItem,
	                                        nil];
	toggleSound.selectedIndex = SOUND_ENABLED;
    
	ExpandingMenuItemToggle *toggleMusic = [ExpandingMenuItemToggle itemWithTarget:[[UIApplication sharedApplication] delegate] selector:@selector(toggleMusic) items:
	                                        musicOffItem,
	                                        musicOnItem,
	                                        nil];
	toggleMusic.selectedIndex = MUSIC_ENABLED;
    
	ExpandingMenuItemToggle *toggleGameCenter = [ExpandingMenuItemToggle itemWithTarget:[[UIApplication sharedApplication] delegate] selector:@selector(toggleGameCenter) items:
	                                             gameCenterOffItem,
	                                             gameCenterOnItem,
	                                             nil];
	toggleGameCenter.selectedIndex = GAMECENTER_ENABLED;
    
	settingsMenu = [CCMenu menuWithItems:toggleMusic, toggleSound, toggleGameCenter, nil];
	[settingsMenu alignItemsVerticallyWithPadding:[GParams settingsMenuSpacing]];
	settingsMenu.position = [GParams settingsMenuStartingPoint];
	[self addChild:settingsMenu];
	[settingsMenu runAction:[CCMoveTo actionWithDuration:0.3 position:[GParams settingsMenuPoint]]];
    
	CCMenuItemSprite *tutorialMenuItem = [CCMenuItemSprite itemFromNormalSprite:[CCSprite spriteWithFile:[GParams spriteFileName:kTutorialButtonOffSprite]]
	                                                             selectedSprite:[CCSprite spriteWithFile:[GParams spriteFileName:kTutorialButtonOnSprite]]
	                                                                     target:self
	                                                                   selector:@selector(onTutorial:)];
	tutorialMenu = [CCMenu menuWithItems:tutorialMenuItem, nil];
	tutorialMenu.position = [GParams tutorialMenuStartingPoint];
	[tutorialMenu runAction:[CCMoveTo actionWithDuration:0.3 position:[GParams tutorialMenuPoint]]];
	[self addChild:tutorialMenu];
}

- (void)hideSettings {
	[musicLabel runAction:[CCSequence actions:[CCMoveTo actionWithDuration:0.25 position:[GParams firstSettingsStartingPoint]],
	                       [CCCallFunc actionWithTarget:musicLabel selector:@selector(disposeOfIt)], nil]];
	[soundLabel runAction:[CCSequence actions:[CCMoveTo actionWithDuration:0.35 position:[GParams firstSettingsStartingPoint]],
	                       [CCCallFunc actionWithTarget:soundLabel selector:@selector(disposeOfIt)], nil]];
	[gameCenterLabel runAction:[CCSequence actions:[CCMoveTo actionWithDuration:0.45 position:[GParams firstSettingsStartingPoint]],
	                            [CCCallFunc actionWithTarget:gameCenterLabel selector:@selector(disposeOfIt)], nil]];
	[settingsMenu runAction:[CCSequence actions:[CCMoveTo actionWithDuration:0.5 position:[GParams settingsMenuStartingPoint]],
	                         [CCCallFunc actionWithTarget:settingsMenu selector:@selector(disposeOfIt)], nil]];
	[tutorialMenu runAction:[CCSequence actions:[CCMoveTo actionWithDuration:0.5 position:ccp(kGameScreenWidth + 45, -35)],
	                         [CCCallFunc actionWithTarget:tutorialMenu selector:@selector(disposeOfIt)], nil]];
}

#pragma mark -
#pragma mark Credits

- (void)showCredits {
	creditsLogo = [CCSprite spriteWithFile:[GParams spriteFileName:kCompanyLogoSprite]];
	creditsLogo.position = [GParams creditsLogoStartingPoint];
	[self addChild:creditsLogo];
	[creditsLogo runAction:[CCMoveTo actionWithDuration:0.45 position:[GParams creditsLogoPoint]]];
	//[creditsLogo runAction: [CCRepeatForever actionWithAction: [CCRotateBy actionWithDuration: 0.1 angle: -10]]];
    
	NSString *creditsStr = [NSString stringWithFormat:@"A\n%@\nGAME", kGameDeveloper];
	NSString *createdByStr = [NSString stringWithFormat:@"CREATED BY\n%@ & %@", kGameProgramming, kGameGraphics];
    
	creditsLabel = [MMLetterLabel labelWithString:creditsStr dimensions:[GParams creditsLabelSize] alignment:UITextAlignmentCenter fontName:kMainMenuFont fontSize:[GParams creditsFontSize]];
	creditsLabel.position = [GParams creditsLabelStartingPoint];
	[self addChild:creditsLabel];
	[creditsLabel runAction:[CCEaseIn actionWithAction:[CCMoveTo actionWithDuration:0.45 position:[GParams creditsLabelPoint]] rate:4.0f]];
    
	createdByLabel = [MMLetterLabel labelWithString:createdByStr dimensions:[GParams createdByLabelSize] alignment:UITextAlignmentCenter fontName:kMainMenuFont fontSize:[GParams creditsFontSize]];
	createdByLabel.position = [GParams createdByLabelStartingPoint];
	[self addChild:createdByLabel];
	[createdByLabel runAction:[CCEaseIn actionWithAction:[CCMoveTo actionWithDuration:0.3 position:[GParams createdByLabelPoint]] rate:4.0f]];
}

- (void)hideCredits {
	[creditsLogo runAction:[CCSequence actions:[CCEaseIn actionWithAction:[CCMoveTo actionWithDuration:0.3 position:[GParams creditsLogoStartingPoint]] rate:4.0f],
	                        [CCCallFunc actionWithTarget:creditsLogo selector:@selector(disposeOfIt)], nil]];
	[creditsLabel runAction:[CCSequence actions:[CCEaseIn actionWithAction:[CCMoveTo actionWithDuration:0.3 position:[GParams creditsLabelStartingPoint]] rate:4.0f],
	                         [CCCallFunc actionWithTarget:creditsLabel selector:@selector(disposeOfIt)], nil]];
	[createdByLabel runAction:[CCSequence actions:[CCEaseIn actionWithAction:[CCMoveTo actionWithDuration:0.45 position:[GParams createdByLabelStartingPoint]] rate:4.0f],
	                           [CCCallFunc actionWithTarget:createdByLabel selector:@selector(disposeOfIt)], nil]];
}

#pragma mark -
#pragma mark Instruments

- (void)trumpetPressed {
	float pitch =  [Instrument bluesPitchForIndex:RandomBetween(0, 6)];
    
	if (SOUND_ENABLED)
		[[SimpleAudioEngine sharedEngine] playEffect:kTrumpetSoundEffect pitch:pitch pan:0.0f gain:0.3f];
    
	float big_scale = 1.2;
	float normal_scale = 1.0;
    
	[icon runAction:[CCSequence actions:
	                 [CCScaleTo actionWithDuration:0.1 scale:big_scale],
	                 [CCScaleTo actionWithDuration:0.2 scale:normal_scale],
	                 nil]];
}

- (void)notePressed:(NSNumber *)num {
	int note = [num intValue] - 1;
    
	float scaleNormal = 1.0, scaleLarge = 1.5;
	if (state != kMainState) {
		scaleNormal = 0.8;
		scaleLarge = 1.2;
	}
    
	[[letters objectAtIndex:note] runAction:[CCSequence actions:
	                                         [CCScaleTo actionWithDuration:0.1 scale:scaleLarge],
	                                         [CCScaleTo actionWithDuration:0.1 scale:scaleNormal],
	                                         nil]];
}

#pragma mark -
#pragma mark  Touch handling

- (void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	if (inTransition || currTouch != nil)
		return;
    
	currTouch = [touches anyObject];
	CGPoint location = [currTouch locationInView:[currTouch view]];
	location = [[CCDirector sharedDirector] convertToGL:location];
    
	BOOL playedNote = NO;
	for (int i = 0; i < [kGameName length]; i++) {
		MMLetterSprite *letter = [letters objectAtIndex:i];
		if (CGRectContainsPoint([letter rect], location)) {
			[piano playNote:i + 1];
			playedNote = YES;
		}
	}
    
	if (!playedNote && CGRectContainsPoint([icon rect], location)) {
		[self trumpetPressed];
	}
    
	// Check if press on Corrino Software
	if (!playedNote && state == kCreditsState && CGRectContainsPoint([creditsLabel rect], location)) {
		//[[UIApplication sharedApplication] openURL:[NSURL URLWithString: kGameDeveloperWebsite]];
		//return;
	}
    
	if (!playedNote) {
		switch (state) {
			case kCreditsState:
				[self shiftIn];
				[self hideCredits];
				state = kMainState;
				break;
                
			case kSettingsState:
				[self shiftIn];
				[self hideSettings];
				state = kMainState;
				break;
                
			case kGameModeState:
				[self shiftIn];
				[self hideGameModeSelection];
				state = kMainState;
				break;
		}
	}
}

- (void)ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if (inTransition || currTouch == nil)
		return;
    
	CGPoint location = [currTouch locationInView:[currTouch view]];
	location = [[CCDirector sharedDirector] convertToGL:location];
    
	BOOL playedNote = NO;
	for (int i = 0; i < [kGameName length]; i++) {
		MMLetterSprite *letter = [letters objectAtIndex:i];
		if (CGRectContainsPoint([letter rect], location)) {
			[piano playNote:i + 1];
			playedNote = YES;
		}
	}
    
	if (!playedNote && CGRectContainsPoint([icon rect], location)) {
		[self trumpetPressed];
		playedNote = YES;
	}
}

- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	currTouch = nil;
}

@end
