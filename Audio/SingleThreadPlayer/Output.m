//
// Created by Dmitry Promsky on 05/06/14.
//
//


#import "Output.h"
#import "Logging.h"
#import "SingleThreadPlayer.h"

#define ALog(fmt, ...) NSLog((@"%s (line %d) " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#define checkErr(err, fmt, ...) if((err) != noErr) {NSLog((@"%s (line %d) Err code = %x, %d " fmt), __PRETTY_FUNCTION__, __LINE__, (int)(err), (int)(err), ##__VA_ARGS__); return NO;}
#define checkErrGoto(err, fmt, ...) if((err) != noErr) {NSLog((@"%s (line %d) Err code = %x, %d " fmt), __PRETTY_FUNCTION__, __LINE__, (int)(err), (int)(err), ##__VA_ARGS__); goto error;}

static AudioChannelLayout* makeStereoLayout() {
    AudioChannelLayout layout = {
        .mChannelLayoutTag = kAudioChannelLayoutTag_Stereo,
        .mChannelBitmap = 0,
        .mNumberChannelDescriptions = 0,
        .mChannelDescriptions = NULL
    };
    return fillChannelLayout(&layout);
}

static SInt32* makeChannelMap(const AudioChannelLayout* inLayout, const AudioChannelLayout* outLayout) {
    // Fun channel mapping time!
    SInt32* channelMap = malloc(sizeof(SInt32) * outLayout->mNumberChannelDescriptions);
    for (int i=0; i<outLayout->mNumberChannelDescriptions; i++) {
        DLog(@"Mapping channel with label %d", (unsigned int) outLayout->mChannelDescriptions[i].mChannelLabel);
        SInt32 chNum = -1;
        for (int j=0; j<inLayout->mNumberChannelDescriptions; j++) {
            DLog(@"Testing label %d", (unsigned int) inLayout->mChannelDescriptions[j].mChannelLabel);
            if (inLayout->mChannelDescriptions[j].mChannelLabel ==
                outLayout->mChannelDescriptions[i].mChannelLabel) {
                chNum = j;
                break;
            }
        }
        channelMap[i] = chNum;
    }

    return channelMap;
}

static void setChannelCount(AudioStreamBasicDescription* asbd, int newChan) {
    assert(asbd->mFormatID == kAudioFormatLinearPCM);

    BOOL isInterleaved = !(asbd->mFormatID == kAudioFormatLinearPCM) ||
                         !(asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved);
    UInt32 numInterleavedChannels = isInterleaved ? asbd->mChannelsPerFrame : 1;
    UInt32 wordSize = 0;

    if (asbd->mBytesPerFrame > 0 && numInterleavedChannels > 0) {
        wordSize = asbd->mBytesPerFrame / numInterleavedChannels;
    } else {
        wordSize = (asbd->mBitsPerChannel + 7) / 8;
    }

    asbd->mChannelsPerFrame = newChan;
    asbd->mFramesPerPacket = 1;

    if (isInterleaved) {
        asbd->mBytesPerPacket = asbd->mBytesPerFrame = newChan * wordSize;
    } else {
        asbd->mBytesPerPacket = asbd->mBytesPerFrame = wordSize;
    }
}

