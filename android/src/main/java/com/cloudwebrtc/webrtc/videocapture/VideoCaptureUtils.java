package com.cloudwebrtc.webrtc.videocapture;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.RectF;
import android.renderscript.Allocation;
import android.renderscript.Element;
import android.renderscript.RenderScript;
import android.renderscript.ScriptIntrinsicBlur;
import android.util.Base64;
import android.util.Log;

import com.cloudwebrtc.webrtc.R;
import com.wpf.library.libyuv_android.YUVUtils;

import org.webrtc.JavaI420Buffer;
import org.webrtc.VideoFrame;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;

public class VideoCaptureUtils {

    public static Bitmap ConvertI420ToARGB(VideoFrame videoFrame){
        VideoFrame.I420Buffer i420Buffer = videoFrame.getBuffer().toI420();
        // Calculate the size of the frame
        int width = i420Buffer.getWidth();
        int height = i420Buffer.getHeight();
        // Calculate the size of the frame
        final int size = width * height;
        // Allocate an array to hold the ARGB pixel data
        final byte[] argbBytes = new byte[size * 4];
        int argbStride = width * 4;

        YUVUtils.instance().Convert_ARGB_I420ToARGB(
                byteBuffer2Byte(i420Buffer.getDataY()),
                i420Buffer.getStrideY(),
                byteBuffer2Byte(i420Buffer.getDataU()),
                i420Buffer.getStrideU(),
                byteBuffer2Byte(i420Buffer.getDataV()),
                i420Buffer.getStrideV(),
                argbBytes,
                argbStride,
                width,
                height
        );

//        Bitmap bitmap = Bitmap.createBitmap( width, height, Bitmap.Config.ARGB_8888 );
        Bitmap bitmap = Bitmap.createBitmap( width, height, Bitmap.Config.ARGB_8888 );
        ByteBuffer byteBuffer = ByteBuffer.wrap( argbBytes );
        bitmap.copyPixelsFromBuffer(byteBuffer);

        i420Buffer.release();
        byteBuffer.clear();

        int rotationDegree = videoFrame.getRotation();
        // If necessary, generate a rotated version of the Bitmap
        if ( rotationDegree == 90 || rotationDegree == -270 )
        {
            final Matrix m = new Matrix();
            m.postRotate( 90 );

            return Bitmap.createBitmap( bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), m, true );
        }
        else if ( rotationDegree == 180 || rotationDegree == -180 )
        {
            final Matrix m = new Matrix();
            m.postRotate( 180 );

            return Bitmap.createBitmap( bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), m, true );
        }
        else if ( rotationDegree == 270 || rotationDegree == -90 )
        {
            final Matrix m = new Matrix();
            m.postRotate( 270 );

            return Bitmap.createBitmap( bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), m, true );
        }
        else
        {
            // Don't rotate, just return the Bitmap
            return bitmap;
        }
    }

    //必须调用完后flip()才可以调用此方法
    public static byte[] byteBuffer2Byte(ByteBuffer byteBuffer){
        int len = byteBuffer.limit() - byteBuffer.position();
        byte[] bytes = new byte[len];

        if(byteBuffer.isReadOnly()){
            return null;
        }else {
            byteBuffer.get(bytes);
        }
        return bytes;
    }

    public static byte[] bitmapToRgba(Bitmap bitmap) {
        if (bitmap.getConfig() != Bitmap.Config.ARGB_8888)
            throw new IllegalArgumentException("Bitmap must be in ARGB_8888 format");
        int[] pixels = new int[bitmap.getWidth() * bitmap.getHeight()];
        byte[] bytes = new byte[pixels.length * 4];
        bitmap.getPixels(pixels, 0, bitmap.getWidth(), 0, 0, bitmap.getWidth(), bitmap.getHeight());
        int i = 0;
        for (int pixel : pixels) {
            // Get components assuming is ARGB
            int A = (pixel >> 24) & 0xff;
            int R = (pixel >> 16) & 0xff;
            int G = (pixel >> 8) & 0xff;
            int B = pixel & 0xff;
            bytes[i++] = (byte) R;
            bytes[i++] = (byte) G;
            bytes[i++] = (byte) B;
            bytes[i++] = (byte) A;

//            if(R != 0 || G != 0 || B != 0 || A != 0) {
//                Log.d("value==>", "sd");
//            }
        }
        return bytes;
    }

    public static VideoFrame.I420Buffer convertARGBToI420(Bitmap bitmap){
        int width = bitmap.getWidth();
        int height = bitmap.getHeight();
        int byteCount = bitmap.getByteCount();
//        ByteBuffer buf = ByteBuffer.allocate(byteCount);
//        bitmap.copyPixelsToBuffer(buf);
        byte[] byteArray = bitmapToRgba(bitmap);
        byte[] yBuffer = new byte[width * height];
        byte[] uBuffer = new byte[width * height / 4];
        byte[] vBuffer = new byte[width * height / 4];

        YUVUtils.instance().Convert_ARGBToI420(
                byteArray,
                width * 4,
                yBuffer,
                width,
                uBuffer,
                (width + 1) / 2,
                vBuffer,
                (width + 1) / 2,
                width,
                height
        );

        ByteBuffer dataY = (ByteBuffer)ByteBuffer.allocateDirect(yBuffer.length).put(yBuffer).position(0);
        ByteBuffer dataU = (ByteBuffer)ByteBuffer.allocateDirect(uBuffer.length).put(uBuffer).position(0);
        ByteBuffer dataV = (ByteBuffer)ByteBuffer.allocateDirect(vBuffer.length).put(vBuffer).position(0);

//        ByteBuffer dataY = ByteBuffer.wrap(yBuffer);
//        ByteBuffer dataU = ByteBuffer.wrap(uBuffer);
//        ByteBuffer dataV = ByteBuffer.wrap(vBuffer);
        if (dataY.isDirect() && dataU.isDirect() && dataV.isDirect()){
            JavaI420Buffer javaI420Buffer = JavaI420Buffer.wrap(
                    width,
                    height,
                    dataY,
                    /* strideY= */ width,
                    dataU,
                    /* strideU= */ width / 2,
                    dataV,
                    /* strideV= */ width / 2,
                    /* releaseCallback= */ null
            );
            return javaI420Buffer;
        }else {
            return null;
        }

    }

    public static VideoFrame.I420Buffer convertABGRToI420(Bitmap bitmap){
        int width = bitmap.getWidth();
        int height = bitmap.getHeight();
        int byteCount = bitmap.getByteCount();
//        ByteBuffer buf = ByteBuffer.allocate(byteCount);
//        bitmap.copyPixelsToBuffer(buf);
        byte[] byteArray = bitmapToRgba(bitmap);
        byte[] yBuffer = new byte[width * height];
        byte[] uBuffer = new byte[width * height / 4];
        byte[] vBuffer = new byte[width * height / 4];

        YUVUtils.instance().Convert_ARGBToI420(
                byteArray,
                width * 4,
                yBuffer,
                width,
                uBuffer,
                (width + 1) / 2,
                vBuffer,
                (width + 1) / 2,
                width,
                height
        );

        ByteBuffer dataY = (ByteBuffer)ByteBuffer.allocateDirect(yBuffer.length).put(yBuffer).position(0);
        ByteBuffer dataU = (ByteBuffer)ByteBuffer.allocateDirect(uBuffer.length).put(uBuffer).position(0);
        ByteBuffer dataV = (ByteBuffer)ByteBuffer.allocateDirect(vBuffer.length).put(vBuffer).position(0);

//        ByteBuffer dataY = ByteBuffer.wrap(yBuffer);
//        ByteBuffer dataU = ByteBuffer.wrap(uBuffer);
//        ByteBuffer dataV = ByteBuffer.wrap(vBuffer);
        if (dataY.isDirect() && dataU.isDirect() && dataV.isDirect()){
            return JavaI420Buffer.wrap(
                    width,
                    height,
                    dataY,
                    /* strideY= */ width,
                    dataU,
                    /* strideU= */ width / 2,
                    dataV,
                    /* strideV= */ width / 2,
                    /* releaseCallback= */ null
            );
        }else {
            return null;
        }

    }

