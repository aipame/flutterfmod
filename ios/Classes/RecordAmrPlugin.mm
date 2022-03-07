#import "RecordAmrPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <EMVoiceConvert.h>
#import "amrFileCodec.h"

@interface RecordAmrPlugin () <AVAudioRecorderDelegate, AVAudioPlayerDelegate>
{
    NSError *_error;
    NSString *recordPath;
    FlutterResult _endResult;
    NSTimer *_levelTimer;
    NSDictionary *_recordSetting;
    NSDate *_startDate;
}
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) FlutterMethodChannel* channel;
@property (nonatomic, strong) NSString *playingPath;

@end
    
@implementation RecordAmrPlugin


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"record_amr"
                                     binaryMessenger:[registrar messenger]];
    RecordAmrPlugin* instance = [[RecordAmrPlugin alloc] init];
    instance.channel = channel;
    [registrar addMethodCallDelegate:instance channel:channel];
}


- (void)handleMethodCall:(FlutterMethodCall*)call
                  result:(FlutterResult)result {
    
    if ([@"startVoiceRecord" isEqualToString:call.method])
    {
        [self startVoiceRecord:call.arguments result:result];
    }
    else if ([@"stopVoiceRecord" isEqualToString:call.method])
    {
        [self stopVoiceRecord:call.arguments result:result];
    }
    else if ([@"cancelVoiceRecord" isEqualToString:call.method])
    {
        [self cancelVoiceRecord:call.arguments result:result];
    }
    else if ([@"play" isEqualToString:call.method])
    {
        [self playAmr:call.arguments result:result];
    }
    else if ([@"stopPlaying" isEqualToString:call.method])
    {
        [self stopPlayAmrFile:call.arguments result:result];
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)startVoiceRecord:(NSDictionary *)callInfo result:(FlutterResult)result {
    
    if (self.recorder && self.recorder.isRecording) {
        NSLog(@"开始失败，目前正在录制");
        result(@NO);
        return;
    }
    
    NSError *error;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDuckOthers error:&error];
    if (!error){
        [[AVAudioSession sharedInstance] setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    }
    
    if (error) {
        error = [NSError errorWithDomain:@"AVAudioSession SetCategory失败" code:-1 userInfo:nil];
        NSLog(@"开始失败，设备初始化错误");
        result(@NO);
        return;
    }
    
    recordPath = [self.path stringByAppendingFormat:@"/%.0f", [[NSDate date] timeIntervalSince1970] * 1000];
    [self _startRecordWithPath:recordPath
                   completion:^(NSError *error)
    {
        result(@(error == nil));
    }];
}

- (void)stopVoiceRecord:(NSDictionary *)callInfo result:(FlutterResult)result {
    [self _stopRecordWithCompletion:result];
}

- (void)cancelVoiceRecord:(NSDictionary *)callInfo result:(FlutterResult)result {
    [self _cancelRecord];
    result(@(YES));
}

- (void)playAmr:(NSDictionary *)callInfo result:(FlutterResult)result
{
    NSString *filePath = callInfo[@"path"];
    [self _startPlayerWithPath:filePath
                    completion:^(NSError *error)
     {
        result(@(error == nil));
    }];
}

- (void)stopPlayAmrFile:(NSDictionary *)callInfo result:(FlutterResult)result
{
    [self _stopPlayer];
    result(@(YES));
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _recordSetting = @{
            AVSampleRateKey:@(8000.0),
            AVFormatIDKey:@(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey:@(16),
            AVNumberOfChannelsKey:@(1),
            AVEncoderAudioQualityKey:@(AVAudioQualityHigh)
        };
    }
    
    return self;
}



- (void)dealloc
{
    [self _stopRecord];
}

- (void)_startRecordWithPath:(NSString *)aPath
                 completion:(void(^)(NSError *error))aCompletion
{
    NSError *error = nil;
    do {
        NSString *_wavPath = [[aPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"wav"];
        NSURL *wavUrl = [[NSURL alloc] initFileURLWithPath:_wavPath];
        self.recorder = [[AVAudioRecorder alloc] initWithURL:wavUrl settings:_recordSetting error:&error];
        if(error || !self.recorder) {
            self.recorder = nil;
            error = [NSError errorWithDomain:@"初始化录制失败" code:-1 userInfo:nil];
            break;
        }
        
        BOOL ret = [self.recorder prepareToRecord];
        if (ret) {
            _startDate = [NSDate date];
            self.recorder.meteringEnabled = YES;
            self.recorder.delegate = self;
            ret = [self.recorder record];
            _levelTimer = [NSTimer scheduledTimerWithTimeInterval: 0.3 target: self
                                                         selector: @selector(_levelTimerCallback:)
                                                         userInfo: nil
                                                          repeats: YES];
        }
        
        if (!ret) {
            [self _stopRecord];
            error = [NSError errorWithDomain:@"准备录制工作失败" code:-1 userInfo:nil];
        }
        
    } while (0);
    
    if (aCompletion) {
        aCompletion(error);
    }
}

#pragma mark - Private

- (void)_levelTimerCallback:(NSTimer *)timer {
    if (!_recorder) {
        return;
    }
    [_recorder updateMeters];
    
    float   level;                // The linear 0.0 .. 1.0 value we need.
    float   minDecibels = -60.0f; // use -80db Or use -60dB, which I measured in a silent room.
    float   decibels    = [_recorder averagePowerForChannel:0];
    
    if (decibels < minDecibels)
    {
        level = 0.0f;
    }
    else if (decibels >= 0.0f)
    {
        level = 1.0f;
    }
    else
    {
        float   root            = 5.0f; //modified level from 2.0 to 5.0 is neast to real test
        float   minAmp          = powf(10.0f, 0.05f * minDecibels);
        float   inverseAmpRange = 1.0f / (1.0f - minAmp);
        float   amp             = powf(10.0f, 0.05f * decibels);
        float   adjAmp          = (amp - minAmp) * inverseAmpRange;
        
        level = powf(adjAmp, 1.0f / root);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.channel invokeMethod:@"volume" arguments:@(level)];
    });
}