// This adds downmixing matrix mixer unit to the graph if there are more channels
// in the input stream than output device is capable of playing
static BOOL setupMixer(AUGraph auGraph,
                       AUNode outputNode,
                       const AudioStreamBasicDescription* inputFormat,
                       const AudioChannelLayout* inputLayout,
                       AUNode* newHeadNode,
                       Float32** mixingMatrix,
                       UInt32* inputChannelCount,
                       UInt32* outputChannelCount) {

    AudioComponentDescription mixerDesc = {
        .componentType = kAudioUnitType_Mixer,
        .componentSubType = kAudioUnitSubType_MatrixMixer,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };

    AudioUnit outputUnit, mixerUnit;
    AUNode mixerNode;
    UInt32 propSize = sizeof(AudioStreamBasicDescription);
    UInt32 deviceChannelLayoutSize = 0;
    AudioStreamBasicDescription deviceFormat;
    AudioChannelLayout* deviceChannelLayout = NULL;
    AudioChannelLayout* mixerOutputLayout = NULL;

    *mixingMatrix = NULL;

    OSStatus ret = AUGraphNodeInfo(auGraph, outputNode, NULL, &outputUnit);
    checkErrGoto(ret, @"Can't get output unit");

    ret = AudioUnitGetProperty(outputUnit,
                               kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Output,
                               0,
                               &deviceFormat,
                               &propSize);
    checkErrGoto(ret, @"Can't get output format for device");

    DLog(@"Device format: sample rate = %f, channels = %d, bits per channel = %d", deviceFormat.mSampleRate, (unsigned int) deviceFormat.mChannelsPerFrame, (unsigned int) deviceFormat.mBitsPerChannel);

    ret = AudioUnitGetPropertyInfo(outputUnit,
                                   kAudioDevicePropertyPreferredChannelLayout,
                                   kAudioUnitScope_Output,
                                   0,
                                   &deviceChannelLayoutSize,
                                   NULL);
    if (ret == noErr) {
        deviceChannelLayout = malloc(deviceChannelLayoutSize);
        AudioUnitGetProperty(outputUnit,
                             kAudioDevicePropertyPreferredChannelLayout,
                             kAudioUnitScope_Output,
                             0,
                             deviceChannelLayout,
                             &deviceChannelLayoutSize);
        AudioChannelLayout* filledLayout = fillChannelLayout(deviceChannelLayout);
        if (filledLayout != NULL) {
            free(deviceChannelLayout);
            deviceChannelLayout = filledLayout;
        }

        // If device's channels aren't assigned in audio midi setup,
        // then the layout obtained here will contain 'unknown' values for all channel tags.
        // If that's the case, get preferred stereo channels and use those.
        BOOL allChannelsUnassigned = YES;
        for (int i=0; i<deviceChannelLayout->mNumberChannelDescriptions; i++) {
            AudioChannelLabel label = deviceChannelLayout->mChannelDescriptions[i].mChannelLabel;
            if (label != kAudioChannelLabel_Unknown && label != kAudioChannelLabel_Unused) {
                allChannelsUnassigned = NO;
                break;
            }
        }

        if (allChannelsUnassigned) {
            UInt32 stereoChannels[2] = {0, 0};
            UInt32 stereoChannelsSize = sizeof(stereoChannels);
            ret = AudioUnitGetProperty(outputUnit,
                                           kAudioDevicePropertyPreferredChannelsForStereo,
                                           kAudioUnitScope_Output,
                                           0,
                                           stereoChannels,
                                           &stereoChannelsSize);
            if (ret != noErr) {
                // just use first two channels for stereo
                stereoChannels[0] = 1;
                stereoChannels[1] = 2;
            }

            deviceChannelLayout->mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelDescriptions;
            deviceChannelLayout->mChannelDescriptions[stereoChannels[0] - 1].mChannelLabel = kAudioChannelLabel_Left;
            deviceChannelLayout->mChannelDescriptions[stereoChannels[1] - 1].mChannelLabel = kAudioChannelLabel_Right;
        }

        setChannelCount(&deviceFormat, deviceChannelLayout->mNumberChannelDescriptions);
    } else {
        ALog(@"No preferred channel layout for device: assuming stereo");
        deviceChannelLayout = makeStereoLayout();
        setChannelCount(&deviceFormat, 2);
    }

    ret = AudioUnitSetProperty(outputUnit,
                               kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Input,
                               0,
                               &deviceFormat,
                               sizeof(AudioStreamBasicDescription));
    checkErrGoto(ret, @"Can't set output unit format");

    if (deviceChannelLayout->mNumberChannelDescriptions != inputLayout->mNumberChannelDescriptions) {
        // try getting default mixing matrix for original channel mappings
        const AudioChannelLayout* layouts[2];
        layouts[0] = inputLayout;
        layouts[1] = deviceChannelLayout;
        ret = AudioFormatGetPropertyInfo(kAudioFormatProperty_MatrixMixMap,
                                         sizeof(layouts),
                                         layouts,
                                         &propSize);
        if (ret == noErr) {
            *mixingMatrix = malloc(propSize);
            ret = AudioFormatGetProperty(kAudioFormatProperty_MatrixMixMap,
                                         sizeof(layouts),
                                         layouts,
                                         &propSize,
                                         *mixingMatrix);
            mixerOutputLayout = malloc(deviceChannelLayoutSize);
            memcpy(mixerOutputLayout, deviceChannelLayout, deviceChannelLayoutSize);
        } else {
            // if that fails - get mixing matrix from original mapping to stereo
            setChannelCount(&deviceFormat, 2);
            mixerOutputLayout = makeStereoLayout();
            layouts[0] = inputLayout;
            layouts[1] = mixerOutputLayout;
            ret = AudioFormatGetPropertyInfo(kAudioFormatProperty_MatrixMixMap,
                                             sizeof(layouts),
                                             layouts,
                                             &propSize);
            if (ret == noErr) {
                *mixingMatrix = malloc(propSize);
                ret = AudioFormatGetProperty(kAudioFormatProperty_MatrixMixMap,
                                             sizeof(layouts),
                                             layouts,
                                             &propSize,
                                             *mixingMatrix);
            } else {
                free(*mixingMatrix);
                *mixingMatrix = NULL;
            }
        }
    }

    const AudioChannelLayout* halInLayout = NULL;

    if (*mixingMatrix != NULL) {
        ret = AUGraphAddNode(auGraph, &mixerDesc, &mixerNode);
        checkErrGoto(ret, @"Can't add mixer node");

        ret = AUGraphNodeInfo(auGraph, mixerNode, NULL, &mixerUnit);
        checkErrGoto(ret, @"Can't get mixer node unit");

        ret = AUGraphConnectNodeInput(auGraph, mixerNode, 0, outputNode, 0);

        // Set mixer's input format and channel layout
        AudioStreamBasicDescription mixerInputFormat;
        AudioStreamBasicDescription mixerOutputFormat;
        propSize = sizeof(AudioStreamBasicDescription);
        ret = AudioUnitGetProperty(mixerUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   0,
                                   &mixerInputFormat,
                                   &propSize);
        checkErrGoto(ret, @"Can't get mixer input format");

        setChannelCount(&mixerInputFormat, inputLayout->mNumberChannelDescriptions);
        mixerInputFormat.mSampleRate = deviceFormat.mSampleRate;

        ret = AudioUnitSetProperty(mixerUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   0,
                                   &mixerInputFormat,
                                   sizeof(AudioStreamBasicDescription));
        checkErrGoto(ret, @"Can't set mixer input format, ret = %x,%u,%d", (unsigned int) ret, (unsigned int) ret, (int) ret);

        // Set mixer's output format
        propSize = sizeof(AudioStreamBasicDescription);
        ret = AudioUnitGetProperty(mixerUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Output,
                                   0,
                                   &mixerOutputFormat,
                                   &propSize);
        checkErrGoto(ret, @"Can't get mixer output format");

        setChannelCount(&mixerOutputFormat, mixerOutputLayout->mNumberChannelDescriptions);
        mixerOutputFormat.mSampleRate = mixerInputFormat.mSampleRate;

        ret = AudioUnitSetProperty(mixerUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Output,
                                   0,
                                   &mixerOutputFormat,
                                   sizeof(AudioStreamBasicDescription));
        checkErrGoto(ret, @"Can't set mixer output format");

        UInt32 numMixerBuses = 1; // Mixer has single multichannel input bus and single multichannel output bus
        ret = AudioUnitSetProperty(mixerUnit,
                                   kAudioUnitProperty_ElementCount,
                                   kAudioUnitScope_Input,
                                   0,
                                   &numMixerBuses,
                                   sizeof(UInt32));
        checkErrGoto(ret, @"Can't set mixer input bus count");

        ret = AudioUnitSetProperty(mixerUnit,
                                   kAudioUnitProperty_ElementCount,
                                   kAudioUnitScope_Output,
                                   0,
                                   &numMixerBuses,
                                   sizeof(UInt32));
        checkErrGoto(ret, @"Can't set mixer output bus count");

        // Mixer unit doesn't have its mixing matrix set here, as
        // it's a parameter and requires that mixer unit is initialized,
        // so that is done later.

        ret = AudioUnitSetProperty(outputUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   0,
                                   &mixerOutputFormat,
                                   sizeof(AudioStreamBasicDescription));
        checkErrGoto(ret, @"Can't set HAL input format to mixer's output format");

        *newHeadNode = mixerNode;
        *inputChannelCount = inputLayout->mNumberChannelDescriptions;
        *outputChannelCount = mixerOutputLayout->mNumberChannelDescriptions;

        halInLayout = mixerOutputLayout;
    } else {
        // No mixing - just set up proper channel mapping
        *newHeadNode = outputNode;
        halInLayout = inputLayout;
    }

    SInt32* deviceChannelMap = makeChannelMap(halInLayout, deviceChannelLayout);
    ret = AudioUnitSetProperty(outputUnit,
                               kAudioOutputUnitProperty_ChannelMap,
                               kAudioUnitScope_Input,
                               0,
                               deviceChannelMap,
                               deviceChannelLayout->mNumberChannelDescriptions * sizeof(SInt32));
    free(deviceChannelMap);
    checkErrGoto(ret, @"Can't set output channel map");

    free(deviceChannelLayout);
    free(mixerOutputLayout);

    return YES;

error:
    if (deviceChannelLayout != NULL) {
        free(deviceChannelLayout);
    }

    if (mixerOutputLayout != NULL) {
        free(mixerOutputLayout);
    }

    if (*mixingMatrix != NULL) {
        free(*mixingMatrix);
        *mixingMatrix = NULL;
    }

    return NO;
}

