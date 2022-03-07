import 'dart:async';

import 'package:flutter/services.dart';

/// `volume` 0 ~ 1;
typedef VolumeCallBack = Function(double volume);
typedef StopRecordCallBack = void Function(String path, int duration);
typedef StopPlayCallBack = void Function(String path);

class Flutterfmod {
  static const MethodChannel _channel = const MethodChannel('flutterfmod');

  static Flutterfmod _flutterFmod;

  // ignore: unused_field
  VolumeCallBack _callBack;
  StopPlayCallBack _stopCallBack;

  static Flutterfmod get _private =>
      _flutterFmod = _flutterFmod ?? Flutterfmod._();

  Flutterfmod._() {
    _channel.setMethodCallHandler((call) {
      if (call.method == 'volume') {
        double volume = call.arguments.toDouble();
        if (_private._callBack != null) {
          _private._callBack(volume);
        }
      }

      if (call.method == 'stopPlaying') {
        String path = call.arguments["path"] as String;
        if (_private._stopCallBack != null) {
          _private._stopCallBack(path);
          _private._stopCallBack = null;
        }
      }
      return null;
    });
  }

  bool recoreding = false;
  VolumeCallBack callback;

  /// start record
  /// [path] record file path.
  /// [callBack] volume callback: 0 ~ 1.
  static Future<bool> startVoiceRecord([
    VolumeCallBack volumeCallBack,
  ]) async {
    if (_private.recoreding) {
      return false;
    }
    if (volumeCallBack != null) {
      _private._callBack = volumeCallBack;
    }

    _private.recoreding =
        await _channel.invokeMethod('startVoiceRecord') as bool;

    return _private.recoreding;
  }

  /// stop record
  static Future<bool> stopVoiceRecord(
    StopRecordCallBack callBack,
  ) async {
    Map result = await _channel.invokeMethod('stopVoiceRecord');
    _private._callBack = null;
    _private.recoreding = false;
    String error = result['error'];
    String path = result['path'];
    int duration = result['duration'] as int;
    callBack(path, duration);
    return error == null ? true : false;
  }

  /// cancel record
  static Future<Null> cancelVoiceRecord() async {
    await _channel.invokeMethod('cancelVoiceRecord');
    _private._callBack = null;
    _private.recoreding = false;
  }

  /// play amr file
  static Future<bool> play(
    String path, [
    StopPlayCallBack endCallback,
  ]) async {
    _private._stopCallBack = endCallback;
    bool isPlay = await _channel.invokeMethod('play', {"path": path}) as bool;
    return isPlay;
  }

  /// stop playing amr file
  static Future<Null> stop() async {
    _private._stopCallBack = null;
    await _channel.invokeMethod('stopPlaying') as bool;
    return null;
  }

  static Future<String> conversion(
      int conversionType, String path, String savePath) async {
    final String okpath = await _channel.invokeMethod('conversion',
        {"conversionType": conversionType, "path": path, "savePath": savePath});
    return okpath;
  }
}
