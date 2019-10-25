//
//  ViewController.m
//  BBVoiceRecordDemo
//
//  Created by 谢国碧 on 2016/12/10.
//
//

#import "ViewController.h"
#import "BBVoiceRecordController.h"
#import "UIColor+BBVoiceRecord.h"
#import "BBHoldToSpeakButton.h"
#import "LVRecordTool.h"

#define kFakeTimerDuration       0.1
#define kMaxRecordDuration       30     //最长录音时长
#define kRemainCountingDuration  10     //剩余多少秒开始倒计时

@interface ViewController () <LVRecordToolDelegate>

@property (nonatomic, strong) BBVoiceRecordController *voiceRecordCtrl;
@property (nonatomic, weak) IBOutlet BBHoldToSpeakButton *btnRecord;
@property (nonatomic, assign) BBVoiceRecordState currentRecordState;
@property (nonatomic, strong) NSTimer *fakeTimer;
@property (nonatomic, assign) float duration;
@property (weak, nonatomic) IBOutlet UIButton *playBtn;

/// 录音工具
@property (nonatomic, strong) LVRecordTool *recordTool;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _btnRecord.layer.borderWidth = 0.5;
    _btnRecord.layer.borderColor = [UIColor colorWithHex:0xA3A5AB].CGColor;
    _btnRecord.layer.cornerRadius = 4;
    _btnRecord.layer.masksToBounds = YES;
    _btnRecord.enabled = NO;    //将事件往上传递
    _btnRecord.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_btnRecord setTitleColor:[UIColor colorWithHex:0x565656] forState:UIControlStateNormal];
    [_btnRecord setTitleColor:[UIColor colorWithHex:0x565656] forState:UIControlStateHighlighted];
    [_btnRecord setTitle:@"Hold to talk" forState:UIControlStateNormal];
    
    _playBtn.layer.borderWidth = 0.5;
    _playBtn.layer.borderColor = [UIColor colorWithHex:0xA3A5AB].CGColor;
    _playBtn.layer.cornerRadius = 4;
    _playBtn.layer.masksToBounds = YES;
    _playBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_playBtn setTitleColor:[UIColor colorWithHex:0x565656] forState:UIControlStateNormal];
    [_playBtn setTitleColor:[UIColor colorWithHex:0x565656] forState:UIControlStateHighlighted];
    [_playBtn setTitle:@"Play Record Voice" forState:UIControlStateNormal];
    
}

- (void)startFakeTimer
{
    self.duration = 0;
    if (_fakeTimer) {
        [_fakeTimer invalidate];
        _fakeTimer = nil;
    }
    self.fakeTimer = [NSTimer scheduledTimerWithTimeInterval:kFakeTimerDuration target:self selector:@selector(onFakeTimerTimeOut) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.fakeTimer forMode:NSRunLoopCommonModes];
    [_fakeTimer fire];
    
    [self.recordTool startRecording];
}

- (void)stopFakeTimer
{
    if (_fakeTimer) {
        [_fakeTimer invalidate];
        _fakeTimer = nil;
    }
    [self.recordTool stopRecording];
}

- (void)onFakeTimerTimeOut
{
    self.duration += kFakeTimerDuration;
//    NSLog(@"+++duration+++ %f",self.duration);
    float remainTime = kMaxRecordDuration-self.duration;
    if (fabsf(remainTime) < kFakeTimerDuration) {
        self.currentRecordState = BBVoiceRecordState_Ended;
        [self dispatchVoiceState];
        [self tryUploadRecordedVoice];
    } else if ([self shouldShowCounting]) {
        self.currentRecordState = BBVoiceRecordState_RecordCounting;
        [self dispatchVoiceState];
        [self.voiceRecordCtrl showRecordCounting:remainTime];
    }
    else
    {
//        float fakePower = (float)(1+arc4random()%99)/100;
//        [self.voiceRecordCtrl updatePower:fakePower];
    }
}

