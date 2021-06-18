package com.cloudwebrtc.webrtc;

import android.Manifest;
import android.app.Activity;
import android.app.Fragment;
import android.app.FragmentTransaction;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.PorterDuff;
import android.graphics.RectF;
import android.hardware.Camera;
import android.hardware.Camera.Parameters;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.media.projection.MediaProjection;
import android.media.projection.MediaProjectionManager;
import android.os.Build;
import android.os.Build.VERSION;
import android.os.Build.VERSION_CODES;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.ResultReceiver;
import android.provider.MediaStore;
import android.util.Log;
import android.util.Range;
import android.util.SparseArray;
import android.util.TypedValue;
import android.view.Surface;
import android.view.WindowManager;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;

import com.cloudwebrtc.webrtc.record.AudioChannel;
import com.cloudwebrtc.webrtc.record.AudioSamplesInterceptor;
import com.cloudwebrtc.webrtc.record.MediaRecorderImpl;
import com.cloudwebrtc.webrtc.record.OutputAudioSamplesInterceptor;
import com.cloudwebrtc.webrtc.utils.Callback;
import com.cloudwebrtc.webrtc.utils.ConstraintsArray;
import com.cloudwebrtc.webrtc.utils.ConstraintsMap;
import com.cloudwebrtc.webrtc.utils.EglUtils;
import com.cloudwebrtc.webrtc.utils.MediaConstraintsUtils;
import com.cloudwebrtc.webrtc.utils.ObjectType;
import com.cloudwebrtc.webrtc.utils.PermissionUtils;
import com.cloudwebrtc.webrtc.videocapture.GPUImageBeautyFilter;
import com.cloudwebrtc.webrtc.videocapture.ImageSegmentAnalyzerTransactor;
import com.cloudwebrtc.webrtc.videocapture.VideoCaptureUtils;
import com.huawei.hmf.tasks.OnFailureListener;
import com.huawei.hmf.tasks.OnSuccessListener;
import com.huawei.hmf.tasks.Task;
import com.huawei.hms.mlsdk.MLAnalyzerFactory;
import com.huawei.hms.mlsdk.common.MLFrame;
import com.huawei.hms.mlsdk.imgseg.MLImageSegmentation;
import com.huawei.hms.mlsdk.imgseg.MLImageSegmentationAnalyzer;
import com.huawei.hms.mlsdk.imgseg.MLImageSegmentationScene;
import com.huawei.hms.mlsdk.imgseg.MLImageSegmentationSetting;

import org.webrtc.AudioSource;
import org.webrtc.AudioTrack;
import org.webrtc.Camera1Capturer;
import org.webrtc.Camera1Enumerator;
import org.webrtc.Camera2Capturer;
import org.webrtc.Camera2Enumerator;
import org.webrtc.CameraEnumerationAndroid.CaptureFormat;
import org.webrtc.CameraEnumerator;
import org.webrtc.CameraVideoCapturer;
import org.webrtc.Logging;
import org.webrtc.MediaConstraints;
import org.webrtc.MediaStream;
import org.webrtc.MediaStreamTrack;
import org.webrtc.PeerConnectionFactory;
import org.webrtc.ScreenCapturerAndroid;
import org.webrtc.SurfaceTextureHelper;
import org.webrtc.VideoCapturer;
import org.webrtc.VideoFrame;
import org.webrtc.VideoFrameHandler;
import org.webrtc.VideoSource;
import org.webrtc.VideoTrack;
import org.webrtc.audio.JavaAudioDeviceModule;

import java.io.File;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodChannel.Result;
import jp.co.cyberagent.android.gpuimage.GPUImage;
import jp.co.cyberagent.android.gpuimage.filter.GPUImageNormalBlendFilter;
//import jp.co.cyberagent.android.gpuimage.GPUImageAddBlendFilter;
//import jp.co.cyberagent.android.gpuimage.GPUImageNormalBlendFilter;
//import jp.co.cyberagent.android.gpuimage.GPUImageView;

/**
 * The implementation of {@code getUserMedia} extracted into a separate file in order to reduce
 * complexity and to (somewhat) separate concerns.
 */
class GetUserMediaImpl {

    private static final int DEFAULT_WIDTH = 1280;
    private static final int DEFAULT_HEIGHT = 720;
    private static final int DEFAULT_FPS = 30;

    private static final String PERMISSION_AUDIO = Manifest.permission.RECORD_AUDIO;
    private static final String PERMISSION_VIDEO = Manifest.permission.CAMERA;
    private static final String PERMISSION_SCREEN = "android.permission.MediaProjection";
    private static int CAPTURE_PERMISSION_REQUEST_CODE = 1;
    private static final String GRANT_RESULTS = "GRANT_RESULT";
    private static final String PERMISSIONS = "PERMISSION";
    private static final String PROJECTION_DATA = "PROJECTION_DATA";
    private static final String RESULT_RECEIVER = "RESULT_RECEIVER";
    private static final String REQUEST_CODE = "REQUEST_CODE";

    static final String TAG = FlutterWebRTCPlugin.TAG;

    private final Map<String, VideoCapturer> mVideoCapturers = new HashMap<>();

    private final StateProvider stateProvider;
    private final Context applicationContext;

    static final int minAPILevel = Build.VERSION_CODES.LOLLIPOP;
    private MediaProjectionManager mProjectionManager = null;
    private static MediaProjection sMediaProjection = null;

    final AudioSamplesInterceptor inputSamplesInterceptor = new AudioSamplesInterceptor();
    private OutputAudioSamplesInterceptor outputSamplesInterceptor = null;
    JavaAudioDeviceModule audioDeviceModule;
    private final SparseArray<MediaRecorderImpl> mediaRecorders = new SparseArray<>();

    private GPUImage gpuImage;

