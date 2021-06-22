//
//  FlutterGPUImageCapture.m
//  flutter_webrtc
//
//  Created by  on 2021/4/27.
//

#import "FlutterGPUImageCapture.h"
#include <mach/mach_time.h>
#import "FlutterScreenCapture.h"
#import <MLImageSegmentationLibrary/MLImageSegmentationLibrary.h>

#import "FlutterGPUImagePicture.h"
#import "UIImage+PixBuffer.h"


typedef enum : NSUInteger {
    None,//没有
    GaussianBlur,//高斯模糊
    BackGround,//背景图
} FlutterGPUImageCaptureBackType;

@interface FlutterGPUImageCapture ()<FlutterRTCVideoCameraDelegate>{
    
    double _tiem_pre;
}

//背景墙
@property(nonatomic, strong) MLImageSegmentationAnalyzer *imgSegAnalyzer;
/** imageName */
@property (nonatomic, strong) UIImage *currentImage;
/** 背景模式 */
@property (nonatomic) FlutterGPUImageCaptureBackType backType;
@end

@implementation FlutterGPUImageCapture

{
    mach_timebase_info_data_t _timebaseInfo;
    int64_t _startTimeStampNs;
}


- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate {
    self = [super initWithDelegate:delegate];
    if (self) {
        mach_timebase_info(&_timebaseInfo);
        _bilateral = 8;
        _brightness = 0.1;
        
        [self initMLSegment];
    }
    return self;
}

- (void)initMLSegment {
    
    self.imgSegAnalyzer = [MLImageSegmentationAnalyzer sharedInstance];
    MLImageSegmentationSetting *setting = [[MLImageSegmentationSetting alloc] init];
    [setting setAnalyzerType:MLImageSegmentationAnalyzerTypeBody];
    [setting setScene:MLImageSegmentationSceneForegroundOnly];
    [setting setExact:NO];
    [self.imgSegAnalyzer setImageSegmentationAnalyzer:setting];
    _currentImage = [UIImage imageNamed:@"virtual_back1.png"];
    _backType = None;
}

- (FlutterRTCVideoCamera *)videoCamera {
    if (!_videoCamera) {
        _videoCamera = [[FlutterRTCVideoCamera alloc] init];
        _videoCamera.delegate = self;
    }
    return _videoCamera;
}

- (void)changeBackGroundImage:(NSString *)imgName {
    if ([imgName isEqualToString:@"blur"]) {
        _backType = GaussianBlur;
    } else {
        _backType = BackGround;
        NSData *data = [[NSData alloc] initWithBase64EncodedString:imgName options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:data];
        if (image) {
            _currentImage = image;
//            UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
        }
    }
    
}

- (void)closeVirtualBackGround {
    _backType = None;
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSLog(@"图片保存完毕");
}

- (void)didOutPutSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (_backType == BackGround || _backType == GaussianBlur) {
        //开启了虚拟背景的使用
        //在这里添加背景墙
        HW_TIME_BEGIN(total);
        
        UIImage *image = [UIImage convertPixBufferToImage:CMSampleBufferGetImageBuffer(sampleBuffer)];
        UIImage *originalImage = [UIImage imageWithCGImage:[image CGImage]];
        
        MLFrame *frame = [[MLFrame alloc] initWithImage:image];
        MLImageSegmentation *imgSeg = [self.imgSegAnalyzer analyseFrame:frame];
        UIImage *foregroundImage = [imgSeg getForeground];
        
        if (_backType == GaussianBlur) {
            //如果当前是高斯模糊模式
            if(originalImage){
                //将原图高斯化
                
                GPUImageGaussianBlurFilter *gaussianBlurFilter = [[GPUImageGaussianBlurFilter alloc] init];
                    gaussianBlurFilter.blurRadiusInPixels = 50;//模糊程度
                    [gaussianBlurFilter forceProcessingAtSize:CGSizeMake(720, 1280)];
                    [gaussianBlurFilter useNextFrameForImageCapture];
                    //获取数据源
                    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc]initWithImage:originalImage];
                    //添加上滤镜
                    [stillImageSource addTarget:gaussianBlurFilter];
                    //开始渲染
                    [stillImageSource processImage];
                    //获取渲染后的图片
                    UIImage *newImage = [gaussianBlurFilter imageFromCurrentFramebuffer];
                _currentImage = newImage;
            }
        }
        
        //背景图
        if (foregroundImage && _currentImage) {
            FlutterGPUImagePicture *input = [[FlutterGPUImagePicture alloc] initWithImage:foregroundImage outPutSize:CGSizeMake(720, 1280)];

            FlutterGPUImagePicture *input1 = [[FlutterGPUImagePicture alloc] initWithImage:_currentImage outPutSize:CGSizeMake(720, 1280)];
            //混合前后两张图片
            GPUImageAlphaBlendFilter *filter = [[GPUImageAlphaBlendFilter alloc] init];
            filter.mix = 1.0;
            //先混合背景图片
            [input1 addTarget:filter];
            [input1 processImage];

            [filter useNextFrameForImageCapture];
            //再混合前景图片
            [input addTarget:filter];
            [input processImage];
            //获取混合的图片
           foregroundImage = filter.imageFromCurrentFramebuffer;

           //添加美颜效果
            foregroundImage = [self beauteImage:foregroundImage];
        }
        
        HW_TIME_END(total);
        
        CVPixelBufferRef convertBuffer = [UIImage convertImageToPixBuffer:foregroundImage];
        if (totalt1.tv_sec - self->_tiem_pre > 1) {
            self->_tiem_pre = totalt1.tv_sec;
        }
        [self handlePixbuffer:convertBuffer];
    } else {
        //没有使用虚拟背景
        UIImage *image = [UIImage convertPixBufferToImage:CMSampleBufferGetImageBuffer(sampleBuffer)];
        if (image) {
            
            image = [self beauteImage:image];
            if (image) {
                CVPixelBufferRef convertBuffer = [UIImage convertImageToPixBuffer:image];
                [self handlePixbuffer:convertBuffer];
            }
        }
    }
}

