import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'La Musica',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MusicPlayerScreen(),
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  @override
  _MusicPlayerScreenState createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isPlaying = false;
  Uint8List? albumImageBytes;
  String streamIP = 'http://127.0.0.1:8090';
  String streamUrl = 'http://127.0.0.1:8090/fm';
  String songTitle = 'Loading...';
  String artistName = 'Loading...';
  double volume = 1.0; // 0.0 to 1.0
  String? previousSongTitle;

  // Timer to fetch song data periodically
  Timer? _timer;

  // Fetch song info
  Future<void> fetchSongData() async {
    try {
      final response = await http.get(Uri.parse(streamIP).replace(path: '/fm/info'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newSongTitle = data['data']['title'] ?? 'Unknown Title';
        final newArtistName = data['data']['artist'] ?? 'Unknown Artist';

        // Update the album image if title changed
        if (newSongTitle != previousSongTitle) {
          previousSongTitle = newSongTitle;

          final imageResponse = await http.get(Uri.parse(streamIP).replace(path: '/fm/info/cover'));

          if (imageResponse.statusCode == 200) {
            setState(() {
              albumImageBytes = imageResponse.bodyBytes; // bytes
            });
          } else {
            setState(() {
              albumImageBytes = null;
            });
          }
        }

        setState(() {
          songTitle = newSongTitle;
          artistName = newArtistName;
        });
      } else {
        setState(() {
          songTitle = 'Error fetching song';
          artistName = 'Error fetching artist';
        });
      }
    } catch (e) {
      setState(() {
        songTitle = 'Network Error';
        artistName = 'Network Error';
        albumImageBytes = null;
      });
    }
  }

  Future<bool> _checkUrlResponse(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Play or mute/unmute music
  void _togglePlayPause() async {
    if (!isPlaying) {
      // Check if the URL is responsive
      bool isUrlResponsive = await _checkUrlResponse(streamIP);
      
      if (isUrlResponsive) {
        try {
          await _audioPlayer.play(UrlSource(streamUrl), volume: volume);
          setState(() {
            isPlaying = true;
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to play audio. Please check the stream URL.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stream URL is not responsive. Please check the URL.'),
            duration: Duration(seconds: 3),
          ),
        );
      }

    } else {
      await _audioPlayer.stop();
      setState(() {
        isPlaying = false;
      });
    }
  }
 
  void _exitApp() {
    SystemNavigator.pop();
  }
  
  @override
  void initState() {
    const String streamIPenv = String.fromEnvironment(
      'STREAM_BASE_IP',
      defaultValue: "http://127.0.0.1:8090",
    );
    streamIP = streamIPenv;
    streamUrl = Uri.parse(streamIP).replace(path: '/fm').toString();
    super.initState();
    fetchSongData();

    // Set up a periodic timer to fetch song info every 2 seconds
    _timer = Timer.periodic(Duration(seconds: 2), (Timer t) {
      fetchSongData();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _timer?.cancel();
    super.dispose();
  }

 // Show Info Popup with TextField to Update Stream URL
  void _showInfo(BuildContext context) {
    String newUrl = streamIP;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "GoFM server IP",
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 4),
              Text(
                "Check https://github.com/kormiltsev/GoFM to build bacend",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: newUrl,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  newUrl = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Save"),
              onPressed: () {
                setState(() {
                  streamIP = newUrl;
                  streamUrl = Uri.parse(streamIP).replace(path: '/fm').toString();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        toolbarHeight: 5,
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              albumImageBytes != null
                  ? Image.memory(
                      albumImageBytes!,
                      height: 420,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 400,
                      color: Colors.grey,
                      child: Icon(
                        Icons.wifi_off_outlined,
                        size: 100,
                        color: Colors.white,
                      ),
                    ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      songTitle,
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      artistName,
                      style: TextStyle(color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
    Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(80.0),
                  topRight: Radius.circular(80.0),
                  bottomLeft: Radius.circular(80.0),
                  bottomRight: Radius.circular(80.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Exit Button
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white, size: 36),
                    onPressed: _exitApp,
                  ),
                  // Play/Pause button
                  IconButton(
                    icon: Icon(
                      isPlaying && volume > 0.0 ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      size: 45,
                      color: Colors.white,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                  // Settings Button
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: Colors.white, size: 36),
                    onPressed: () => _showInfo(context),
                  ),
                ],
              ),
            ),
          ),
          // Volume slider
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: screenWidth / 2,
                child: Slider(
                  value: volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  activeColor: const Color.fromARGB(255, 154, 141, 141),
                  onChanged: (value) {
                    setState(() {
                      volume = value;
                      _audioPlayer.setVolume(volume);
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}