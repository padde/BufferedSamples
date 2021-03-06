//
//  DummyRecorder.m
//  BufferedSamples
//
//  Created by Patrick Oscity on 21.08.12.
//  Copyright (c) 2012 Patrick Oscity. All rights reserved.
//

#import "DummyRecorder.h"


#define kTwoBytesPerSInt16 2
#define kEightBitsPerByte 8
#define kSInt16Max 32768 // = 2^15

#define kInputBus 1
#define kSamplingRate 44100.0
#define kBufferLength 4096*kTwoBytesPerSInt16 // holds 4096 samples (or more)

// taken from http://pastebin.com/zMc3xBMS by Michael Tyson
#define checkResult(result,operation) (_checkResult((result),(operation),strrchr(__FILE__, '/'),__LINE__))
static inline BOOL _checkResult(OSStatus result, const char *operation, const char* file, int line) {
    if ( result != noErr ) {
        NSLog(@"%s:%d: %s result %d %08X %4.4s\n", file, line, operation, (int)result, (int)result, (char*)&result);
        return NO;
    }
    return YES;
}

static OSStatus inputCallback(void *inRefCon,
                              AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp,
                              UInt32 inBusNumber,
                              UInt32 inNumberFrames,
                              AudioBufferList *ioData)
{
	DummyRecorder *dummyRecorder = (DummyRecorder*)inRefCon;
    
    // render samples into buffer
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mNumberChannels = 1;
    bufferList.mBuffers[0].mDataByteSize = inNumberFrames * kTwoBytesPerSInt16;
    bufferList.mBuffers[0].mData = NULL;
    
    OSStatus err = AudioUnitRender(dummyRecorder->audioUnit, ioActionFlags, inTimeStamp, kInputBus, inNumberFrames, &bufferList);
    
    
    // move samples to ring buffer
    if (checkResult(err, "AudioUnitRender"))
        TPCircularBufferProduceBytes(&dummyRecorder->buffer, bufferList.mBuffers[0].mData, bufferList.mBuffers[0].mDataByteSize);
    
    
    return noErr;
}


@implementation DummyRecorder


-(id)init
{
    self = [super init];
    if (self) {
        TPCircularBufferInit(&buffer, kBufferLength);
        
        [self createAudioUnit];
    }
    
    return self;
}

-(void)dealloc
{
    OSStatus err;
    err = AudioComponentInstanceDispose(audioUnit);
    checkResult(err, "AudioComponentInstanceDispose");
    
    TPCircularBufferCleanup(&buffer);
    
    [super dealloc];
}

-(void)start
{
    OSStatus err;
    err = AudioUnitInitialize(audioUnit);
    checkResult(err, "AudioUnitInitialize");
    err = AudioOutputUnitStart(audioUnit);
    checkResult(err, "AudioOutputUnitStart");
    
    recording = YES;
    [self performSelectorInBackground:@selector(consumeSamples) withObject:nil];
}

-(void)stop
{
    recording = NO;
    
    OSStatus err;
    err = AudioOutputUnitStop(audioUnit);
    checkResult(err, "AudioOutputUnitStop");
    err = AudioUnitUninitialize(audioUnit);
    checkResult(err, "AudioUnitUninitialize");
    audioUnit = nil;
}

-(void)consumeSamples
{
    while (recording) {
        int32_t availableBytes;
        SInt16 *incomingSamples = TPCircularBufferTail(&buffer, &availableBytes);
        
        int samplesToRead = 500;
        
        if (availableBytes >= samplesToRead) {
            // compute average rectified value
            int arv = 0;
            for (int i=0; i<samplesToRead; i++) {
                arv += abs(incomingSamples[i]);
            }
            arv /= samplesToRead;
            
            NSLog(@"%d", arv);
            
            TPCircularBufferConsume(&buffer, samplesToRead);
        } else {
            usleep(50);
        }
    }
}

-(void)createAudioUnit
{
    OSStatus err;
    
    // describe audio unit
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO; // iOS
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    // get audio component and unit
    AudioComponent ac = AudioComponentFindNext(NULL, &desc);
    err = AudioComponentInstanceNew(ac, &audioUnit);
    checkResult(err, "AudioComponentInstanceNew");
    
    // enable recording
	UInt32 flag = 1;
    err = AudioUnitSetProperty(audioUnit,
                               kAudioOutputUnitProperty_EnableIO,
                               kAudioUnitScope_Input,
                               kInputBus,
                               &flag,
                               sizeof(flag));
    checkResult(err, "AudioUnitSetProperty-EnableIO-Scope_Input");
    
    // set format
	AudioStreamBasicDescription fmt;
	fmt.mSampleRate       = kSamplingRate;
	fmt.mFormatID         = kAudioFormatLinearPCM;
	fmt.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    fmt.mChannelsPerFrame = 1;
    fmt.mFramesPerPacket  = 1;
    fmt.mBytesPerFrame    = kTwoBytesPerSInt16;
	fmt.mBytesPerPacket   = kTwoBytesPerSInt16;
	fmt.mBitsPerChannel   = kTwoBytesPerSInt16 * kEightBitsPerByte;
    err = AudioUnitSetProperty(audioUnit,
                               kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Input,
                               0,
                               &fmt,
                               sizeof(fmt));
    checkResult(err, "AudioUnitSetProperty-StreamFormat-Scope_Input");
    
    // set callback
	AURenderCallbackStruct cbStruct;
	cbStruct.inputProc = inputCallback;
	cbStruct.inputProcRefCon = self;
	err = AudioUnitSetProperty(audioUnit,
                               kAudioOutputUnitProperty_SetInputCallback,
                               kAudioUnitScope_Global,
                               kInputBus,
                               &cbStruct,
                               sizeof(cbStruct));
    checkResult(err, "AudioUnitSetProperty-SetInputCallback-Scope_Global");
}

@end