//将图片磨皮
- (UIImage *)beauteImage:(UIImage *)originImage {
    
    GPUImagePicture *input = [[GPUImagePicture alloc] initWithImage:originImage];
    
    //设置磨皮,值越大磨皮效果越好，最大10
    GPUImageBilateralFilter *bilateralFilter = [[GPUImageBilateralFilter alloc] init];
    bilateralFilter.distanceNormalizationFactor = 8;
    [bilateralFilter forceProcessingAtSize:originImage.size];
    [bilateralFilter useNextFrameForImageCapture];
    
    [input addTarget:bilateralFilter];
    [input processImage];
    
    return bilateralFilter.imageFromCurrentFramebuffer;
}

- (void)startCapture {
    _startTimeStampNs = -1;
    [self.videoCamera startCaputre];
 
}

- (void)stopCapture {
    [self.videoCamera stopCapture];
}


- (void)handlePixbuffer:(CVPixelBufferRef)convertBuffer {
        
    RTCCVPixelBuffer * rtcPixelBuffer = nil;
    CGFloat originalWidth = (CGFloat)CVPixelBufferGetWidth(convertBuffer);
    CGFloat originalHeight = (CGFloat)CVPixelBufferGetHeight(convertBuffer);
    if (originalWidth > kScrMaximumSupportedResolution || originalHeight > kScrMaximumSupportedResolution) {
        rtcPixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer: convertBuffer];
        int width = originalWidth * kScrMaximumSupportedResolution / originalHeight;
        int height = kScrMaximumSupportedResolution;
        if (originalWidth > originalHeight) {
            width = kScrMaximumSupportedResolution;
            height = originalHeight * kScrMaximumSupportedResolution / originalWidth;
        }
        CVPixelBufferRef outputPixelBuffer = nil;
        OSType pixelFormat = CVPixelBufferGetPixelFormatType(convertBuffer);
        CVPixelBufferRelease(convertBuffer);
        
        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width,
                                              height, pixelFormat, nil,
                                              &outputPixelBuffer);
        if (status!=kCVReturnSuccess) {
            return;
        }
        int tmpBufferSize = [rtcPixelBuffer bufferSizeForCroppingAndScalingToWidth:width height:height];
        uint8_t* tmpBuffer = malloc(tmpBufferSize);
        if ([rtcPixelBuffer cropAndScaleTo:outputPixelBuffer withTempBuffer:tmpBuffer]) {
            rtcPixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer: outputPixelBuffer];
        } else {
            CVPixelBufferRelease(outputPixelBuffer);
            free(tmpBuffer);
            return;
        }
        CVPixelBufferRelease(outputPixelBuffer);
        free(tmpBuffer);
    }
    int64_t currentTime = mach_absolute_time();
    int64_t currentTimeStampNs = currentTime * _timebaseInfo.numer / _timebaseInfo.denom;
    int64_t frameTimeStampNs = currentTimeStampNs - _startTimeStampNs;
    RTCVideoFrame *videoFrame = [[RTCVideoFrame alloc] initWithBuffer:rtcPixelBuffer
                                                             rotation:RTCVideoRotation_0
                                                          timeStampNs:frameTimeStampNs];
    [self.delegate capturer:self didCaptureVideoFrame:videoFrame];
}

@end
