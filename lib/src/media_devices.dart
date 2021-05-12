import '../flutter_webrtc.dart';

class MediaDevices {
  @Deprecated(
      'Use the navigator.mediaDevices.getUserMedia(Map<String, dynamic>) provide from the facrory instead')
  static Future<MediaStream> getUserMedia(
      Map<String, dynamic> mediaConstraints) async {
    return navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  @Deprecated(
      'Use the navigator.mediaDevices.getDisplayMedia(Map<String, dynamic>) provide from the facrory instead')
  static Future<MediaStream> getDisplayMedia(
      Map<String, dynamic> mediaConstraints) async {
    return navigator.mediaDevices.getDisplayMedia(mediaConstraints);
  }

  @Deprecated(
      'Use the navigator.mediaDevices.getScreenShareMedia(Map<String, dynamic>) provide from the facrory instead')
  static Future<MediaStream> getScreenShareMedia(
      Map<String, dynamic> mediaConstraints) async {
    return navigator.mediaDevices.getScreenShareMedia(mediaConstraints);
  }

  @Deprecated(
      'Use the navigator.mediaDevices.closeScreenShareMedia(Map<String, dynamic>) provide from the facrory instead')
  static Future<void> closeScreenShareMedia() async {
    await navigator.mediaDevices.closeScreenShareMedia();
  }

  static Future<void> changeVirturalBackGround(
      Map<String, dynamic> constraints) async {
    await navigator.mediaDevices.changeVirturalBackGround(constraints);
  }

  @Deprecated(
      'Use the navigator.mediaDevices.getSources() provide from the facrory instead')
  static Future<List<dynamic>> getSources() {
    return navigator.mediaDevices.getSources();
  }
}