static BOOL setupConverter(AUGraph auGraph, AUNode headNode,
    const AudioStreamBasicDescription* inputFormat, AUNode* newHeadNode) {

    AudioComponentDescription converterDesc = {
        .componentType = kAudioUnitType_FormatConverter,
        .componentSubType = kAudioUnitSubType_AUConverter,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };

    AudioUnit headUnit, convUnit;
    AUNode convNode;
    UInt32 propSize;
    AudioStreamBasicDescription graphInFormat;
    OSStatus ret = AUGraphNodeInfo(auGraph, headNode, NULL, &headUnit);
    checkErr(ret, @"Can't get head unit");

    propSize = sizeof(AudioStreamBasicDescription);
    ret = AudioUnitGetProperty(headUnit,
                               kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Input,
                               0,
                               &graphInFormat,
                               &propSize);
    checkErr(ret, @"Can't get graph input format");

    if (inputFormat->mSampleRate != graphInFormat.mSampleRate ||
        inputFormat->mFormatFlags != graphInFormat.mFormatFlags ||
        inputFormat->mBitsPerChannel != graphInFormat.mBitsPerChannel) {

        ret = AUGraphAddNode(auGraph, &converterDesc, &convNode);
        checkErr(ret, @"Can't add converter node");

        ret = AUGraphNodeInfo(auGraph, convNode, NULL, &convUnit);
        checkErr(ret, @"Can't add converter unit");

        ret = AUGraphConnectNodeInput(auGraph, convNode, 0, headNode, 0);
        checkErr(ret, @"Can't connect converter node");

        ret = AudioUnitSetProperty(convUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   0,
                                   inputFormat,
                                   sizeof(AudioStreamBasicDescription));
        checkErr(ret, @"Can't set input format for converter");

        ret = AudioUnitSetProperty(convUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Output,
                                   0,
                                   &graphInFormat,
                                   sizeof(AudioStreamBasicDescription));
        checkErr(ret, @"Can't set output format for converter");

        *newHeadNode = convNode;
    } else {
        *newHeadNode = headNode;
    }

    return YES;
}

