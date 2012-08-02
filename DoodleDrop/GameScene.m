//
//  GameScene.m
//  DoodleDrop
//
//  Created by Arbie Samong on 8/2/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "GameScene.h"
#import "SimpleAudioEngine.h"

@interface GameScene (PrivateMethods)
-(void) initSpiders;
-(void) resetSpiders;
-(void) spidersUpdate:(ccTime)delta;
-(void) runSpiderMoveSequence:(CCSprite*)spider;
-(void) spiderBelowScreen:(id)sender;
-(void) checkForCollision;
@end

@implementation GameScene

+ (id)scene
{
    CCScene *scene = [CCScene node];
    CCLayer *layer = [GameScene node];
    [scene addChild:layer];
    return scene;
}

- (id)init
{
    if ((self = [super init])) {
        CCLOG(@"%@: %@", NSStringFromSelector(_cmd), self);
        
        self.isAccelerometerEnabled = YES;
        
        [self scheduleUpdate];
        [self initSpiders];
        
        // create player
        player = [CCSprite spriteWithFile:@"alien.png"];
        [self addChild:player z:0 tag:1];
        
        // position player relatively
        CGSize screenSize = [[CCDirector sharedDirector] winSize];
        float imageHeight = [player texture].contentSize.height;
        player.position = CGPointMake(screenSize.width/2, imageHeight/2);
        
        // score label
        scoreLabel = [CCLabelTTF labelWithString:@"0" fontName:@"Arial" fontSize:48];
        scoreLabel.position = CGPointMake(screenSize.width/2, screenSize.height);
        // adjust the label's anchor point's y position to make it align with the top
        scoreLabel.anchorPoint = CGPointMake(0.5f, 1.0f);
        // add the score label with z value of -1 so it's drawn below everything else
        [self addChild:scoreLabel z:-1];
        
        [[SimpleAudioEngine sharedEngine] playBackgroundMusic:@"blues.mp3" loop:YES];
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"alien-sfx.caf"];
    }
    return self;
}

- (void)dealloc
{
    CCLOG(@"%@: %@", NSStringFromSelector(_cmd), self);
    
    // release required when using [CCArray alloc]
    [spiders release];
    
    // Never forget to call [super dealloc]!
    [super dealloc];
}

#pragma mark Spiders

- (void)initSpiders
{
    CGSize screenSize = [[CCDirector sharedDirector] winSize];
    // using a temporary spider sprite is the easiest way to get the image's size
    
    CCSprite* tempSpider = [CCSprite spriteWithFile:@"spider.png"];
    float imageWidth = [tempSpider texture].contentSize.width;
    
    // Use as many spiders as can fit next to each other over the whole screen width.
    int numSpiders = screenSize.width / imageWidth;
    
    // Initialize the spiders array using alloc.
    NSAssert(spiders == nil, @"%@: spiders array is already initialized!", NSStringFromSelector(_cmd));
    spiders = [[CCArray alloc] initWithCapacity:numSpiders];
    
    for (int i = 0; i < numSpiders; i++)
    {
        CCSprite* spider = [CCSprite spriteWithFile:@"spider.png"];
        [self addChild:spider z:0 tag:2];
        // Also add the spider to the spiders array.
        [spiders addObject:spider];
    }
    
    // call the method to reposition all spiders
    [self resetSpiders];
}

- (void)resetSpiders
{
    CGSize screenSize = [[CCDirector sharedDirector] winSize];
    
    int numSpiders = [spiders count];
    if (numSpiders > 0) {
        // Get any spider to get its image width
        CCSprite* tempSpider = [spiders lastObject];
        CGSize size = [tempSpider texture].contentSize;
        
        for (int i = 0; i < numSpiders; i++)
        {
            // Put each spider at its designated position outside the screen
            CCSprite* spider = [spiders objectAtIndex:i];
            spider.position = CGPointMake(size.width * i + size.width * 0.5f, screenSize.height + size.height);
        }
    }
    
    // Unschedule the selector just in case. If it isn't scheduled it won't do anything.
    [self unschedule:@selector(spidersUpdate:)];
    // Schedule the spider update logic to run at the given interval.
    [self schedule:@selector(spidersUpdate:) interval:0.7f];
    
    // reset the moved spiders counter and spider move duration (affects spider's speed)
	numSpidersMoved = 0;
	spiderMoveDuration = 4.0f;
}

- (void)spidersUpdate:(ccTime)delta
{
    // try to find a spider which isn't currently working
    for (int i=0; i<10; i++) {
        int randomSpiderIndex = CCRANDOM_0_1() * [spiders count];
        CCSprite* spider = [spiders objectAtIndex:randomSpiderIndex];
        
        // If the spider isn't moving it won’t have any running actions.
        if ([spider numberOfRunningActions] == 0) {
            if (i > 0) {
                CCLOG(@"Dropping a Spider after %i retries", i);
            }
            
            // This is the sequence which controls the spiders' movement
            [self runSpiderMoveSequence:spider];
            
            // Only one spider should start moving at a time.
            break;
        }
    }
}