    public void screenRequestPremissions(ResultReceiver resultReceiver) {
        final Activity activity = stateProvider.getActivity();
        if (activity == null) {
            // Activity went away, nothing we can do.
            return;
        }

        Bundle args = new Bundle();
        args.putParcelable(RESULT_RECEIVER, resultReceiver);
        args.putInt(REQUEST_CODE, CAPTURE_PERMISSION_REQUEST_CODE);

        ScreenRequestPermissionsFragment fragment = new ScreenRequestPermissionsFragment();
        fragment.setArguments(args);

        FragmentTransaction transaction =
                activity
                        .getFragmentManager()
                        .beginTransaction()
                        .add(fragment, fragment.getClass().getName());

        try {
            transaction.commit();
        } catch (IllegalStateException ise) {

        }
    }

    public static class ScreenRequestPermissionsFragment extends Fragment {

        private ResultReceiver resultReceiver = null;
        private int requestCode = 0;
        private int resultCode = 0;

        private void checkSelfPermissions(boolean requestPermissions) {
            if (resultCode != Activity.RESULT_OK) {
                Activity activity = this.getActivity();
                Bundle args = getArguments();
                resultReceiver = args.getParcelable(RESULT_RECEIVER);
                requestCode = args.getInt(REQUEST_CODE);
                requestStart(activity, requestCode);
            }
        }

        public void requestStart(Activity activity, int requestCode) {
            if (android.os.Build.VERSION.SDK_INT < minAPILevel) {
                Log.w(
                        TAG,
                        "Can't run requestStart() due to a low API level. API level 21 or higher is required.");
                return;
            } else {
                MediaProjectionManager mediaProjectionManager =
                        (MediaProjectionManager) activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE);

                // call for the projection manager
                this.startActivityForResult(
                        mediaProjectionManager.createScreenCaptureIntent(), requestCode);
            }
        }

        @Override
        public void onActivityResult(int requestCode, int resultCode, Intent data) {
            super.onActivityResult(requestCode, resultCode, data);
            resultCode = resultCode;
            String[] permissions;
            if (resultCode != Activity.RESULT_OK) {
                finish();
                Bundle resultData = new Bundle();
                resultData.putString(PERMISSIONS, PERMISSION_SCREEN);
                resultData.putInt(GRANT_RESULTS, resultCode);
                resultReceiver.send(requestCode, resultData);
                return;
            }
            Bundle resultData = new Bundle();
            resultData.putString(PERMISSIONS, PERMISSION_SCREEN);
            resultData.putInt(GRANT_RESULTS, resultCode);
            resultData.putParcelable(PROJECTION_DATA, data);
            resultReceiver.send(requestCode, resultData);
            finish();
        }

        private void finish() {
            Activity activity = getActivity();
            if (activity != null) {
                activity.getFragmentManager().beginTransaction().remove(this).commitAllowingStateLoss();
            }
        }