static OSStatus renderInputSine(
                            void *inRefCon,
                            AudioUnitRenderActionFlags *ioActionFlags,
                            const AudioTimeStamp *inTimeStamp,
                            UInt32 inBusNumber,
                            UInt32 inNumberFrames,
                            AudioBufferList  *ioData) {

    Output* out = (Output*) inRefCon;
    Float32 *outA = (Float32*) ioData->mBuffers[0].mData;
    // SInt32* outA = (SInt32*) ioData->mBuffers[0].mData;
    // AudioSampleType *outA = (AudioSampleType*) ioData->mBuffers[0].mData;

    float freqL = 300;
    float freqR = 500;
    float freqC = 0;
    float freqLFE = 0;
    float freqLS = 500;
    float freqRS = 300;
    float samplePeriod = 1.0 / 44100.0;

    for (UInt32 i = 0; i < inNumberFrames; ++i) {
        // outA[2*i] = (SInt32) ((2147483647.0 / 2.0) * sin(2*M_PI*freqL*out->time));
        // outA[2*i+1] = (SInt32) ((2147483647.0 / 2.0) * sin(2*M_PI*freqR*out->time));
//        outA[2*i] = sin(2*M_PI*freqL*out->time);
//        outA[2*i+1] = sin(2*M_PI*freqR*out->time);
        outA[6*i  ] = sin(2*M_PI*freqL*out->time);
        outA[6*i+1] = sin(2*M_PI*freqR*out->time);
        outA[6*i+2] = sin(2*M_PI*freqC*out->time);
        outA[6*i+3] = sin(2*M_PI*freqLFE*out->time);
        outA[6*i+4] = sin(2*M_PI*freqLS*out->time);
        outA[6*i+5] = sin(2*M_PI*freqRS*out->time);
        // outA[2*i] = (SInt16)(sinSignal * 32767.0f);
        // outA[2*i + 1] = (SInt16)(sinSignal * 32767.0f);

        out->time += samplePeriod;
    }

    // ioData->mBuffers[0].mDataByteSize = inNumberFrames * sizeof(AudioSampleType) * 2;
    // ioData->mBuffers[0].mNumberChannels = 2;

    return noErr;
}

