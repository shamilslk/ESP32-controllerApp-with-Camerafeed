import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

bool _joyLock = false;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Controller',
      theme: ThemeData.dark(),
      home: const ControllerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  double sensitivity = 1.0;
  double joyX = 0;
  double joyY = 0;

  String esp32Ip = "192.168.4.1"; // Default ESP32 IP
  final ipController = TextEditingController();

  Future<void> sendCommand(String cmd) async {
    final url = Uri.parse("http://$esp32Ip/$cmd");

    try {
      await http.get(url);
    } catch (e) {
      print("ESP32 not reachable: $e");
    }
  }

  void openMenu() {
    ipController.text = esp32Ip;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("Settings"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // IP input field
                  TextField(
                    controller: ipController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "ESP32 IP",
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const SizedBox(height: 20),

                  // Sensitivity slider
                  const Text("Sensitivity"),
                  Slider(
                    value: sensitivity,
                    min: 0.1,
                    max: 3.0,
                    divisions: 30,
                    label: sensitivity.toStringAsFixed(1),
                    onChanged: (v) {
                      setDialogState(() {
                        sensitivity = v;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (!isLandscape) {
      return const Scaffold(
        body: Center(
          child: Text(
            "Rotate your phone to Landscape",
            style: TextStyle(fontSize: 22),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("ESP32 Controller"),
        actions: [
          IconButton(icon: const Icon(Icons.menu), onPressed: openMenu),
        ],
      ),
      body: Row(
        children: [
          // LEFT — JOYSTICK (smaller size)
          Expanded(
            flex: 3,
            child: Center(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: Joystick(
                  onChange: (x, y) {
                    joyX = x * sensitivity;
                    joyY = y * sensitivity;
                    if (!_joyLock) {
                      _joyLock = true;
                      sendCommand("joystick?x=$joyX&y=$joyY");
                      Future.delayed(const Duration(milliseconds: 70), () {
                        _joyLock = false;
                      });
                    }
                  },
                ),
              ),
            ),
          ),

          // CENTER — CAMERA FEED
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white30, width: 2),
                  color: Colors.black,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 4 / 3, // or 16/9 based on ESP32 cam
                    child: CameraWS(url: "ws://$esp32Ip:80/camera"),
                  ),
                ),
              ),
            ),
          ),

          // RIGHT — BUTTON CONTROLS
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // START & STOP buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => sendCommand("start"),
                      child: const Text("START"),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: () => sendCommand("stop"),
                      child: const Text("STOP"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ARROW controls
                Column(
                  children: [
                    IconButton(
                      iconSize: 60,
                      onPressed: () => sendCommand("up"),
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 60,
                          onPressed: () => sendCommand("left"),
                          icon: const Icon(Icons.keyboard_arrow_left),
                        ),
                        const SizedBox(width: 30),
                        IconButton(
                          iconSize: 60,
                          onPressed: () => sendCommand("right"),
                          icon: const Icon(Icons.keyboard_arrow_right),
                        ),
                      ],
                    ),
                    IconButton(
                      iconSize: 60,
                      onPressed: () => sendCommand("down"),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Joystick extends StatefulWidget {
  final Function(double x, double y) onChange;

  const Joystick({super.key, required this.onChange});

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  double x = 0, y = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final knobSize = size * 0.28;
        final radius = size / 2 - knobSize / 2;

        return GestureDetector(
          onPanUpdate: (details) {
            final box = context.findRenderObject() as RenderBox;
            final p = box.globalToLocal(details.globalPosition);

            double dx = p.dx - size / 2;
            double dy = p.dy - size / 2;

            double dist = sqrt(dx * dx + dy * dy);
            if (dist > radius) {
              dx = dx * radius / dist;
              dy = dy * radius / dist;
            }

            setState(() {
              x = dx / radius;
              y = dy / radius;
            });

            widget.onChange(x, -y);
          },
          onPanEnd: (_) {
            setState(() {
              x = 0;
              y = 0;
            });
            widget.onChange(0, 0);
          },

          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38, width: 4),
                  ),
                ),
                Positioned(
                  left: size / 2 + x * radius - knobSize / 2,
                  top: size / 2 + y * radius - knobSize / 2,
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MJPEG extends StatefulWidget {
  final String streamUrl;
  final BoxFit fit;

  const MJPEG({super.key, required this.streamUrl, this.fit = BoxFit.cover});

  @override
  State<MJPEG> createState() => _MJPEGState();
}

class _MJPEGState extends State<MJPEG> {
  StreamController<Uint8List>? _streamController;
  HttpClient? _httpClient;

  @override
  void initState() {
    super.initState();
    _streamController = StreamController<Uint8List>();
    _httpClient = HttpClient();
    _startStream();
  }

  void _startStream() async {
    try {
      final request = await _httpClient!.getUrl(Uri.parse(widget.streamUrl));
      final response = await request.close();

      List<int> buffer = [];

      response.listen((chunk) {
        for (var byte in chunk) {
          buffer.add(byte);

          // JPEG images start with FFD8 and end with FFD9
          if (buffer.length >= 2 &&
              buffer[buffer.length - 2] == 0xFF &&
              buffer[buffer.length - 1] == 0xD9) {
            _streamController?.add(Uint8List.fromList(buffer));
            buffer = [];
          }
        }
      });
    } catch (e) {
      print("Stream error: $e");
    }
  }

  @override
  void dispose() {
    _streamController?.close();
    _httpClient?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Uint8List>(
      stream: _streamController?.stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return Image.memory(snapshot.data!, fit: widget.fit);
      },
    );
  }
}

class CameraWS extends StatefulWidget {
  final String url;
  const CameraWS({super.key, required this.url});

  @override
  State<CameraWS> createState() => _CameraWSState();
}

class _CameraWSState extends State<CameraWS> {
  WebSocket? _socket;

  Uint8List? latestFrame; // always holds the latest frame
  Uint8List? displayedFrame; // frame shown on UI
  Timer? frameTimer;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();

    // Update UI at 20 FPS max
    frameTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (latestFrame != null) {
        setState(() {
          displayedFrame = latestFrame;
        });
      }
    });
  }

  Future<void> _connectWebSocket() async {
    try {
      _socket = await WebSocket.connect(widget.url);

      _socket!.listen(
        (data) {
          latestFrame = data; // store latest frame (skip old ones)
        },
        onError: (e) => print("WS Error: $e"),
        onDone: () => print("WS Closed"),
      );
    } catch (e) {
      print("Failed to connect WS: $e");
    }
  }

  @override
  void dispose() {
    _socket?.close();
    frameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (displayedFrame == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Image.memory(displayedFrame!, fit: BoxFit.cover);
  }
}
