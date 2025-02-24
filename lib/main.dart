import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class AppColors {
  static const primary = Color(0xFF0A2540);
  static const secondary = Color(0xFF00B3B3);
  static const background = Color(0xFFF7F9FC);
  static const text = Color(0xFF1A1F36);
}

class MyApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('ar', '');

  void _changeLanguage(bool isEnglish) {
    setState(() {
      _locale = isEnglish ? const Locale('en') : const Locale('ar');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Abser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.cairoTextTheme().apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''),
        Locale('en', ''),
      ],
      locale: _locale,
      home: SplashScreen(cameras: widget.cameras, changeLanguage: _changeLanguage),
    );
  }
}

class SplashScreen extends StatelessWidget {
  final List<CameraDescription> cameras;
  final Function(bool) changeLanguage;

  const SplashScreen({
    Key? key,
    required this.cameras,
    required this.changeLanguage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Future<void> checkFirstSeen() async {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OnboardingScreen(cameras: cameras),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => checkFirstSeen());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const OnboardingScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          cameras: widget.cameras,
          changeLanguage: (bool isEnglish) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (int page) => setState(() => _currentPage = page),
        children: [
          _buildOnboardingPage(
            animationPath: 'assets/money.json',
            title: 'Welcome to Abser',
            content: 'App that is dedicated to recognize Libyan Currency for the blind community',
            color: Colors.blue,
          ),
          _buildOnboardingPage(
            animationPath: 'assets/phone.json',
            title: 'Features',
            content: 'Abser app uses models that help recognize Libyan currencies through the use of mobile camera',
            color: Colors.green,
          ),
          _buildOnboardingPage(
            animationPath: 'assets/start.json',
            title: 'Get Started',
            content: 'Start using the app now',
            color: Colors.orange,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _currentPage == 2
            ? _completeOnboarding
            : () => _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.ease,
        ),
        child: Icon(_currentPage == 2 ? Icons.check : Icons.arrow_forward),
      ),
    );
  }

  Widget _buildOnboardingPage({
    required String title,
    required String content,
    required Color color,
    required String animationPath,
  }) {
    return Container(
      color: color,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            animationPath,
            height: 200,
            fit: BoxFit.cover,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 32,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            content,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Function(bool) changeLanguage;

  const HomeScreen({
    Key? key,
    required this.cameras,
    required this.changeLanguage,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late CameraController _controller;
  String? _capturedImagePath;
  String? _currencyType;
  bool isEnglish = false;
  late Interpreter _interpreter;
  List<String> labels = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
    _loadLabels();
  }

  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset('best.tflite');
  }

  Future<void> _loadLabels() async {
    final labelData = await DefaultAssetBundle.of(context).loadString('assets/labels.txt');
    setState(() {
      labels = labelData.split('\n');
    });
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
    );
    await _controller.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _processImage(String imagePath) async {
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes)!;

    // Preprocess image
    final resizedImage = img.copyResize(image, width: 320, height: 320);
    final input = preprocessImage(resizedImage);

    // Run inference
    final output = List.filled(6, 0.0);
    // Wrap output in a list to simulate a 2D structure if required
    final outputReshaped = [output];
    _interpreter.run(input, outputReshaped);

    // Postprocess results
    final results = parseOutput(outputReshaped);
    setState(() {
      _currencyType = results.isNotEmpty ? labels[results[0].classIndex] : 'Unknown';
    });
  }

  // Returns a flat Float32List for the image of size 320 x 320 x 3.
  Float32List preprocessImage(img.Image image) {
    final inputBytes = Float32List(320 * 320 * 3);
    int pixelIndex = 0;
    for (int y = 0; y < 320; y++) {
      for (int x = 0; x < 320; x++) {
        final pixel = image.getPixel(x, y);
        inputBytes[pixelIndex++] = img.getRed(pixel) / 255.0;
        inputBytes[pixelIndex++] = img.getGreen(pixel) / 255.0;
        inputBytes[pixelIndex++] = img.getBlue(pixel) / 255.0;
      }
    }
    return inputBytes;
  }

  List<DetectionResult> parseOutput(List<dynamic> output) {
    final results = <DetectionResult>[];
    final confidenceThreshold = 0.5;

    // Assuming each prediction is structured as:
    // [x, y, width, height, confidence, classIndex]
    for (var prediction in output[0]) {
      final confidence = prediction[4];
      if (confidence > confidenceThreshold) {
        results.add(DetectionResult(
          classIndex: prediction[5].toInt(),
          confidence: confidence,
          rect: Rect.fromLTWH(
            prediction[0],
            prediction[1],
            prediction[2],
            prediction[3],
          ),
        ));
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          toolbarHeight: 80.0,
          title: SvgPicture.asset(
            isEnglish ? 'assets/Abser Logo white en-03.svg' : 'assets/Abser Logo white ar-03-04.svg',
            height: 40,
          ),
          elevation: 0,
        ),
        drawer: Drawer(
          child: ListView(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                ),
                child: SvgPicture.asset(
                  isEnglish ? 'assets/Abser Logo white en-03.svg' : 'assets/Abser Logo white ar-03-04.svg',
                  height: 60,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: Text(
                  isEnglish ? 'Capture Image' : 'التقاط صورة',
                  style: const TextStyle(color: AppColors.text),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _resetCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info, color: AppColors.primary),
                title: Text(
                  isEnglish ? 'About App' : 'حول التطبيق',
                  style: const TextStyle(color: AppColors.text),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(isEnglish ? 'About App' : 'حول التطبيق'),
                      content: Text(
                        isEnglish
                            ? 'This app was made possible from dedicated students who want to help the community:\n\n• Anas Mersal\n• Mohamed Gabriel\n• Nabiel Asteita'
                            : 'تم إنشاء هذا التطبيق بواسطة طلاب متفانين يريدون مساعدة المجتمع:\n\n• أنس مرسال\n• محمد جبريل\n• نبيل استيتة',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(isEnglish ? 'Close' : 'إغلاق'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.language, color: AppColors.primary),
                title: Text(
                  isEnglish ? 'Change Language' : 'تغيير اللغة',
                  style: const TextStyle(color: AppColors.text),
                ),
                onTap: _toggleLanguage,
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _capturedImagePath != null
                        ? AppColors.primary
                        : AppColors.secondary.withOpacity(0.3),
                    width: _capturedImagePath != null ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _capturedImagePath == null
                      ? CameraPreview(_controller)
                      : Image.file(File(_capturedImagePath!)),
                ),
              ),
            ),
            if (_currencyType != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  'نوع العملة: $_currencyType',
                  style: const TextStyle(
                    fontSize: 20,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_capturedImagePath != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                      onPressed: _resetCamera,
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                      ),
                      label: Text(
                        isEnglish ? 'Retake' : 'إعادة التقاط',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (_capturedImagePath == null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      onPressed: () async {
                        try {
                          final image = await _controller.takePicture();
                          setState(() {
                            _capturedImagePath = image.path;
                          });
                          await _processImage(image.path);
                        } catch (e) {
                          print(e);
                        }
                      },
                      child: Text(
                        isEnglish ? 'Capture' : 'التقاط',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetCamera() {
    setState(() {
      _capturedImagePath = null;
      _currencyType = null;
    });
  }

  void _toggleLanguage() {
    setState(() {
      isEnglish = !isEnglish;
      widget.changeLanguage(isEnglish);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _interpreter.close();
    super.dispose();
  }
}

class DetectionResult {
  final int classIndex;
  final double confidence;
  final Rect rect;

  DetectionResult({
    required this.classIndex,
    required this.confidence,
    required this.rect,
  });
}