static OSStatus renderInput(
        void *inRefCon,
        AudioUnitRenderActionFlags *ioActionFlags,
        const AudioTimeStamp *inTimeStamp,
        UInt32 inBusNumber,
        UInt32 inNumberFrames,
        AudioBufferList  *ioData) {

    Output* output = (Output*) inRefCon;
    OSStatus err = noErr;
    void* readPointer = ioData->mBuffers[0].mData;
    int bytesRead = [[output player] outputReadAudio:readPointer frameCount:inNumberFrames];

    if (bytesRead < 0) {
        err = -1;
        bytesRead = 0;
    }

    ioData->mBuffers[0].mDataByteSize = (UInt32)bytesRead;

    return err;
}

static BOOL setMixingMatrix(AudioUnit mixerUnit,
                            Float32* mixingMatrix,
                            UInt32 mixerInChans,
                            UInt32 mixerOutChans) {

    OSStatus ret = AudioUnitSetParameter(mixerUnit,
                                         kMatrixMixerParam_Enable,
                                         kAudioUnitScope_Input,
                                         0,
                                         1,
                                         0);
    checkErr(ret, @"Can't enable mixer input");

    ret = AudioUnitSetParameter(mixerUnit,
                                kMatrixMixerParam_Enable,
                                kAudioUnitScope_Output,
                                0,
                                1,
                                0);
    checkErr(ret, @"Can't enable mixer output");

    for (UInt32 i=0; i<mixerInChans; i++) {
        ret = AudioUnitSetParameter(mixerUnit,
                                    kMatrixMixerParam_Volume,
                                    kAudioUnitScope_Input,
                                    i,
                                    1.0,
                                    0);
        checkErr(ret, @"Can't set mixer input volume (%d)", (int) i);
    }

    for (UInt32 i=0; i<mixerOutChans; i++) {
        // We can PROBABLY set output volume to something other than
        // 1.0 here to try avoiding clipping
        ret = AudioUnitSetParameter(mixerUnit,
                                    kMatrixMixerParam_Volume,
                                    kAudioUnitScope_Output,
                                    i,
                                    1.0,
                                    0);
        checkErr(ret, @"Can't set mixer output volume (%d)", (int) i);
    }

    ret = AudioUnitSetParameter(mixerUnit,
                                kMatrixMixerParam_Volume,
                                kAudioUnitScope_Global,
                                0xFFFFFFFF,
                                1.0,
                                0);
    checkErr(ret, @"Can't set mixer master volume");

    // Set mixer's mixing matrix
    for (UInt32 i=0; i<mixerInChans; i++) {
        for (UInt32 j=0; j<mixerOutChans; j++) {
            Float32 paramValue = mixingMatrix[i*mixerOutChans + j];
            UInt32 element = (i << 16) | (j & 0x0000FFFF);
            ret = AudioUnitSetParameter(mixerUnit,
                                        kMatrixMixerParam_Volume,
                                        kAudioUnitScope_Global,
                                        element,
                                        paramValue,
                                        0);
            checkErr(ret, @"Can't set mixing volume for i = %d, j = %d, ret = %d", (unsigned int) i, (unsigned int) j, (int)ret);
        }
    }

    return YES;
    // UInt32 matrixDim[2];
    // UInt32 propSize = sizeof(matrixDim);
    // ret = AudioUnitGetProperty(mixerUnit,
    //                            kAudioUnitProperty_MatrixDimensions,
    //                            kAudioUnitScope_Global,
    //                            0,
    //                            matrixDim,
    //                            &propSize);
    // checkErr(ret, @"Can't get mixer matrix dimensions");

    // propSize = (matrixDim[0]+1) * (matrixDim[1]+1) * sizeof(Float32);
    // Float32* matrix = (Float32*) malloc(propSize);
    // ret = AudioUnitGetProperty(mixerUnit,
    //                            kAudioUnitProperty_MatrixLevels,
    //                            kAudioUnitScope_Global,
    //                            0,
    //                            matrix,
    //                            &propSize);
    // checkErr(ret, @"Can't get mixer matrix");

    // for (int i=0; i<(matrixDim[0] + 1); i++) {
    //     for(int j=0; j<(matrixDim[1] + 1); j++) {
    //         NSLog(@"matrix[%d][%d] = %f", i, j, (float) matrix[i*(matrixDim[1]+1) + j]);
    //     }
    // }
}