//    public static Bitmap blendBitmap(Canvas canvas /*Bitmap background*/, Bitmap foreground){
////        int backgroundWidth = foreground.getWidth();
////        int backgroundHeight = foreground.getHeight();
////        Bitmap newMap = Bitmap.createBitmap(backgroundWidth, backgroundHeight, Bitmap.Config.ARGB_8888);
////        Canvas canvas = new Canvas(newMap);
////        canvas.drawBitmap(BitmapFactory.decodeResource(context.getResources(),id),0,0,null);
////        canvas.drawBitmap(foreground, 0, 0, null);
////        canvas.save();
////        canvas.restore();
////        return newMap;
//
////        int width = background.getWidth();
////        int height = background.getHeight();
////        int newWidth = foreground.getWidth();
////        int newHeight = foreground.getHeight();
////        float scaleWidth = ((float) newWidth) / width;
////        float scaleHeight = ((float) newHeight) / height;
////        Matrix matrix = new Matrix();
////        matrix.postScale(scaleWidth, scaleHeight);
////        Bitmap resizedBitmap = Bitmap.createBitmap(background, 0, 0, width,height, matrix, true);
////        Canvas canvas = new Canvas(resizedBitmap);
////        canvas.drawBitmap(foreground, 0, 0, null);
////        canvas.save();
////        canvas.restore();
////        return resizedBitmap;
////--------------------
////        int backgroundWidth = foreground.getWidth();
////        int backgroundHeight = foreground.getHeight();
////
////        Bitmap newMap = Bitmap.createBitmap(backgroundWidth, backgroundHeight, Bitmap.Config.ARGB_8888);
////        Canvas canvas = new Canvas(newMap);
////
////        canvas.drawBitmap(background, null, new RectF(0, 0, backgroundWidth, backgroundHeight), null);
//        canvas.drawBitmap(foreground, 0, 0, null);
//        canvas.save();
//        canvas.restore();
//        foreground.recycle();
//        return newMap;
//    }

    public static void blendBitmap(Canvas canvas , Bitmap foreground){
        canvas.drawBitmap(foreground, 0, 0, null);
        canvas.save();
        canvas.restore();
        foreground.recycle();
    }

    /**
     * 将bitmap转换成base64字符串
     * @param bitmap
     * @return base64 字符串
     */
    public static String bitmaptoString(Bitmap bitmap, int bitmapQuality) {

        // 将Bitmap转换成字符串
        String string = null;
        ByteArrayOutputStream bStream = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, bitmapQuality, bStream);
        byte[] bytes = bStream.toByteArray();
        string = Base64.encodeToString(bytes, Base64.DEFAULT);
        return string;

    }

    /**
     * 将base64转换成bitmap图片
     *
     * @param string base64字符串
     * @return bitmap
     */
    public static Bitmap stringtoBitmap(String string) {
        // 将字符串转换成Bitmap类型
        Bitmap bitmap = null;
        try {
            byte[] bitmapArray;
            bitmapArray = Base64.decode(string, Base64.DEFAULT);
            bitmap = BitmapFactory.decodeByteArray(bitmapArray, 0, bitmapArray.length);
            bitmap = mirrorBitmap(bitmap);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return bitmap;
    }

    public static Bitmap mirrorBitmap(Bitmap bitmap) {
        Matrix matrix = new Matrix();
        matrix.preScale(-1.0f, 1.0f);
        Bitmap newBitmap = Bitmap.createBitmap(bitmap, 0, 0,
                bitmap.getWidth(), bitmap.getHeight(), matrix, false);
        return newBitmap;
    }

    public static Bitmap createFlippedBitmap(Bitmap source, boolean xFlip, boolean yFlip) {
        Matrix matrix = new Matrix();
        matrix.postScale(xFlip ? -1 : 1, yFlip ? -1 : 1, source.getWidth() / 2f, source.getHeight() / 2f);
        return Bitmap.createBitmap(source, 0, 0, source.getWidth(), source.getHeight(), matrix, true);
    }
    
    
//    public static int getId(Context context, String bgImage) {
//        int id = R.drawable.virtual_back1;
//        switch (bgImage) {
//            case "virtual_back2.png":
//                id = R.drawable.virtual_back2;
//                break;
//            case "virtual_back3.png":
//                id = R.drawable.virtual_back3;
//                break;
//            case "virtual_back4.png":
//                id = R.drawable.virtual_back4;
//                break;
//            case "virtual_back5.png":
//                id = R.drawable.virtual_back5;
//                break;
//            case "virtual_back6.png":
//                id = R.drawable.virtual_back6;
//                break;
//            case "virtual_back7.png":
//                id = R.drawable.virtual_back7;
//                break;
//            case "virtual_back8.png":
//                id = R.drawable.virtual_back8;
//                break;
//            case "virtual_back9.png":
//                id = R.drawable.virtual_back9;
//                break;
//            case "virtual_back10.png":
//                id = R.drawable.virtual_back10;
//                break;
//            default:
//                id = R.drawable.virtual_back1;
//        }
//        return id;
//    }

    /**
     * Stack Blur v1.0 from
     * http://www.quasimondo.com/StackBlurForCanvas/StackBlurDemo.html
     * Java Author: Mario Klingemann <mario at quasimondo.com>
     * http://incubator.quasimondo.com
     *
     * created Feburary 29, 2004
     * Android port : Yahel Bouaziz <yahel at kayenko.com>
     * http://www.kayenko.com
     * ported april 5th, 2012
     *
     * This is a compromise between Gaussian Blur and Box blur
     * It creates much better looking blurs than Box Blur, but is
     * 7x faster than my Gaussian Blur implementation.
     *
     * I called it Stack Blur because this describes best how this
     * filter works internally: it creates a kind of moving stack
     * of colors whilst scanning through the image. Thereby it
     * just has to add one new block of color to the right side
     * of the stack and remove the leftmost color. The remaining
     * colors on the topmost layer of the stack are either added on
     * or reduced by one, depending on if they are on the right or
     * on the left side of the stack.
     *
     * If you are using this algorithm in your code please add
     * the following line:
     * Stack Blur Algorithm by Mario Klingemann <mario@quasimondo.com>
     */

    public static Bitmap fastblur(Bitmap sentBitmap, float scale, int radius) {

        int width = Math.round(sentBitmap.getWidth() * scale);
        int height = Math.round(sentBitmap.getHeight() * scale);
        sentBitmap = Bitmap.createScaledBitmap(sentBitmap, width, height, false);

        Bitmap bitmap = sentBitmap.copy(sentBitmap.getConfig(), true);

        if (radius < 1) {
            return (null);
        }

        int w = bitmap.getWidth();
        int h = bitmap.getHeight();

        int[] pix = new int[w * h];
        Log.e("pix", w + " " + h + " " + pix.length);
        bitmap.getPixels(pix, 0, w, 0, 0, w, h);

        int wm = w - 1;
        int hm = h - 1;
        int wh = w * h;
        int div = radius + radius + 1;

        int r[] = new int[wh];
        int g[] = new int[wh];
        int b[] = new int[wh];
        int rsum, gsum, bsum, x, y, i, p, yp, yi, yw;
        int vmin[] = new int[Math.max(w, h)];

        int divsum = (div + 1) >> 1;
        divsum *= divsum;
        int dv[] = new int[256 * divsum];
        for (i = 0; i < 256 * divsum; i++) {
            dv[i] = (i / divsum);
        }

        yw = yi = 0;

        int[][] stack = new int[div][3];
        int stackpointer;
        int stackstart;
        int[] sir;
        int rbs;
        int r1 = radius + 1;
        int routsum, goutsum, boutsum;
        int rinsum, ginsum, binsum;

        for (y = 0; y < h; y++) {
            rinsum = ginsum = binsum = routsum = goutsum = boutsum = rsum = gsum = bsum = 0;
            for (i = -radius; i <= radius; i++) {
                p = pix[yi + Math.min(wm, Math.max(i, 0))];
                sir = stack[i + radius];
                sir[0] = (p & 0xff0000) >> 16;
                sir[1] = (p & 0x00ff00) >> 8;
                sir[2] = (p & 0x0000ff);
                rbs = r1 - Math.abs(i);
                rsum += sir[0] * rbs;
                gsum += sir[1] * rbs;
                bsum += sir[2] * rbs;
                if (i > 0) {
                    rinsum += sir[0];
                    ginsum += sir[1];
                    binsum += sir[2];
                } else {
                    routsum += sir[0];
                    goutsum += sir[1];
                    boutsum += sir[2];
                }
            }
            stackpointer = radius;

            for (x = 0; x < w; x++) {

                r[yi] = dv[rsum];
                g[yi] = dv[gsum];
                b[yi] = dv[bsum];

                rsum -= routsum;
                gsum -= goutsum;
                bsum -= boutsum;

                stackstart = stackpointer - radius + div;
                sir = stack[stackstart % div];

                routsum -= sir[0];
                goutsum -= sir[1];
                boutsum -= sir[2];

                if (y == 0) {
                    vmin[x] = Math.min(x + radius + 1, wm);
                }
                p = pix[yw + vmin[x]];

                sir[0] = (p & 0xff0000) >> 16;
                sir[1] = (p & 0x00ff00) >> 8;
                sir[2] = (p & 0x0000ff);

                rinsum += sir[0];
                ginsum += sir[1];
                binsum += sir[2];

                rsum += rinsum;
                gsum += ginsum;
                bsum += binsum;

                stackpointer = (stackpointer + 1) % div;
                sir = stack[(stackpointer) % div];

                routsum += sir[0];
                goutsum += sir[1];
                boutsum += sir[2];

                rinsum -= sir[0];
                ginsum -= sir[1];
                binsum -= sir[2];

                yi++;
            }
            yw += w;
        }
        for (x = 0; x < w; x++) {
            rinsum = ginsum = binsum = routsum = goutsum = boutsum = rsum = gsum = bsum = 0;
            yp = -radius * w;
            for (i = -radius; i <= radius; i++) {
                yi = Math.max(0, yp) + x;

                sir = stack[i + radius];

                sir[0] = r[yi];
                sir[1] = g[yi];
                sir[2] = b[yi];

                rbs = r1 - Math.abs(i);

                rsum += r[yi] * rbs;
                gsum += g[yi] * rbs;
                bsum += b[yi] * rbs;

                if (i > 0) {
                    rinsum += sir[0];
                    ginsum += sir[1];
                    binsum += sir[2];
                } else {
                    routsum += sir[0];
                    goutsum += sir[1];
                    boutsum += sir[2];
                }

                if (i < hm) {
                    yp += w;
                }
            }
            yi = x;
            stackpointer = radius;
            for (y = 0; y < h; y++) {
                // Preserve alpha channel: ( 0xff000000 & pix[yi] )
                pix[yi] = ( 0xff000000 & pix[yi] ) | ( dv[rsum] << 16 ) | ( dv[gsum] << 8 ) | dv[bsum];

                rsum -= routsum;
                gsum -= goutsum;
                bsum -= boutsum;

                stackstart = stackpointer - radius + div;
                sir = stack[stackstart % div];

                routsum -= sir[0];
                goutsum -= sir[1];
                boutsum -= sir[2];

                if (x == 0) {
                    vmin[y] = Math.min(y + r1, hm) * w;
                }
                p = x + vmin[y];

                sir[0] = r[p];
                sir[1] = g[p];
                sir[2] = b[p];

                rinsum += sir[0];
                ginsum += sir[1];
                binsum += sir[2];

                rsum += rinsum;
                gsum += ginsum;
                bsum += binsum;

                stackpointer = (stackpointer + 1) % div;
                sir = stack[stackpointer];

                routsum += sir[0];
                goutsum += sir[1];
                boutsum += sir[2];

                rinsum -= sir[0];
                ginsum -= sir[1];
                binsum -= sir[2];

                yi += w;
            }
        }

        Log.e("pix", w + " " + h + " " + pix.length);
        bitmap.setPixels(pix, 0, w, 0, 0, w, h);

        return (bitmap);
    }

    public static RectF getRectF(Bitmap bitmap, Bitmap bgBitmap){
        float ratio = (float)bitmap.getHeight() / bitmap.getWidth();
        float bgRatio = (float)bgBitmap.getHeight() / bgBitmap.getWidth();
        RectF rectF;
        if(bgRatio > ratio){
            float index = 1.0f;
            if(bgBitmap.getWidth() < bitmap.getWidth()){
                index = (float)bitmap.getWidth() / bgBitmap.getWidth();
            }else {
                index = (float)bgBitmap.getWidth() / bitmap.getWidth();
            }

            rectF = new RectF(0, 0, bgBitmap.getWidth() * index, bgBitmap.getHeight()  * index);
        }else if(bgRatio == ratio){
            rectF = new RectF(0, 0, bgBitmap.getWidth(), bgBitmap.getHeight());
        }else {
            float index = 1.0f;
            if(bgBitmap.getHeight() < bitmap.getHeight()){
                index = (float)bitmap.getHeight() / bgBitmap.getHeight();
            }else {
                index = (float)bgBitmap.getHeight() / bitmap.getHeight();
            }
            float side = (bgBitmap.getWidth() - bgBitmap.getHeight()) / 2;
            rectF = new RectF(0, 0, bgBitmap.getWidth()  * index, bgBitmap.getHeight() * index);
        }
        return rectF;
    }
}