- (void)runSpiderMoveSequence:(CCSprite *)spider
{
    // Slowly increase the spider speed over time.
    numSpidersMoved++;
    if (numSpidersMoved % 8 == 0 && spiderMoveDuration > 2.0f) {
        spiderMoveDuration -= 0.1f;
    }
    
    // This is the sequence which controls the spiders' movement.
    CGPoint belowScreenPosition = CGPointMake(spider.position.x, -[spider texture].contentSize.height);
    CCMoveTo* move = [CCMoveTo actionWithDuration:spiderMoveDuration position:belowScreenPosition];
    CCCallFuncN* call = [CCCallFuncN actionWithTarget:self selector:@selector(spiderBelowScreen:)];
    CCSequence* sequence = [CCSequence actions:move, call, nil];
    [spider runAction:sequence];
}

- (void)spiderBelowScreen:(id)sender
{
    // Make sure sender is actually of the right class.
    NSAssert([sender isKindOfClass:[CCSprite class]], @"sender is not a CCSprite!");
    CCSprite* spider = (CCSprite*)sender;
    
    // move the spider back up outside the top of the screen
    CGPoint pos = spider.position;
    CGSize screenSize = [[CCDirector sharedDirector] winSize];
    pos.y = screenSize.height + [spider texture].contentSize.height;
    spider.position = pos;
}

#pragma mark accelerometer input

- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
    // controls how quickly velocity decelerates
    // lower = quicer to change direction
    float deceleration = 0.4f;
    
    // determines how sensitive the accelerometer reacts
    // higher = more sensitive
    float sensitivity = 6.0f;
    
    // how fast the velocity can be at most
    float maxVelocity = 100;
    
    // adjust player velocity based on current accelerometer acceleration
    playerVelocity.x = playerVelocity.x * deceleration + acceleration.x * sensitivity;
    
    // limit the player velocity of the player sprite, in both directions
    if (playerVelocity.x > maxVelocity) {
        playerVelocity.x = maxVelocity;
    } else if (playerVelocity.x < - maxVelocity) {
        playerVelocity.x = - maxVelocity;
    }
}

#pragma mark update

- (void)update:(ccTime)delta
{
    // keep adding the player velocity to the player's position
    CGPoint pos = player.position;
    pos.x += playerVelocity.x;
    
    // determine player and screen bounds
    CGSize screenSize = [[CCDirector sharedDirector] winSize];
    float imageWidthHalved = [player texture].contentSize.width * 0.5f;
    float leftBorderLimit = imageWidthHalved;
    float rightBorderLimit = screenSize.width - imageWidthHalved;
    
    // prevent the player sprite from moving outside the screen
    if (pos.x < leftBorderLimit) {
        pos.x = leftBorderLimit;
        playerVelocity = CGPointZero;
    } else if (pos.x > rightBorderLimit) {
        pos.x = rightBorderLimit;
        playerVelocity = CGPointZero;
    }
    // Alternatively, the above if/else if block can be rewritten using fminf and fmaxf more neatly like so:
	// pos.x = fmaxf(fminf(pos.x, rightBorderLimit), leftBorderLimit);
    
    // assign the modified position back
    player.position = pos;
    
    // collison detection
    [self checkForCollision];
    
    // update the Score (Timer) once per second
    totalTime += delta;
    int currentTime = (int)totalTime;
    if (score < currentTime) {
        score = currentTime;
        [scoreLabel setString:[NSString stringWithFormat:@"%i", score]];
    }
}

#pragma mark Collision

- (void)checkForCollision
{
    // assumption: both player and spider images are squares
    float playerImageSize = [player texture].contentSize.width;
    float playerCollisionRadius = playerImageSize * 0.4f;
    
    float spiderImageSize = [[spiders lastObject] texture].contentSize.width;
    float spiderCollisionRadius = spiderImageSize * 0.4f;
    
    // this collision distance will roughly equal the image shapes
    float maxCollisionDistance = playerCollisionRadius + spiderCollisionRadius;
    
    int numSpiders = [spiders count];
    for (int i=0; i<numSpiders; i++) {
        CCSprite *spider = [spiders objectAtIndex:i];
        
        if ([spider numberOfRunningActions] == 0) {
             // this spider isn't even moving so we can skip checking it
            continue;
        }
        
        // get the distance between player and spider
        float actualDistance = ccpDistance(player.position, spider.position);
        
        // are the two objects closer than allowed?
        if (actualDistance < maxCollisionDistance) {
            [[SimpleAudioEngine sharedEngine] playEffect:@"alien-sfx.caf"];
            
            CCBlink *blinkAction = [CCBlink actionWithDuration:1.0 blinks:3.0];
            [player runAction:blinkAction];
                        
            // no game over, just reset the spiders
            [self resetSpiders];
        }
    }
    
}
          
@end
