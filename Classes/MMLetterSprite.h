//
//  MMLetterSprite.h
//  Pizarro
//
//  Created by Sveinbjorn Thordarson on 2/17/11.
//  Copyright 2011 Corrino Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"

@interface MMLetterSprite : CCSprite
{
	CGPoint originalPosition;
}
@property (readwrite, assign) CGPoint originalPosition;
- (CGRect)rect;
@end
