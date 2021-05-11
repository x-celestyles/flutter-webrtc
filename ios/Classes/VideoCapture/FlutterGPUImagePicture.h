//
//  FlutterGPUImagePicture.h
//  flutter_webrtc
//
//  Created by  on 2021/5/11.
//

#import "GPUImageOutput.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FlutterGPUImagePicture : GPUImageOutput
{
    CGSize pixelSizeOfImage;
    BOOL hasProcessedImage;
    
    dispatch_semaphore_t imageUpdateSemaphore;
}

/// 指定输出具体尺寸的图片
/// @param newImageSource 原图片
/// @param outPutSize 指定输出的大小
- (id)initWithImage:(UIImage *)newImageSource outPutSize:(CGSize)outPutSize;

// Image rendering
- (void)processImage;
- (CGSize)outputImageSize;

/**
 * Process image with all targets and filters asynchronously
 * The completion handler is called after processing finished in the
 * GPU's dispatch queue - and only if this method did not return NO.
 *
 * @returns NO if resource is blocked and processing is discarded, YES otherwise
 */
- (BOOL)processImageWithCompletionHandler:(void (^)(void))completion;
- (void)processImageUpToFilter:(GPUImageOutput<GPUImageInput> *)finalFilterInChain withCompletionHandler:(void (^)(UIImage *processedImage))block;
@end

NS_ASSUME_NONNULL_END