        @Override
        public void onResume() {
            super.onResume();
            checkSelfPermissions(/* requestPermissions */ true);
        }
    }

    GetUserMediaImpl(StateProvider stateProvider, Context applicationContext) {
        this.stateProvider = stateProvider;
        this.applicationContext = applicationContext;
    }

    static private void resultError(String method, String error, Result result) {
        String errorMsg = method + "(): " + error;
        result.error(method, errorMsg,null);
        Log.d(TAG, errorMsg);
    }

    /**
     * Includes default constraints set for the audio media type.
     *
     * @param audioConstraints <tt>MediaConstraints</tt> instance to be filled with the default
     *                         constraints for audio media type.
     */
    private void addDefaultAudioConstraints(MediaConstraints audioConstraints) {
        audioConstraints.optional.add(
                new MediaConstraints.KeyValuePair("googNoiseSuppression", "true"));
        audioConstraints.optional.add(
                new MediaConstraints.KeyValuePair("googEchoCancellation", "true"));
        audioConstraints.optional.add(new MediaConstraints.KeyValuePair("echoCancellation", "true"));
        audioConstraints.optional.add(
                new MediaConstraints.KeyValuePair("googEchoCancellation2", "true"));
        audioConstraints.optional.add(
                new MediaConstraints.KeyValuePair("googDAEchoCancellation", "true"));
    }

    /**
     * Create video capturer via given facing mode
     *
     * @param enumerator a <tt>CameraEnumerator</tt> provided by webrtc it can be Camera1Enumerator or
     *                   Camera2Enumerator
     * @param isFacing   'user' mapped with 'front' is true (default) 'environment' mapped with 'back'
     *                   is false
     * @param sourceId   (String) use this sourceId and ignore facing mode if specified.
     * @return VideoCapturer can invoke with <tt>startCapture</tt>/<tt>stopCapture</tt> <tt>null</tt>
     * if not matched camera with specified facing mode.
     */
    private VideoCapturer createVideoCapturer(
            CameraEnumerator enumerator, boolean isFacing, String sourceId) {
        VideoCapturer videoCapturer = null;

        // if sourceId given, use specified sourceId first
        final String[] deviceNames = enumerator.getDeviceNames();
        if (sourceId != null) {
            for (String name : deviceNames) {
                if (name.equals(sourceId)) {
                    videoCapturer = enumerator.createCapturer(name, new CameraEventsHandler());
                    if (videoCapturer != null) {
                        Log.d(TAG, "create user specified camera " + name + " succeeded");
                        return videoCapturer;
                    } else {
                        Log.d(TAG, "create user specified camera " + name + " failed");
                        break; // fallback to facing mode
                    }
                }
            }
        }

        // otherwise, use facing mode
        String facingStr = isFacing ? "front" : "back";
        for (String name : deviceNames) {
            if (enumerator.isFrontFacing(name) == isFacing) {
                videoCapturer = enumerator.createCapturer(name, new CameraEventsHandler());
                if (videoCapturer != null) {
                    Log.d(TAG, "Create " + facingStr + " camera " + name + " succeeded");
                    return videoCapturer;
                } else {
                    Log.e(TAG, "Create " + facingStr + " camera " + name + " failed");
                }
            }
        }
        // should we fallback to available camera automatically?
        return videoCapturer;
    }

    /**
     * Retrieves "facingMode" constraint value.
     *
     * @param mediaConstraints a <tt>ConstraintsMap</tt> which represents "GUM" constraints argument.
     * @return String value of "facingMode" constraints in "GUM" or <tt>null</tt> if not specified.
     */
    private String getFacingMode(ConstraintsMap mediaConstraints) {
        return mediaConstraints == null ? null : mediaConstraints.getString("facingMode");
    }

    /**
     * Retrieves "sourceId" constraint value.
     *
     * @param mediaConstraints a <tt>ConstraintsMap</tt> which represents "GUM" constraints argument
     * @return String value of "sourceId" optional "GUM" constraint or <tt>null</tt> if not specified.
     */
    private String getSourceIdConstraint(ConstraintsMap mediaConstraints) {
        if (mediaConstraints != null
                && mediaConstraints.hasKey("optional")
                && mediaConstraints.getType("optional") == ObjectType.Array) {
            ConstraintsArray optional = mediaConstraints.getArray("optional");

            for (int i = 0, size = optional.size(); i < size; i++) {
                if (optional.getType(i) == ObjectType.Map) {
                    ConstraintsMap option = optional.getMap(i);

                    if (option.hasKey("sourceId") && option.getType("sourceId") == ObjectType.String) {
                        return option.getString("sourceId");
                    }
                }
            }
        }

        return null;
    }

    private AudioTrack getUserAudio(ConstraintsMap constraints) {
        MediaConstraints audioConstraints;
        if (constraints.getType("audio") == ObjectType.Boolean) {
            audioConstraints = new MediaConstraints();
            addDefaultAudioConstraints(audioConstraints);
        } else {
            audioConstraints = MediaConstraintsUtils.parseMediaConstraints(constraints.getMap("audio"));
        }

        Log.i(TAG, "getUserMedia(audio): " + audioConstraints);

        String trackId = stateProvider.getNextTrackUUID();
        PeerConnectionFactory pcFactory = stateProvider.getPeerConnectionFactory();
        AudioSource audioSource = pcFactory.createAudioSource(audioConstraints);

        return pcFactory.createAudioTrack(trackId, audioSource);
    }

    /**
     * Implements {@code getUserMedia} without knowledge whether the necessary permissions have
     * already been granted. If the necessary permissions have not been granted yet, they will be
     * requested.
     */
    void getUserMedia(
            final ConstraintsMap constraints, final Result result, final MediaStream mediaStream) {

        // TODO: change getUserMedia constraints format to support new syntax
        //   constraint format seems changed, and there is no mandatory any more.
        //   and has a new syntax/attrs to specify resolution
        //   should change `parseConstraints()` according
        //   see: https://www.w3.org/TR/mediacapture-streams/#idl-def-MediaTrackConstraints

        ConstraintsMap videoConstraintsMap = null;
        ConstraintsMap videoConstraintsMandatory = null;

        if (constraints.getType("video") == ObjectType.Map) {
            videoConstraintsMap = constraints.getMap("video");
            if (videoConstraintsMap.hasKey("mandatory")
                    && videoConstraintsMap.getType("mandatory") == ObjectType.Map) {
                videoConstraintsMandatory = videoConstraintsMap.getMap("mandatory");
            }
        }

        final ArrayList<String> requestPermissions = new ArrayList<>();

        if (constraints.hasKey("audio")) {
            switch (constraints.getType("audio")) {
                case Boolean:
                    if (constraints.getBoolean("audio")) {
                        requestPermissions.add(PERMISSION_AUDIO);
                    }
                    break;
                case Map:
                    requestPermissions.add(PERMISSION_AUDIO);
                    break;
                default:
                    break;
            }
        }

        if (constraints.hasKey("video")) {
            switch (constraints.getType("video")) {
                case Boolean:
                    if (constraints.getBoolean("video")) {
                        requestPermissions.add(PERMISSION_VIDEO);
                    }
                    break;
                case Map:
                    requestPermissions.add(PERMISSION_VIDEO);
                    break;
                default:
                    break;
            }
        }

        // According to step 2 of the getUserMedia() algorithm,
        // requestedMediaTypes is the set of media types in constraints with
        // either a dictionary value or a value of "true".
        // According to step 3 of the getUserMedia() algorithm, if
        // requestedMediaTypes is the empty set, the method invocation fails
        // with a TypeError.
        if (requestPermissions.isEmpty()) {
            resultError("getUserMedia", "TypeError, constraints requests no media types", result);
            return;
        }

        /// Only systems pre-M, no additional permission request is needed.
        if (VERSION.SDK_INT < VERSION_CODES.M) {
            getUserMedia(constraints, result, mediaStream, requestPermissions);
            return;
        }

        requestPermissions(
                requestPermissions,
                /* successCallback */ new Callback() {
                    @Override
                    public void invoke(Object... args) {
                        List<String> grantedPermissions = (List<String>) args[0];

                        getUserMedia(constraints, result, mediaStream, grantedPermissions);
                    }
                },
                /* errorCallback */ new Callback() {
                    @Override
                    public void invoke(Object... args) {
                        // According to step 10 Permission Failure of the
                        // getUserMedia() algorithm, if the user has denied
                        // permission, fail "with a new DOMException object whose
                        // name attribute has the value NotAllowedError."
                        resultError("getUserMedia", "DOMException, NotAllowedError", result);
                    }
                });
    }

    void getDisplayMedia(
            final ConstraintsMap constraints, final Result result, final MediaStream mediaStream) {
        ConstraintsMap videoConstraintsMap = null;
        ConstraintsMap videoConstraintsMandatory = null;

        if (constraints.getType("video") == ObjectType.Map) {
            videoConstraintsMap = constraints.getMap("video");
            if (videoConstraintsMap.hasKey("mandatory")
                    && videoConstraintsMap.getType("mandatory") == ObjectType.Map) {
                videoConstraintsMandatory = videoConstraintsMap.getMap("mandatory");
            }
        }

        final ConstraintsMap videoConstraintsMandatory2 = videoConstraintsMandatory;

        screenRequestPremissions(
                new ResultReceiver(new Handler(Looper.getMainLooper())) {
                    @Override
                    protected void onReceiveResult(int requestCode, Bundle resultData) {

                        /* Create ScreenCapture */
                        int resultCode = resultData.getInt(GRANT_RESULTS);
                        Intent mediaProjectionData = resultData.getParcelable(PROJECTION_DATA);

                        if (resultCode != Activity.RESULT_OK) {
                            resultError("screenRequestPremissions", "User didn't give permission to capture the screen.", result);
                            return;
                        }

                        MediaStreamTrack[] tracks = new MediaStreamTrack[1];
                        VideoCapturer videoCapturer = null;
                        videoCapturer =
                                new ScreenCapturerAndroid(
                                        mediaProjectionData,
                                        new MediaProjection.Callback() {
                                            @Override
                                            public void onStop() {
                                                resultError("MediaProjection.Callback()", "User revoked permission to capture the screen.", result);
                                            }
                                        });
                        if (videoCapturer == null) {
                            resultError("screenRequestPremissions", "GetDisplayMediaFailed, User revoked permission to capture the screen.", result);
                            return;
                        }

                        PeerConnectionFactory pcFactory = stateProvider.getPeerConnectionFactory();
                        VideoSource videoSource = pcFactory.createVideoSource(true);


                        String threadName = Thread.currentThread().getName();
                        SurfaceTextureHelper surfaceTextureHelper =
                                SurfaceTextureHelper.create(threadName, EglUtils.getRootEglBaseContext());
                        videoCapturer.initialize(
                                surfaceTextureHelper, applicationContext, videoSource.getCapturerObserver());

                        WindowManager wm =
                                (WindowManager) applicationContext.getSystemService(Context.WINDOW_SERVICE);

                        int width = wm.getDefaultDisplay().getWidth();
                        int height = wm.getDefaultDisplay().getHeight();
                        int fps = DEFAULT_FPS;

                        videoCapturer.startCapture(width, height, fps);
                        Log.d(TAG, "ScreenCapturerAndroid.startCapture: " + width + "x" + height + "@" + fps);

                        String trackId = stateProvider.getNextTrackUUID();
                        mVideoCapturers.put(trackId, videoCapturer);

                        tracks[0] = pcFactory.createVideoTrack(trackId, videoSource);

                        ConstraintsArray audioTracks = new ConstraintsArray();
                        ConstraintsArray videoTracks = new ConstraintsArray();
                        ConstraintsMap successResult = new ConstraintsMap();

                        for (MediaStreamTrack track : tracks) {
                            if (track == null) {
                                continue;
                            }

                            String id = track.id();

                            if (track instanceof AudioTrack) {
                                mediaStream.addTrack((AudioTrack) track);
                            } else {
                                mediaStream.addTrack((VideoTrack) track);
                            }
                            stateProvider.getLocalTracks().put(id, track);

                            ConstraintsMap track_ = new ConstraintsMap();
                            String kind = track.kind();

                            track_.putBoolean("enabled", track.enabled());
                            track_.putString("id", id);
                            track_.putString("kind", kind);
                            track_.putString("label", kind);
                            track_.putString("readyState", track.state().toString());
                            track_.putBoolean("remote", false);

                            if (track instanceof AudioTrack) {
                                audioTracks.pushMap(track_);
                            } else {
                                videoTracks.pushMap(track_);
                            }
                        }

                        String streamId = mediaStream.getId();

                        Log.d(TAG, "MediaStream id: " + streamId);
                        stateProvider.getLocalStreams().put(streamId, mediaStream);
                        successResult.putString("streamId", streamId);
                        successResult.putArray("audioTracks", audioTracks.toArrayList());
                        successResult.putArray("videoTracks", videoTracks.toArrayList());
                        result.success(successResult.toMap());
                    }
                });
    }

    /**
     * Implements {@code getUserMedia} with the knowledge that the necessary permissions have already
     * been granted. If the necessary permissions have not been granted yet, they will NOT be
     * requested.
     */
    private void getUserMedia(
            ConstraintsMap constraints,
            Result result,
            MediaStream mediaStream,
            List<String> grantedPermissions) {
        MediaStreamTrack[] tracks = new MediaStreamTrack[2];

        // If we fail to create either, destroy the other one and fail.
        if ((grantedPermissions.contains(PERMISSION_AUDIO)
                && (tracks[0] = getUserAudio(constraints)) == null)
                || (grantedPermissions.contains(PERMISSION_VIDEO)
                && (tracks[1] = getUserVideo(constraints)) == null)) {
            for (MediaStreamTrack track : tracks) {
                if (track != null) {
                    track.dispose();
                }
            }

            // XXX The following does not follow the getUserMedia() algorithm
            // specified by
            // https://www.w3.org/TR/mediacapture-streams/#dom-mediadevices-getusermedia
            // with respect to distinguishing the various causes of failure.
            resultError("getUserMedia", "Failed to create new track.", result);
            return;
        }

        ConstraintsArray audioTracks = new ConstraintsArray();
        ConstraintsArray videoTracks = new ConstraintsArray();
        ConstraintsMap successResult = new ConstraintsMap();

        for (MediaStreamTrack track : tracks) {
            if (track == null) {
                continue;
            }

            String id = track.id();

            if (track instanceof AudioTrack) {
                mediaStream.addTrack((AudioTrack) track);
            } else {
                mediaStream.addTrack((VideoTrack) track);
            }
            stateProvider.getLocalTracks().put(id, track);

            ConstraintsMap track_ = new ConstraintsMap();
            String kind = track.kind();

            track_.putBoolean("enabled", track.enabled());
            track_.putString("id", id);
            track_.putString("kind", kind);
            track_.putString("label", kind);
            track_.putString("readyState", track.state().toString());
            track_.putBoolean("remote", false);

            if (track instanceof AudioTrack) {
                audioTracks.pushMap(track_);
            } else {
                videoTracks.pushMap(track_);
            }
        }

        String streamId = mediaStream.getId();

        Log.d(TAG, "MediaStream id: " + streamId);
        stateProvider.getLocalStreams().put(streamId, mediaStream);

        successResult.putString("streamId", streamId);
        successResult.putArray("audioTracks", audioTracks.toArrayList());
        successResult.putArray("videoTracks", videoTracks.toArrayList());
        result.success(successResult.toMap());
    }

    private boolean isFacing=true;

    private int i = 1;
