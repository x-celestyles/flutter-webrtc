import '../interface/media_stream.dart';
import '../interface/mediadevices.dart';
import '../interface/navigator.dart';
import 'mediadevices_impl.dart';

class NavigatorNative extends Navigator {
  @override
  Future<MediaStream> getDisplayMedia(Map<String, dynamic> mediaConstraints) {
    return mediaDevices.getDisplayMedia(mediaConstraints);
  }

  @override
  Future<MediaStream> getScreenShareMedia(
      Map<String, dynamic> mediaConstraints) {
    return mediaDevices.getScreenShareMedia(mediaConstraints);
  }

  @override
  Future<void> closeScreenShareMedia() async {
    await mediaDevices.closeScreenShareMedia();
  }

  @override
  Future<void> changeVirtualBackGround(
      Map<String, dynamic> constraints) async {
    await mediaDevices.changeVirtualBackGround(constraints);
  }

  @override
  Future<List> getSources() {
    return mediaDevices.enumerateDevices();
  }

  @override
  Future<MediaStream> getUserMedia(Map<String, dynamic> mediaConstraints) {
    return mediaDevices.getUserMedia(mediaConstraints);
  }

  @override
  MediaDevices get mediaDevices => MediaDeviceNative();
}