- (void)_stopRecord
{
    _recorder.delegate = nil;
    _path = nil;
    if (_recorder.recording) {
        [_recorder stop];
    }
    if (_levelTimer) {
        [_levelTimer invalidate];
    }
    _levelTimer = nil;
    _recorder = nil;
    _path = nil;
    _startDate = nil;
}


-(void)_stopRecordWithCompletion:(FlutterResult)aCompletion
{
    _endResult = aCompletion;
    [self.recorder stop];
}

-(void)_cancelRecord
{
    [self _stopRecord];
}

+ (int)_wavPath:(NSString *)aWavPath toAmrPath:(NSString*)aAmrPath
{
    if (EM_EncodeWAVEFileToAMRFile([aWavPath cStringUsingEncoding:NSASCIIStringEncoding], [aAmrPath cStringUsingEncoding:NSASCIIStringEncoding], 1, 16))
    {
        return 0;   // success
    }
    
    return 1;   // failed
}

- (BOOL)_convertWAV:(NSString *)aWavPath toAMR:(NSString *)aAmrPath
{
    BOOL ret = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:aAmrPath]) {
        ret = YES;
    } else if ([fileManager fileExistsAtPath:aWavPath]) {
        [RecordAmrPlugin _wavPath:aWavPath toAmrPath:aAmrPath];
        if ([fileManager fileExistsAtPath:aAmrPath]) {
            ret = YES;
        }
    }
    
    return ret;
}

