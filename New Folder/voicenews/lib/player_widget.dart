import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:voicenews/voice_connection.dart';

enum PlayerState { stopped, playing, paused }

class PlayerWidget extends StatefulWidget {
  final String body;
  final PlayerMode mode;

  PlayerWidget({@required this.body, this.mode = PlayerMode.MEDIA_PLAYER});

  @override
  State<StatefulWidget> createState() {
    return _PlayerWidgetState(body, mode);
  }
}

class _PlayerWidgetState extends State<PlayerWidget> {
  String body;
  PlayerMode mode;
  AudioPlayer _audioPlayer;
  AudioPlayerState _audioPlayerState;
  Duration _duration;
  Duration _position;

  PlayerState _playerState = PlayerState.stopped;

  StreamSubscription _durationSubscription;

  StreamSubscription _positionSubscription;

  StreamSubscription _playerCompleteSubscription;

  StreamSubscription _playerErrorSubscription;

  StreamSubscription _playerStateSubscription;

  get _isPlaying => _playerState == PlayerState.playing;

  get _isPaused => _playerState == PlayerState.paused;

  get _durationText => _duration?.toString()?.split('.')?.first ?? '';

  get _positionText => _position?.toString()?.split('.')?.first ?? '';

  _PlayerWidgetState(this.body, this.mode);

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.stop();

    _durationSubscription?.cancel();

    _positionSubscription?.cancel();

    _playerCompleteSubscription?.cancel();

    _playerErrorSubscription?.cancel();

    _playerStateSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        SizedBox(
          height: 60.0,
          width: 60.0,
          child: CircularProgressIndicator(
            backgroundColor: Colors.black,
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation(Colors.greenAccent),
            value: (_position != null &&
                    _duration != null &&
                    _position.inMilliseconds > 0 &&
                    _position.inMilliseconds < _duration.inMilliseconds)
                ? _position.inMilliseconds / _duration.inMilliseconds
                : 0.0,
          ),
        ),
        IconButton(
            icon: _isPlaying
                ? Icon(
                    Icons.pause,
                    color: Colors.black,
                    size: 30,
                  )
                : Icon(
                    Icons.play_arrow,
                    color: Colors.black,
                    size: 30,
                  ),
            onPressed: () {
              _isPlaying ? _pause() : _play(body);
            })
      ],
    );
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer(mode: mode);

    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    _positionSubscription =
        _audioPlayer.onAudioPositionChanged.listen((p) => setState(() {
              _position = p;
            }));

    _playerCompleteSubscription =
        _audioPlayer.onPlayerCompletion.listen((event) {
      _onComplete();

      setState(() {
        _position = _duration;
      });
    });

    _playerErrorSubscription = _audioPlayer.onPlayerError.listen((msg) {
      print('audioPlayer error : $msg');

      setState(() {
        _playerState = PlayerState.stopped;

        _duration = Duration(seconds: 0);

        _position = Duration(seconds: 0);
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;

      setState(() {
        _audioPlayerState = state;
      });
    });
  }

  Future<int> _play(String body) async {
    var response = await voiceResponse(body);
    var jsonData = jsonDecode(response.body);

    String audiobase64 = jsonData['audioContent'];
    Uint8List bytes = base64Decode(audiobase64);

    String dir = (await getApplicationDocumentsDirectory()).path;
    File file = File(
        "$dir/" + DateTime.now().millisecondsSinceEpoch.toString() + ".mp3");
    await file.writeAsBytes(bytes);

    final playPosition = (_position != null &&
            _duration != null &&
            _position.inMilliseconds > 0 &&
            _position.inMilliseconds < _duration.inMilliseconds)
        ? _position
        : null;

    final result = await _audioPlayer.play(file.path,
        isLocal: true, position: playPosition);

    if (result == 1) setState(() => _playerState = PlayerState.playing);

    return result;
  }

  Future<int> _pause() async {
    final result = await _audioPlayer.pause();

    if (result == 1) setState(() => _playerState = PlayerState.paused);

    return result;
  }

  Future<int> _stop() async {
    final result = await _audioPlayer.stop();

    if (result == 1) {
      setState(() {
        _playerState = PlayerState.stopped;

        _position = Duration();
      });
    }
    return result;
  }

  void _onComplete() {
    setState(() => _playerState = PlayerState.stopped);
  }
}