@implementation Output
- (id)init {
    self = [super init];
    if (self) {
        currentInChannelLayout = NULL;
        currentInFormat = NULL;
    }
    return self;
}

- (void)dealloc {
    if (currentInChannelLayout != NULL) {
        free(currentInChannelLayout);
        currentInChannelLayout = NULL;
    }

    if (currentInFormat != NULL) {
        free(currentInFormat);
        currentInChannelLayout = NULL;
    }

    DisposeAUGraph(auGraph);

    [super dealloc];
}

- (BOOL) setupWithPlayer:(id<OutputDelegate>) player {
    AudioComponentDescription outputDesc = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_HALOutput,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };

    self->player = player;

    AudioDeviceID deviceId = [player outputGetDeviceId];
    const AudioStreamBasicDescription* format = [player outputGetFormat];
    const AudioChannelLayout* channelLayout = [player outputGetChannelLayout];

    AUNode outputNode, headNode;
    AudioUnit headUnit, mixerUnit;

    Float32* mixingMatrix = NULL;

    UInt32 mixerInChans, mixerOutChans;

    OSStatus ret = NewAUGraph(&auGraph);
    checkErr(ret, @"Can't create augraph");

    ret = AUGraphOpen(auGraph);
    checkErrGoto(ret, @"Can't open augraph");

    ret = AUGraphAddNode(auGraph, &outputDesc, &outputNode);
    checkErrGoto(ret, @"Can't add output node");

    ret = AUGraphNodeInfo(auGraph, outputNode, NULL, &outputUnit);
    checkErrGoto(ret, @"Can't get output unit");

    ret = AudioUnitSetProperty(outputUnit,
                               kAudioOutputUnitProperty_CurrentDevice,
                               kAudioUnitScope_Output,
                               0,
                               &deviceId,
                               sizeof(AudioDeviceID));
    checkErr(ret, @"Can't set output device");

    if (!setupMixer(auGraph, outputNode, format, channelLayout, &headNode, &mixingMatrix, &mixerInChans, &mixerOutChans)) {
        ALog(@"Setting up mixer failed :(");
        goto error;
    }

    if (mixingMatrix != NULL) {
        // there's some channel mixing going on, the head node is matrix mixer now
        // we need corresponding unit to set mixing matrix after graph initialization
        ret = AUGraphNodeInfo(auGraph, headNode, NULL, &mixerUnit);
        checkErrGoto(ret, @"Can't get mixer unit");
    }

    if (!setupConverter(auGraph, headNode, format, &headNode)) {
        ALog(@"Setting up converter failed :(");
        goto error;
    }

    ret = AUGraphNodeInfo(auGraph, headNode, NULL, &headUnit);
    checkErrGoto(ret, @"Can't get head unit");

    AURenderCallbackStruct rcbs;
    rcbs.inputProc = &renderInput;
    rcbs.inputProcRefCon = self;
    ret = AudioUnitSetProperty(headUnit,
                               kAudioUnitProperty_SetRenderCallback,
                               kAudioUnitScope_Input,
                               0,
                               &rcbs,
                               sizeof(rcbs));
    checkErrGoto(ret, "Can't set graph render callback");

    ret = AUGraphInitialize(auGraph);
    checkErrGoto(ret, @"Can't initialize graph");

    if (mixingMatrix != NULL) {
        if (!setMixingMatrix(mixerUnit, mixingMatrix, mixerInChans, mixerOutChans)) {
            ALog(@"Can't set mixing matrix");
            goto error;
        }
    }

    ALog(@"Graph after start: ");
    CAShow(auGraph);

    if (mixingMatrix != NULL) {
        free(mixingMatrix);
    }

    currentInFormat = malloc(sizeof(AudioStreamBasicDescription));
    memcpy(currentInFormat, format, sizeof(AudioStreamBasicDescription));
    int layoutSize = sizeof(AudioChannelLayoutTag) +
                     2*sizeof(UInt32) +
                     channelLayout->mNumberChannelDescriptions*sizeof(AudioChannelDescription);
    currentInChannelLayout = malloc(layoutSize);
    memcpy(currentInChannelLayout, channelLayout, layoutSize);

    return YES;

