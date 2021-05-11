//
//  UIImage+PixBuffer.m
//  flutter_webrtc
//
//  Created by  on 2021/5/11.
//

#import "UIImage+PixBuffer.h"

@implementation UIImage (PixBuffer)

+ (UIImage *)convertPixBufferToImage:(CVPixelBufferRef)sampleBuffer {

//    CVImageBufferRef sampleBuffer;
//    sampleBuffer = CMSampleBufferGetImageBuffer(buffer);

    CVPixelBufferLockBaseAddress(sampleBuffer, 0);
    uint8_t *base;
    size_t width, height, bytesPerRow;
    base = (uint8_t *)CVPixelBufferGetBaseAddress(sampleBuffer);
    width = CVPixelBufferGetWidth(sampleBuffer);
    height = CVPixelBufferGetHeight(sampleBuffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(sampleBuffer);

    CGColorSpaceRef colorSpace;
    CGContextRef cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(base, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);

    CGImageRef cgImage;
    UIImage *image;
    cgImage = CGBitmapContextCreateImage(cgContext);
    image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);

    CVPixelBufferUnlockBaseAddress(sampleBuffer, 0);

    return image;
}


+ (CVPixelBufferRef)convertImageToPixBuffer:(UIImage *)image {

    CGImageRef imageRef = [image CGImage];
    NSDictionary *options = @{
                                  (NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
                                  (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
                                  (NSString*)kCVPixelBufferIOSurfacePropertiesKey: [NSDictionary dictionary]
                                  };
        CVPixelBufferRef pxbuffer = NULL;

        CGFloat frameWidth = CGImageGetWidth(imageRef);
        CGFloat frameHeight = CGImageGetHeight(imageRef);

        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                              frameWidth,
                                              frameHeight,
                                              kCVPixelFormatType_32BGRA,
                                              (__bridge CFDictionaryRef) options,
                                              &pxbuffer);

        NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

        CVPixelBufferLockBaseAddress(pxbuffer, 0);
        void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
        NSParameterAssert(pxdata != NULL);

        CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();

        CGContextRef context = CGBitmapContextCreate(pxdata,
                                                     frameWidth,
                                                     frameHeight,
                                                     8,
                                                     CVPixelBufferGetBytesPerRow(pxbuffer),
                                                     rgbColorSpace,
                                                     kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        NSParameterAssert(context);
        CGContextConcatCTM(context, CGAffineTransformIdentity);
        CGContextDrawImage(context, CGRectMake(0,
                                               0,
                                               frameWidth,
                                               frameHeight),
                           imageRef);
        CGColorSpaceRelease(rgbColorSpace);
        CGContextRelease(context);

        CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
        return pxbuffer;
}

@end