//    private GPUImageBeautyFilter gPUImageBeautyFilter = new GPUImageBeautyFilter();

    private MLImageSegmentationAnalyzer analyzer;

    private Canvas canvas;

    private volatile Bitmap bgBitmap;

    private Bitmap newBitmap;

    private boolean virtualBgOpen = false;

    private boolean virtualBgBlur = false;

    private boolean refreshBgRectF = true;

    private RectF bgRectF;

    private Bitmap getResourceBitmap(int resId) {
        BitmapFactory.Options options = new BitmapFactory.Options();
        TypedValue value = new TypedValue();
        applicationContext.getResources().openRawResource(resId, value);
        options.inTargetDensity = value.density;
        options.inScaled = false;//不缩放
        return BitmapFactory.decodeResource(applicationContext.getResources(), resId, options);
    }

    private MLImageSegmentationAnalyzer getAnalyzer() {
        if(this.analyzer == null ){
            // 方式二：使用自定义参数MLImageSegmentationSetting配置图像分割检测器。
            MLImageSegmentationSetting setting = new MLImageSegmentationSetting.Factory()
                    .setExact(false)
                    .setAnalyzerType(MLImageSegmentationSetting.BODY_SEG)
                    .setScene(MLImageSegmentationScene.ALL)
                    .create();
            GetUserMediaImpl.this.analyzer = MLAnalyzerFactory.getInstance().getImageSegmentationAnalyzer(setting);
        }
        return analyzer;
    }


    private Canvas getCanvas(int width, int height) {
        if(canvas == null){
            newBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
            canvas = new Canvas(newBitmap);
            // this.getBgBitmap();
        }
        canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR);
        return canvas;
    }

    public void destroy(){
        if(this.analyzer != null ){
            this.analyzer.destroy();
        }
        if(this.bgBitmap != null){
            this.bgBitmap.recycle();
        }
        if(this.newBitmap != null){
            this.newBitmap.recycle();
        }
    }

    public void setBgBitmap(String bgImage){
        if(bgImage == null || "".equals(bgImage)){
            virtualBgOpen = false;
            this.virtualBgBlur = false;
            if(canvas != null){
                canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR);
            }
            /*if(bgBitmap != null){
                bgBitmap.recycle();
            }
            this.bgBitmap = null;*/
            return;
        }else if(bgImage.equals("blur")){
            this.virtualBgOpen = true;
            this.virtualBgBlur = true;
            this.refreshBgRectF = true;
        }else {

            String a = VideoCaptureUtils.bitmaptoString(this.getResourceBitmap(R.drawable.virtual_back1), 90);
            Log.d("====>", a);
            // this.bgBitmap = this.getResourceBitmap(VideoCaptureUtils.getId(applicationContext, bgImage));
            this.bgBitmap = VideoCaptureUtils.stringtoBitmap(bgImage);
            this.virtualBgOpen = true;
            this.virtualBgBlur = false;
            this.refreshBgRectF = true;
        }


    }

    private VideoTrack getUserVideo(ConstraintsMap constraints) {
        ConstraintsMap videoConstraintsMap = null;
        ConstraintsMap videoConstraintsMandatory = null;
        if (constraints.getType("video") == ObjectType.Map) {
            videoConstraintsMap = constraints.getMap("video");
            if (videoConstraintsMap.hasKey("mandatory")
                    && videoConstraintsMap.getType("mandatory") == ObjectType.Map) {
                videoConstraintsMandatory = videoConstraintsMap.getMap("mandatory");
            }
        }

        Log.i(TAG, "getUserMedia(video): " + videoConstraintsMap);

        // NOTE: to support Camera2, the device should:
        //   1. Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP
        //   2. all camera support level should greater than LEGACY
        //   see:
        // https://developer.android.com/reference/android/hardware/camera2/CameraCharacteristics.html#INFO_SUPPORTED_HARDWARE_LEVEL
        // TODO Enable camera2 enumerator
        CameraEnumerator cameraEnumerator;

        if (Camera2Enumerator.isSupported(applicationContext)) {
            Log.d(TAG, "Creating video capturer using Camera2 API.");
            cameraEnumerator = new Camera2Enumerator(applicationContext);
        } else {
            Log.d(TAG, "Creating video capturer using Camera1 API.");
            cameraEnumerator = new Camera1Enumerator(false);
        }

        String facingMode = getFacingMode(videoConstraintsMap);
        isFacing = facingMode == null || !facingMode.equals("environment");
        String sourceId = getSourceIdConstraint(videoConstraintsMap);

        VideoCapturer videoCapturer = createVideoCapturer(cameraEnumerator, isFacing, sourceId);

        if (videoCapturer == null) {
            return null;
        }

        PeerConnectionFactory pcFactory = stateProvider.getPeerConnectionFactory();
        VideoSource videoSource = pcFactory.createVideoSource(false);

        /*if(GetUserMediaImpl.this.bgBitmap == null) {
            GetUserMediaImpl.this.bgBitmap = this.getResourceBitmap(R.drawable.virtual_back4);
        }*/

        if(videoSource.getVideoFrameHandler() == null){
            videoSource.setVideoFrameHandler(new VideoFrameHandler() {
                @Override
                public VideoFrame handle(VideoFrame videoFrame) {
                    if (GetUserMediaImpl.this.virtualBgOpen && GetUserMediaImpl.this.bgBitmap != null) {
                        Bitmap bitmap = VideoCaptureUtils.ConvertI420ToARGB(videoFrame);
                        Canvas canvas = GetUserMediaImpl.this.getCanvas(bitmap.getWidth(), bitmap.getHeight());

                        if(virtualBgBlur) {
                            Bitmap blurBitmap = VideoCaptureUtils.fastblur(bitmap, 1.0f,10);
                            if(GetUserMediaImpl.this.refreshBgRectF){
                                GetUserMediaImpl.this.bgRectF = new RectF(0, 0, blurBitmap.getWidth(), blurBitmap.getHeight());
                                GetUserMediaImpl.this.refreshBgRectF = false;
                            }
                            canvas.drawBitmap(blurBitmap, null, GetUserMediaImpl.this.bgRectF, null);
                        }else {
                            if(GetUserMediaImpl.this.refreshBgRectF){
                                GetUserMediaImpl.this.bgRectF = VideoCaptureUtils.getRectF(bitmap, bgBitmap);
                                GetUserMediaImpl.this.refreshBgRectF = false;
                            }
                            canvas.drawBitmap(bgBitmap, null, GetUserMediaImpl.this.bgRectF, null);
                        }

                        // 通过bitmap创建MLFrame，bitmap为输入的Bitmap格式图片数据。
                        GetUserMediaImpl.this.getAnalyzer();
                        MLFrame mlFrame = new MLFrame.Creator().setBitmap(bitmap).create();
                        SparseArray<MLImageSegmentation> segmentations = analyzer.analyseFrame(mlFrame);
                        MLImageSegmentation segmentation = segmentations.get(0);
                        bitmap = segmentation.getForeground();

                        VideoCaptureUtils.blendBitmap(canvas, bitmap);
                        VideoFrame.I420Buffer i420Buffer = VideoCaptureUtils.convertARGBToI420(newBitmap);
                        if (i420Buffer != null) {
                            bitmap.recycle();
                            return new VideoFrame(i420Buffer, 0, videoFrame.getTimestampNs());
                        }
                    }
                    return videoFrame;
/*
                    Bitmap bitmap = VideoCaptureUtils.ConvertI420ToARGB(videoFrame);
//                    Bitmap bitmap1 = BitmapFactory.decodeResource(applicationContext.getResources(), R.drawable.classification_image);
//                    Bitmap bitmap2 = BitmapFactory.decodeResource(applicationContext.getResources(), R.drawable.imgseg_foreground);
//                    Bitmap bitmap = BitmapFactory.decodeResource(applicationContext.getResources(), R.drawable.su);
                    if(bitmap == null || bitmap.getHeight() < 1){
                        return videoFrame;
                    }
//                    String name = String.valueOf(i++);
//                    MediaStore.Images.Media.insertImage(applicationContext.getContentResolver(), bitmap, name, name);

                    // 通过bitmap创建MLFrame，bitmap为输入的Bitmap格式图片数据。
                    MLFrame mlFrame = new MLFrame.Creator().setBitmap(bitmap).create();
                    SparseArray<MLImageSegmentation> segmentations = analyzer.analyseFrame(mlFrame);
                    MLImageSegmentation segmentation = segmentations.get(0);
                    bitmap = segmentation.getForeground();

//                    if(GetUserMediaImpl.this.gpuImage == null){
//                        GetUserMediaImpl.this.gpuImage = new GPUImage(applicationContext);
//                    }
//
//                    gpuImage.setImage(bitmap1);
//////                  gpuImage.setFilter(GetUserMediaImpl.this.gPUImageBeautyFilter);
//                    GPUImageNormalBlendFilter gpuImageNormalBlendFilter = new GPUImageNormalBlendFilter();
//                    gpuImageNormalBlendFilter.setBitmap(bitmap2);
//                    gpuImage.setFilter(gpuImageNormalBlendFilter);


//                    Bitmap bitmap3 = gpuImage.getBitmapWithFilterApplied();
//                    Bitmap.Config config = bitmap3.getConfig();
//                    Bitmap.Config config = bitmap3.getConfig();/

//                    bitmap = VideoCaptureUtils.blendBitmap(bitmap1, bitmap);

                    VideoCaptureUtils.blendBitmap(getCanvas(bitmap.getWidth(), bitmap.getHeight()), bitmap);
                    VideoFrame.I420Buffer i420Buffer = VideoCaptureUtils.convertARGBToI420(newBitmap);

//                    VideoFrame.I420Buffer i420Buffer = VideoCaptureUtils.convertARGBToI420(bitmap);
                    if(i420Buffer != null){
//                        bitmap.recycle();
                        long timestampNs = videoFrame.getTimestampNs();
                        int rotation = 0;
                        return new VideoFrame(i420Buffer, rotation, timestampNs);
                    }
                    return videoFrame;
//                    return videoFrame;
*/
                }
            });
        }
        String threadName = Thread.currentThread().getName();
        SurfaceTextureHelper surfaceTextureHelper =
                SurfaceTextureHelper.create(threadName, EglUtils.getRootEglBaseContext());
        videoCapturer.initialize(
                surfaceTextureHelper, applicationContext, videoSource.getCapturerObserver());

        // Fall back to defaults if keys are missing.
        int width =
                videoConstraintsMandatory != null && videoConstraintsMandatory.hasKey("minWidth")
                        ? videoConstraintsMandatory.getInt("minWidth")
                        : DEFAULT_WIDTH;
        int height =
                videoConstraintsMandatory != null && videoConstraintsMandatory.hasKey("minHeight")
                        ? videoConstraintsMandatory.getInt("minHeight")
                        : DEFAULT_HEIGHT;
        int fps =
                videoConstraintsMandatory != null && videoConstraintsMandatory.hasKey("minFrameRate")
                        ? videoConstraintsMandatory.getInt("minFrameRate")
                        : DEFAULT_FPS;

        videoCapturer.startCapture(width, height, fps);

        String trackId = stateProvider.getNextTrackUUID();
        mVideoCapturers.put(trackId, videoCapturer);

        Log.d(TAG, "changeCaptureFormat: " + width + "x" + height + "@" + fps);
        videoSource.adaptOutputFormat(width, height, fps);

        return pcFactory.createVideoTrack(trackId, videoSource);
    }

    void removeVideoCapturer(String id) {
        VideoCapturer videoCapturer = mVideoCapturers.get(id);
        if (videoCapturer != null) {
            try {
                videoCapturer.stopCapture();
            } catch (InterruptedException e) {
                Log.e(TAG, "removeVideoCapturer() Failed to stop video capturer");
            } finally {
                videoCapturer.dispose();
                mVideoCapturers.remove(id);
            }
        }
    }

    @RequiresApi(api = VERSION_CODES.M)
    private void requestPermissions(
            final ArrayList<String> permissions,
            final Callback successCallback,
            final Callback errorCallback) {
        PermissionUtils.Callback callback =
                (permissions_, grantResults) -> {
                    List<String> grantedPermissions = new ArrayList<>();
                    List<String> deniedPermissions = new ArrayList<>();

                    for (int i = 0; i < permissions_.length; ++i) {
                        String permission = permissions_[i];
                        int grantResult = grantResults[i];

                        if (grantResult == PackageManager.PERMISSION_GRANTED) {
                            grantedPermissions.add(permission);
                        } else {
                            deniedPermissions.add(permission);
                        }
                    }

                    // Success means that all requested permissions were granted.
                    for (String p : permissions) {
                        if (!grantedPermissions.contains(p)) {
                            // According to step 6 of the getUserMedia() algorithm
                            // "if the result is denied, jump to the step Permission
                            // Failure."
                            errorCallback.invoke(deniedPermissions);
                            return;
                        }
                    }
                    successCallback.invoke(grantedPermissions);
                };

        final Activity activity = stateProvider.getActivity();
        if (activity != null) {
            PermissionUtils.requestPermissions(
                    activity, permissions.toArray(new String[permissions.size()]), callback);
        }
    }

    void switchCamera(String id, Result result) {
        VideoCapturer videoCapturer = mVideoCapturers.get(id);
        if (videoCapturer == null) {
            resultError("switchCamera", "Video capturer not found for id: " + id, result);
            return;
        }

        CameraEnumerator cameraEnumerator;

        if (Camera2Enumerator.isSupported(applicationContext)) {
            Log.d(TAG, "Creating video capturer using Camera2 API.");
            cameraEnumerator = new Camera2Enumerator(applicationContext);
        } else {
            Log.d(TAG, "Creating video capturer using Camera1 API.");
            cameraEnumerator = new Camera1Enumerator(false);
        }
        // if sourceId given, use specified sourceId first
        final String[] deviceNames = cameraEnumerator.getDeviceNames();
        for (String name : deviceNames) {
            if (cameraEnumerator.isFrontFacing(name) == !isFacing) {
                CameraVideoCapturer cameraVideoCapturer = (CameraVideoCapturer) videoCapturer;
                cameraVideoCapturer.switchCamera(
                        new CameraVideoCapturer.CameraSwitchHandler() {
                            @Override
                            public void onCameraSwitchDone(boolean b) {
                                isFacing=!isFacing;
                                result.success(b);
                            }

                            @Override
                            public void onCameraSwitchError(String s) {
                                resultError("switchCamera", "Switching camera failed: " + id, result);
                            }
                        },name);
                return;
            }
        }
        resultError("switchCamera", "Switching camera failed: " + id, result);
    }

    /**
     * Creates and starts recording of local stream to file
     *
     * @param path         to the file for record
     * @param videoTrack   to record or null if only audio needed
     * @param audioChannel channel for recording or null
     * @throws Exception lot of different exceptions, pass back to dart layer to print them at least
     */
    void startRecordingToFile(
            String path, Integer id, @Nullable VideoTrack videoTrack, @Nullable AudioChannel audioChannel)
            throws Exception {
        AudioSamplesInterceptor interceptor = null;
        if (audioChannel == AudioChannel.INPUT) {
            interceptor = inputSamplesInterceptor;
        } else if (audioChannel == AudioChannel.OUTPUT) {
            if (outputSamplesInterceptor == null) {
                outputSamplesInterceptor = new OutputAudioSamplesInterceptor(audioDeviceModule);
            }
            interceptor = outputSamplesInterceptor;
        }
        MediaRecorderImpl mediaRecorder = new MediaRecorderImpl(id, videoTrack, interceptor);
        mediaRecorder.startRecording(new File(path));
        mediaRecorders.append(id, mediaRecorder);
    }

    void stopRecording(Integer id) {
        MediaRecorderImpl mediaRecorder = mediaRecorders.get(id);
        if (mediaRecorder != null) {
            mediaRecorder.stopRecording();
            mediaRecorders.remove(id);
            File file = mediaRecorder.getRecordFile();
            if (file != null) {
                ContentValues values = new ContentValues(3);
                values.put(MediaStore.Video.Media.TITLE, file.getName());
                values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");
                values.put(MediaStore.Video.Media.DATA, file.getAbsolutePath());
                applicationContext
                        .getContentResolver()
                        .insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);
            }
        }
    }

    void hasTorch(String trackId, Result result) {
        VideoCapturer videoCapturer = mVideoCapturers.get(trackId);
        if (videoCapturer == null) {
            resultError("hasTorch", "Video capturer not found for id: " + trackId, result);
            return;
        }

        if (VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP && videoCapturer instanceof Camera2Capturer) {
            CameraManager manager;
            CameraDevice cameraDevice;

            try {
                Object session =
                        getPrivateProperty(
                                Camera2Capturer.class.getSuperclass(), videoCapturer, "currentSession");
                manager =
                        (CameraManager)
                                getPrivateProperty(Camera2Capturer.class, videoCapturer, "cameraManager");
                cameraDevice =
                        (CameraDevice) getPrivateProperty(session.getClass(), session, "cameraDevice");
            } catch (NoSuchFieldWithNameException e) {
                // Most likely the upstream Camera2Capturer class have changed
                resultError("hasTorch", "[TORCH] Failed to get `" + e.fieldName + "` from `" + e.className + "`", result);
                return;
            }

            boolean flashIsAvailable;
            try {
                CameraCharacteristics characteristics =
                        manager.getCameraCharacteristics(cameraDevice.getId());
                flashIsAvailable = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
            } catch (CameraAccessException e) {
                // Should never happen since we are already accessing the camera
                throw new RuntimeException(e);
            }

            result.success(flashIsAvailable);
            return;
        }

        if (videoCapturer instanceof Camera1Capturer) {
            Camera camera;

            try {
                Object session =
                        getPrivateProperty(
                                Camera1Capturer.class.getSuperclass(), videoCapturer, "currentSession");
                camera = (Camera) getPrivateProperty(session.getClass(), session, "camera");
            } catch (NoSuchFieldWithNameException e) {
                // Most likely the upstream Camera1Capturer class have changed
                resultError("hasTorch", "[TORCH] Failed to get `" + e.fieldName + "` from `" + e.className + "`", result);
                return;
            }

            Parameters params = camera.getParameters();
            List<String> supportedModes = params.getSupportedFlashModes();

            result.success(
                    (supportedModes == null) ? false : supportedModes.contains(Parameters.FLASH_MODE_TORCH));
            return;
        }

        resultError("hasTorch", "[TORCH] Video capturer not compatible", result);
    }

    @RequiresApi(api = VERSION_CODES.LOLLIPOP)
    void setTorch(String trackId, boolean torch, Result result) {
        VideoCapturer videoCapturer = mVideoCapturers.get(trackId);
        if (videoCapturer == null) {
            resultError("setTorch", "Video capturer not found for id: " + trackId, result);
            return;
        }

        if (videoCapturer instanceof Camera2Capturer) {
            CameraCaptureSession captureSession;
            CameraDevice cameraDevice;
            CaptureFormat captureFormat;
            int fpsUnitFactor;
            Surface surface;
            Handler cameraThreadHandler;

            try {
                Object session =
                        getPrivateProperty(
                                Camera2Capturer.class.getSuperclass(), videoCapturer, "currentSession");
                CameraManager manager =
                        (CameraManager)
                                getPrivateProperty(Camera2Capturer.class, videoCapturer, "cameraManager");
                captureSession =
                        (CameraCaptureSession)
                                getPrivateProperty(session.getClass(), session, "captureSession");
                cameraDevice =
                        (CameraDevice) getPrivateProperty(session.getClass(), session, "cameraDevice");
                captureFormat =
                        (CaptureFormat) getPrivateProperty(session.getClass(), session, "captureFormat");
                fpsUnitFactor = (int) getPrivateProperty(session.getClass(), session, "fpsUnitFactor");
                surface = (Surface) getPrivateProperty(session.getClass(), session, "surface");
                cameraThreadHandler =
                        (Handler) getPrivateProperty(session.getClass(), session, "cameraThreadHandler");
            } catch (NoSuchFieldWithNameException e) {
                // Most likely the upstream Camera2Capturer class have changed
                resultError("setTorch", "[TORCH] Failed to get `" + e.fieldName + "` from `" + e.className + "`", result);
                return;
            }

            try {
                final CaptureRequest.Builder captureRequestBuilder =
                        cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_RECORD);
                captureRequestBuilder.set(
                        CaptureRequest.FLASH_MODE,
                        torch ? CaptureRequest.FLASH_MODE_TORCH : CaptureRequest.FLASH_MODE_OFF);
                captureRequestBuilder.set(
                        CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                        new Range<>(
                                captureFormat.framerate.min / fpsUnitFactor,
                                captureFormat.framerate.max / fpsUnitFactor));
                captureRequestBuilder.set(
                        CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);
                captureRequestBuilder.set(CaptureRequest.CONTROL_AE_LOCK, false);
                captureRequestBuilder.addTarget(surface);
                captureSession.setRepeatingRequest(
                        captureRequestBuilder.build(), null, cameraThreadHandler);
            } catch (CameraAccessException e) {
                // Should never happen since we are already accessing the camera
                throw new RuntimeException(e);
            }

            result.success(null);
            return;
        }

        if (videoCapturer instanceof Camera1Capturer) {
            Camera camera;
            try {
                Object session =
                        getPrivateProperty(
                                Camera1Capturer.class.getSuperclass(), videoCapturer, "currentSession");
                camera = (Camera) getPrivateProperty(session.getClass(), session, "camera");
            } catch (NoSuchFieldWithNameException e) {
                // Most likely the upstream Camera1Capturer class have changed
                resultError("setTorch", "[TORCH] Failed to get `" + e.fieldName + "` from `" + e.className + "`", result);
                return;
            }

            Camera.Parameters params = camera.getParameters();
            params.setFlashMode(
                    torch ? Camera.Parameters.FLASH_MODE_TORCH : Camera.Parameters.FLASH_MODE_OFF);
            camera.setParameters(params);

            result.success(null);
            return;
        }
        resultError("setTorch", "[TORCH] Video capturer not compatible", result);
    }

    private Object getPrivateProperty(Class klass, Object object, String fieldName)
            throws NoSuchFieldWithNameException {
        try {
            Field field = klass.getDeclaredField(fieldName);
            field.setAccessible(true);
            return field.get(object);
        } catch (NoSuchFieldException e) {
            throw new NoSuchFieldWithNameException(klass.getName(), fieldName, e);
        } catch (IllegalAccessException e) {
            // Should never happen since we are calling `setAccessible(true)`
            throw new RuntimeException(e);
        }
    }

    private class NoSuchFieldWithNameException extends NoSuchFieldException {

        String className;
        String fieldName;

        NoSuchFieldWithNameException(String className, String fieldName, NoSuchFieldException e) {
            super(e.getMessage());
            this.className = className;
            this.fieldName = fieldName;
        }
    }
}
