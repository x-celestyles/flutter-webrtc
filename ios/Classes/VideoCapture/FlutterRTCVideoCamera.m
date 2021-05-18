//
//  FlutterRTCVideoCamera.m
//  flutter_webrtc
//
//  Created by  on 2021/5/11.
//

#import "FlutterRTCVideoCamera.h"


@interface FlutterRTCVideoCamera ()<AVCaptureVideoDataOutputSampleBufferDelegate>


@property(nonatomic, strong) CALayer *previewLayer;
@property(nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
@property(nonatomic, weak) AVCaptureDevice *inputDevice;

/** position */
@property (nonatomic) AVCaptureDevicePosition currentPosition;

@end


@implementation FlutterRTCVideoCamera
- (instancetype)init {
    if (self = [super init]) {
        _currentPosition = AVCaptureDevicePositionFront;
        [self cameraChangePosition:_currentPosition];
    }
    return self;
}

- (AVCaptureSession *)session {
    if (!_session) {
        _session = [[AVCaptureSession alloc] init];
        _session.sessionPreset = AVCaptureSessionPresetMedium;
        if ([_session canSetSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
            [_session setSessionPreset:AVCaptureSessionPresetiFrame960x540];
        }

        AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
        dispatch_queue_t queue = dispatch_queue_create("video data queue", NULL);
        [output setSampleBufferDelegate:self queue:queue];
        output.videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey, nil];
        
        if ([_session canAddOutput:output]) {
            [_session addOutput:output];
        }
    }
    return _session;
}

- (void)startCaputre {
    [self.session startRunning];
}

- (void)stopCapture {
    [self.session stopRunning];
}

- (void)changeCameraPosition {
    if (_currentPosition == AVCaptureDevicePositionFront) {
        _currentPosition =  AVCaptureDevicePositionBack;
    } else {
        _currentPosition = AVCaptureDevicePositionFront;
    }
    [self cameraChangePosition:_currentPosition];
}

/// Camera reverse
/// @param position direction
- (void)cameraChangePosition:(AVCaptureDevicePosition)position {
    
    // Judging the direction
    AVCaptureDevice *inputDevice = nil;
    if (position == AVCaptureDevicePositionFront) {
        inputDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
    } else if (position == AVCaptureDevicePositionBack) {
        inputDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    }
    self.inputDevice = inputDevice;

    // Device input
    NSError *error = nil;
    AVCaptureDeviceInput *toChangeDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:&error];
    if (error) {
        NSLog(@"AVCaptureDeviceInput error %@", error);
        return;
    }

    [self.session beginConfiguration];
    // Set input
    [self.session removeInput:self.captureDeviceInput];
    if ([self.session canAddInput:toChangeDeviceInput]) {
        [self.session addInput:toChangeDeviceInput];
        self.captureDeviceInput = toChangeDeviceInput;
    }
    // Set direction
    AVCaptureConnection *videoConnect = [(AVCaptureVideoDataOutput *)self.session.outputs.firstObject connectionWithMediaType:AVMediaTypeVideo];
    if ([videoConnect isVideoOrientationSupported])
        [videoConnect setVideoOrientation:AVCaptureVideoOrientationPortrait];
    if (position == AVCaptureDevicePositionFront) {
        videoConnect.videoMirrored = NO;
    } else {
        videoConnect.videoMirrored = YES;
    }
    [self.session commitConfiguration];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (self.delegate && [self.delegate respondsToSelector:@selector(didOutPutSampleBuffer:)]) {
        [self.delegate didOutPutSampleBuffer:sampleBuffer];
    }
}
@end
