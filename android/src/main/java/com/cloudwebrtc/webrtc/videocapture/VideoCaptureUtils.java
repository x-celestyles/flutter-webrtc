package com.cloudwebrtc.webrtc.videocapture;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.RectF;
import android.util.Log;

import com.cloudwebrtc.webrtc.R;
import com.wpf.library.libyuv_android.YUVUtils;

import org.webrtc.JavaI420Buffer;
import org.webrtc.VideoFrame;

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
    
    
    public static int getId(Context context, String bgImage) {
        int id = R.drawable.virtual_back1;
        switch (bgImage) {
            case "virtual_back2.png":
                id = R.drawable.virtual_back2;
                break;
            case "virtual_back3.png":
                id = R.drawable.virtual_back3;
                break;
            case "virtual_back4.png":
                id = R.drawable.virtual_back4;
                break;
            case "virtual_back5.png":
                id = R.drawable.virtual_back5;
                break;
            case "virtual_back6.png":
                id = R.drawable.virtual_back6;
                break;
            case "virtual_back7.png":
                id = R.drawable.virtual_back7;
                break;
            case "virtual_back8.png":
                id = R.drawable.virtual_back8;
                break;
            case "virtual_back9.png":
                id = R.drawable.virtual_back9;
                break;
            case "virtual_back10.png":
                id = R.drawable.virtual_back10;
                break;
            default:
                id = R.drawable.virtual_back1;
        }
        return id;
    }
}
