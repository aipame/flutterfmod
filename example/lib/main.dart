import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutterfmod/flutterfmod.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  double _volume = 0;
  String _path;
  String _playPath;
  @override
  void initState() {
    _requestPermiss();
    super.initState();
  }

// const val MODE_FUNNY = 1 //搞笑

//     const val MODE_UNCLE = 2 //大叔

//     const val MODE_LOLITA = 3 //萝莉

//     const val MODE_ROBOT = 4 //机器人

//     const val MODE_ETHEREAL = 5 //空灵

//     const val MODE_CHORUS = 6 //混合

//     const val MODE_HORROR = 7 //恐怖
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: _volume * 100,
                height: 30,
                color: Colors.blue[300],
              ),
              Container(
                width: 120,
                height: 120,
                child: GestureDetector(
                  onTapDown: (TapDownDetails details) => _startRecord(),
                  onTapUp: (TapUpDetails details) => _stopRecord(),
                  onTapCancel: () => _cancelRecord(),
                  child: Text(
                    'Record',
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.play_arrow),
                    onPressed: () => _play(),
                  ),
                  IconButton(
                    icon: Icon(Icons.stop),
                    onPressed: () => _stop(),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () async {
                  _playPath = await Flutterfmod.conversion(1, _path, null);
                },
                child: Text(
                  '搞笑',
                ),
              ),
              GestureDetector(
                onTap: () async {
                  _playPath = await Flutterfmod.conversion(2, _path, null);
                },
                child: Text(
                  '大叔',
                ),
              ),
              GestureDetector(
                onTap: () async {
                  _playPath = await Flutterfmod.conversion(3, _path, null);
                },
                child: Text(
                  '萝莉',
                ),
              ),
              GestureDetector(
                onTap: () async {
                  _playPath = await Flutterfmod.conversion(4, _path, null);
                },
                child: Text(
                  '机器人',
                ),
              ),
              GestureDetector(
                onTap: () async {
                  _playPath = await Flutterfmod.conversion(5, _path, null);
                },
                child: Text(
                  '空灵',
                ),
              ),
              GestureDetector(
                onTap: () async {
                  _playPath = await Flutterfmod.conversion(6, _path, null);
                },
                child: Text(
                  '混合',
                ),
              ),
              GestureDetector(
                onTap: () async {
                  _playPath = await Flutterfmod.conversion(7, _path, null);
                },
                child: Text(
                  '恐怖',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _startRecord() async {
    bool success = await Flutterfmod.startVoiceRecord((volume) {
      print('volume ---- $volume');
      setState(() {
        _volume = volume;
      });
    });
    print('start record ---- $success');
  }

  _stopRecord() async {
    bool success = await Flutterfmod.stopVoiceRecord((path, duration) {
      _path = path;
      _playPath = path;
      print('path --- $path, duration ---- $duration');
    });
    setState(() {
      _volume = 0;
    });
    print('stop record ---- $success');
  }

  _cancelRecord() async {
    await Flutterfmod.cancelVoiceRecord();
    setState(() {
      _volume = 0;
    });
    print('取消录制');
  }

  _play() async {
    await Flutterfmod.play(_playPath, (path) {
      print('play end');
    });
  }

  _stop() async {
    await Flutterfmod.stop();
  }

  _requestPermiss() async {
    await Permission.microphone.request();
  }
}
