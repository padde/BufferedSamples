//
//  DummyRecorder.h
//  BufferedSamples
//
//  Created by Patrick Oscity on 21.08.12.
//  Copyright (c) 2012 Patrick Oscity. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TPCircularBuffer+AudioBufferList.h"

@interface DummyRecorder : NSObject
{

@public
    AudioComponentInstance audioUnit;
    TPCircularBuffer buffer;
    bool recording;
}

-(void)start;
-(void)stop;
-(void)consumeSamples;
-(void)createAudioUnit;

@end