- (IBAction)playBtnClicked:(UIButton *)sender {
    if ([self.recordTool isPlaying]) {
        [self.recordTool stopPlaying];
    } else {
        [self.recordTool playRecordingFile];
    }
}

- (BOOL)shouldShowCounting
{
    if (self.duration >= (kMaxRecordDuration-kRemainCountingDuration) && self.duration < kMaxRecordDuration && self.currentRecordState != BBVoiceRecordState_ReleaseToCancel) {
        return YES;
    }
    return NO;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    CGPoint touchPoint = [[touches anyObject] locationInView:self.view];
    if (CGRectContainsPoint(_btnRecord.frame, touchPoint)) {
        self.currentRecordState = BBVoiceRecordState_PrepareToRecord;
        [self dispatchVoiceState];
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.currentRecordState == BBVoiceRecordState_Ended) {
        return;
    }
    CGPoint touchPoint = [[touches anyObject] locationInView:self.view];
    if (CGRectContainsPoint(_btnRecord.frame, touchPoint)) {
        if ([self shouldShowCounting]) {
            self.currentRecordState = BBVoiceRecordState_RecordCounting;
            [self.voiceRecordCtrl showRecordCounting:kMaxRecordDuration-self.duration];
        } else {
            self.currentRecordState = BBVoiceRecordState_Recording;
        }
    }
    else
    {
        self.currentRecordState = BBVoiceRecordState_ReleaseToCancel;
    }
    [self dispatchVoiceState];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.currentRecordState == BBVoiceRecordState_Ended) {
        return;
    }
    CGPoint touchPoint = [[touches anyObject] locationInView:self.view];
    if (CGRectContainsPoint(_btnRecord.frame, touchPoint)) {
        [self tryUploadRecordedVoice];
    } else {
        [self.recordTool destructionRecordingFile];
    }
    self.currentRecordState = BBVoiceRecordState_Ended;
    [self dispatchVoiceState];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.currentRecordState == BBVoiceRecordState_Ended) {
        return;
    }
    CGPoint touchPoint = [[touches anyObject] locationInView:self.view];
    if (CGRectContainsPoint(_btnRecord.frame, touchPoint)) {
        [self tryUploadRecordedVoice];
    } else {
        [self.recordTool destructionRecordingFile];
    }
    self.currentRecordState = BBVoiceRecordState_Ended;
    [self dispatchVoiceState];
}

- (void)dispatchVoiceState
{
    switch (_currentRecordState) {
        case BBVoiceRecordState_PrepareToRecord:
            [self startFakeTimer];
            break;
        case BBVoiceRecordState_Ended:
            [self stopFakeTimer];
        default:
            break;
    }
    [_btnRecord updateRecordButtonStyle:_currentRecordState];
    [self.voiceRecordCtrl updateUIWithRecordState:_currentRecordState];
}

- (void)tryUploadRecordedVoice {
    if (self.duration < 3) {
        [self.voiceRecordCtrl showToast:@"Message Too Short."];
        [self.recordTool destructionRecordingFile];
    }
    else
    {
        //upload voice
        NSLog(@"====upload voice duration:%f", self.duration);
        [self.voiceRecordCtrl showToast:[NSString stringWithFormat:@"Send Voice %.2fs", self.duration]];
    }
}

- (BBVoiceRecordController *)voiceRecordCtrl
{
    if (_voiceRecordCtrl == nil) {
        _voiceRecordCtrl = [BBVoiceRecordController new];
    }
    return _voiceRecordCtrl;
}

- (LVRecordTool *)recordTool {
    if (!_recordTool) {
        _recordTool = [LVRecordTool sharedRecordTool];
        _recordTool.delegate = self;
    }
    return _recordTool;
}

#pragma mark - LVRecordToolDelegate
- (void)recordTool:(LVRecordTool *)recordTool didstartRecoring:(int)no {
    [self.voiceRecordCtrl updatePower:no/7.0];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
