import 'media_stream.dart';
import 'mediadevices.dart';

abstract class Navigator {
  @Deprecated('use mediadevice.getUserMedia() instead')
  Future<MediaStream> getUserMedia(Map<String, dynamic> mediaConstraints);

  @Deprecated('use mediadevice.getDisplayMedia() instead')
  Future<MediaStream> getDisplayMedia(Map<String, dynamic> mediaConstraints);

  @Deprecated('use mediadevice.getScreenShareMedia() instead')
  Future<MediaStream> getScreenShareMedia(
      Map<String, dynamic> mediaConstraints);

  @Deprecated('use mediadevice.closeScreenShareMedia() instead')
  Future<void> closeScreenShareMedia();

  Future<void> changeVirtualBackGround(Map<String, dynamic> constraints);

  @Deprecated('use mediadevice.enumerateDevices() instead')
  Future<List<dynamic>> getSources();

  MediaDevices get mediaDevices;
}
