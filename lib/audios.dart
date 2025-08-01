import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'utils/network.dart';
import 'utils/audio_commons.dart';
import 'package:rxdart/rxdart.dart';
// import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;

class AudiosPage extends StatelessWidget {
  const AudiosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pinkAccent,
        title: const Text("listening practice"),
      ),
      body: const AudioJust(),
    );
  }
}

class AudioJust extends StatefulWidget {
  const AudioJust({super.key});

  @override
  AudioJustState createState() => AudioJustState();
}

class AudioJustState extends State<AudioJust> {
  late AudioPlayer _player;
  ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    fetchAudios();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  fetchAudios() {
    List<AudioSource> list = [];
    laravel.get("audios").then((value) {
      if (value.data["status"] != "success") return;
      var data = value.data["data"];
      for (var element in data) {
        AudioSource voice = AudioSource.uri(
          Uri.parse(mediaHost + element["path"]),
          tag: MediaItem(
            id: "${element["id"]}",
            album: "",
            title: element["name"],
            artUri:
                Uri.parse("https://api.xiaobaibk.com/api/pic/?pic=meizi&a=${element["id"]}"),
                // https://api.lolicon.app/setu/v2  docs : https://api.lolicon.app/#/setu 
          ),
        );
        list.add(voice);
      }
      _init();
      setState(() {
        _playlist = ConcatenatingAudioSource(children: list);
        _loading = false;
      });
    });
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // Listen to errors during playback.
    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      print('A stream error occurred: $e');
    });
    try {
      await _player.setAudioSource(_playlist);
    } catch (e, stackTrace) {
      // Catch load errors: 404, invalid url ...
      print("Error loading playlist: $e");
      print(stackTrace);
    }
  }

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: StreamBuilder<SequenceState?>(
                      stream: _player.sequenceStateStream,
                      builder: (context, snapshot) {
                        final state = snapshot.data;
                        if (state?.sequence.isEmpty ?? true) {
                          return const SizedBox();
                        }
                        final metadata = state!.currentSource!.tag as MediaItem;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                    child: Image.network(
                                        metadata.artUri.toString())),
                              ),
                            ),
                            Text(metadata.album!,
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(metadata.title),
                          ],
                        );
                      },
                    ),
                  ),
                  ControlButtons(_player),
                  StreamBuilder<PositionData>(
                    stream: _positionDataStream,
                    builder: (context, snapshot) {
                      final positionData = snapshot.data;
                      return SeekBar(
                        duration: positionData?.duration ?? Duration.zero,
                        position: positionData?.position ?? Duration.zero,
                        bufferedPosition:
                            positionData?.bufferedPosition ?? Duration.zero,
                        onChangeEnd: (newPosition) {
                          _player.seek(newPosition);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      StreamBuilder<LoopMode>(
                        stream: _player.loopModeStream,
                        builder: (context, snapshot) {
                          final loopMode = snapshot.data ?? LoopMode.off;
                          const icons = [
                            Icon(Icons.repeat, color: Colors.grey),
                            Icon(Icons.repeat, color: Colors.orange),
                            Icon(Icons.repeat_one, color: Colors.orange),
                          ];
                          const cycleModes = [
                            LoopMode.off,
                            LoopMode.all,
                            LoopMode.one,
                          ];
                          final index = cycleModes.indexOf(loopMode);
                          return IconButton(
                            icon: icons[index],
                            onPressed: () {
                              _player.setLoopMode(cycleModes[
                                  (cycleModes.indexOf(loopMode) + 1) %
                                      cycleModes.length]);
                            },
                          );
                        },
                      ),
                      Expanded(
                        child: Text(
                          "Playlist",
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      StreamBuilder<bool>(
                        stream: _player.shuffleModeEnabledStream,
                        builder: (context, snapshot) {
                          final shuffleModeEnabled = snapshot.data ?? false;
                          return IconButton(
                            icon: shuffleModeEnabled
                                ? const Icon(Icons.shuffle,
                                    color: Colors.orange)
                                : const Icon(Icons.shuffle, color: Colors.grey),
                            onPressed: () async {
                              final enable = !shuffleModeEnabled;
                              if (enable) {
                                await _player.shuffle();
                              }
                              await _player.setShuffleModeEnabled(enable);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 240.0,
                    child: StreamBuilder<SequenceState?>(
                      stream: _player.sequenceStateStream,
                      builder: (context, snapshot) {
                        final state = snapshot.data;
                        final sequence = state?.sequence ?? [];
                        return ReorderableListView(
                          onReorder: (int oldIndex, int newIndex) {
                            if (oldIndex < newIndex) newIndex--;
                            _playlist.move(oldIndex, newIndex);
                          },
                          children: [
                            for (var i = 0; i < sequence.length; i++)
                              Dismissible(
                                key: ValueKey(sequence[i]),
                                background: Container(
                                  color: Colors.redAccent,
                                  alignment: Alignment.centerRight,
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child:
                                        Icon(Icons.delete, color: Colors.white),
                                  ),
                                ),
                                onDismissed: (dismissDirection) {
                                  _playlist.removeAt(i);
                                },
                                child: Material(
                                  color: i == state!.currentIndex
                                      ? Colors.grey.shade300
                                      : null,
                                  child: ListTile(
                                    title:
                                        Text(sequence[i].tag.title as String),
                                    onTap: () {
                                      _player.seek(Duration.zero, index: i);
                                      _player.play();
                                    },
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ));
  }
}

class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  const ControlButtons(this.player, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              value: player.volume,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),
        StreamBuilder<SequenceState?>(
          stream: player.sequenceStateStream,
          builder: (context, snapshot) => IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: player.hasPrevious ? player.seekToPrevious : null,
          ),
        ),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: const EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: const CircularProgressIndicator(),
              );
            } else if (playing != true) {
              return IconButton(
                icon: const Icon(Icons.play_arrow),
                iconSize: 64.0,
                onPressed: player.play,
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                icon: const Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                icon: const Icon(Icons.replay),
                iconSize: 64.0,
                onPressed: () => player.seek(Duration.zero,
                    index: player.effectiveIndices!.first),
              );
            }
          },
        ),
        StreamBuilder<SequenceState?>(
          stream: player.sequenceStateStream,
          builder: (context, snapshot) => IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: player.hasNext ? player.seekToNext : null,
          ),
        ),
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              showSliderDialog(
                context: context,
                title: "Adjust speed",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                value: player.volume,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        ),
      ],
    );
  }
}