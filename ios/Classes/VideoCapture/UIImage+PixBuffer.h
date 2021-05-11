//
//  UIImage+PixBuffer.h
//  flutter_webrtc
//
//  Created by  on 2021/5/11.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (PixBuffer)
+ (CVPixelBufferRef)convertImageToPixBuffer:(UIImage *)image;

+ (UIImage *)convertPixBufferToImage:(CVPixelBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
