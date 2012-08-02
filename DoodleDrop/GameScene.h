//
//  GameScene.h
//  DoodleDrop
//
//  Created by Arbie Samong on 8/2/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"

@interface GameScene : CCLayer
{
    CCSprite *player;
    CGPoint playerVelocity;
    
    CCArray* spiders;
    float spiderMoveDuration;
    int numSpidersMoved;
    
    CCLabelTTF *scoreLabel;
    float totalTime;
    int score;
}

+ (id)scene;

@end