error:
    DisposeAUGraph(auGraph);

    if (mixingMatrix != NULL) {
        free(mixingMatrix);
    }

    return NO;
}

- (BOOL)start {
    OSStatus ret = AUGraphStart(auGraph);
    checkErr(ret, @"Can't start augraph");
    return YES;
}

- (BOOL)stop {
    OSStatus ret = AUGraphStop(auGraph);
    checkErr(ret, @"Can't stop augraph");
    return YES;
}

- (BOOL)isRunning {
    Boolean result = NO;
    OSStatus ret = AUGraphIsRunning(auGraph, &result);
    checkErr(ret, @"Can't figure out if augraph is running or not");
    return result;
}

- (BOOL)setVolume:(double)vol {
    NSLog(@"Output setting volume: %f", vol);
    OSStatus ret = AudioUnitSetParameter(outputUnit,
                                         kHALOutputParam_Volume,
                                         kAudioUnitScope_Global,
                                         0,
                                         vol * 0.01f,
                                         0);
    checkErr(ret, @"Can't set volume");
    return YES;
}

- (SingleThreadPlayer *)player {
    return player;
}

- (const AudioStreamBasicDescription *)format {
    return currentInFormat;
}

- (const AudioChannelLayout *)channelLayout {
    return currentInChannelLayout;
}


@end