- (void)_startPlayerWithPath:(NSString *)aPath
                  completion:(void(^)(NSError *error))aCompleton {
    NSError *error = nil;
    do {
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![aPath isKindOfClass:[NSString class]] || ![fm fileExistsAtPath:aPath]) {
            error = [NSError errorWithDomain:@"文件路径不存在" code:-1 userInfo:nil];
            break;
        }
        
        if (self.player && self.player.isPlaying && [self.playingPath isEqualToString:aPath]) {
            break;
        } else {
            if (_playingPath) {
                [self _stopPlayer];
            }
        }
        
        aPath = [self _convertAudioFile:aPath];
        if ([aPath length] == 0) {
            error = [NSError errorWithDomain:@"转换音频格式失败" code:-1 userInfo:nil];
            break;
        }
        
        NSURL *wavUrl = [[NSURL alloc] initFileURLWithPath:aPath];
        self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:wavUrl error:&error];
        if (error || !self.player) {
            self.player = nil;
            error = [NSError errorWithDomain:@"初始化AVAudioPlayer失败" code:-1 userInfo:nil];
            break;
        }
        
        self.playingPath = aPath;
        
        self.player.delegate = self;
        BOOL ret = [self.player prepareToPlay];
        if (ret) {
            AVAudioSession *audioSession = [AVAudioSession sharedInstance];
            [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
            if (error) {
                break;
            }
        }
        
        ret = [self.player play];
        if (!ret) {
            [self _stopPlayer];
            error = [NSError errorWithDomain:@"AVAudioPlayer播放失败" code:-1 userInfo:nil];
        }
        
    } while (0);
    
    if (error) {
        if (aCompleton) {
            aCompleton(error);
        }
    }
}

- (void)_stopPlayer
{
    [self.channel invokeMethod:@"stopPlaying" arguments:@{@"error": @(NO), @"path": _playingPath ?: @""}];
    if(_player) {
        _player.delegate = nil;
        [_player stop];
        _player = nil;
    }
    
    self.playingPath = nil;
}

+ (int)_isMP3File:(NSString *)aFilePath
{
    const char *filePath = [aFilePath cStringUsingEncoding:NSASCIIStringEncoding];
    return isMP3File(filePath);
}

+ (int)_amrToWav:(NSString*)aAmrPath wavSavePath:(NSString*)aWavPath
{
    
    if (EM_DecodeAMRFileToWAVEFile([aAmrPath cStringUsingEncoding:NSASCIIStringEncoding], [aWavPath cStringUsingEncoding:NSASCIIStringEncoding]))
        return 0; // success
    
    return 1;   // failed
}


- (NSString *)_convertAudioFile:(NSString *)aPath
{
    if ([[aPath pathExtension] isEqualToString:@"mp3"]) {
        return aPath;
    }
    
    NSString *retPath = [[aPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"wav"];
    do {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:retPath]) {
            break;
        }
        
        if ([RecordAmrPlugin _isMP3File:retPath]) {
            retPath = aPath;
            break;
        }
        
        [RecordAmrPlugin _amrToWav:aPath wavSavePath:retPath];
        if (![fileManager fileExistsAtPath:retPath]) {
            retPath = nil;
        }
        
    } while (0);
    
    return retPath;
}


#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder
                           successfully:(BOOL)flag
{
    NSInteger duration = [[NSDate date] timeIntervalSinceDate:_startDate];
    NSString *recordPath = [[self.recorder url] path];
    if (!flag) {
        recordPath = nil;
    }
    // Convert wav to amr
    NSString *amrFilePath = [[recordPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"amr"];
    BOOL ret = [self _convertWAV:recordPath toAMR:amrFilePath];
    if (ret) {
        // Remove the wav
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:recordPath error:nil];

        amrFilePath = amrFilePath;
    } else {
        recordPath = nil;
        duration = 0;
    }
    self.recorder = nil;
    if (_endResult) {
        _endResult(@{@"path":amrFilePath, @"duration":@(duration)});
    }
    _endResult = nil;
    [self _stopRecord];
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder
                                   error:(NSError *)error{
    [self _stopRecord];
    _endResult(@{@"path":@"", @"duration": @(0), @"error": error.domain});
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
                       successfully:(BOOL)flag
{
    if (_player) {
        [self.channel invokeMethod:@"stopPlaying" arguments:@{@"error": (@NO), @"path": _playingPath}];
        _player.delegate = nil;
        _player = nil;
        _playingPath = nil;
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                 error:(NSError *)error
{
    [self.channel invokeMethod:@"stopPlaying" arguments:@{@"error": @"decodeError", @"path": _playingPath}];
    if (_player) {
        _player.delegate = nil;
        _player = nil;
        _playingPath = nil;
    }
}

- (NSString *)path
{
    if (!_path) {
        _path =  [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        _path = [_path stringByAppendingPathComponent:@"EMRecord"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:_path]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_path withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return _path;
}

@end
