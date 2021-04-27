//
//  GPUImageBeautifyFilter.h
//  flutter_webrtc
//
//  Created by  on 2021/4/27.
//

#import <GPUImage/GPUImage.h>

NS_ASSUME_NONNULL_BEGIN

@class GPUImageCombinationFilter;

@interface GPUImageBeautifyFilter : GPUImageFilterGroup
{
    GPUImageBilateralFilter *bilateralFilter;
    GPUImageBrightnessFilter* brightnessFilter;
    
    GPUImageCannyEdgeDetectionFilter *cannyEdgeFilter;
    GPUImageCombinationFilter *combinationFilter;
    GPUImageHSBFilter *hsbFilter;
}
@end

NS_ASSUME_NONNULL_END
