import 'dart:async';
import 'dart:typed_data';
import 'bc_ur_encoder.dart';

/// Animated QR code generator for BC-UR multi-part messages
class AnimatedQR {
  final List<String> _parts;
  final Duration _interval;
  int _currentIndex = 0;
  Timer? _timer;
  StreamController<String>? _controller;
  
  AnimatedQR(this._parts, {Duration interval = const Duration(milliseconds: 500)})
      : _interval = interval;
  
  /// Get the total number of parts
  int get partCount => _parts.length;
  
  /// Get the current part index
  int get currentIndex => _currentIndex;
  
  /// Get the current QR code data
  String get currentPart => _parts[_currentIndex];
  
  /// Check if this is a single-part message
  bool get isSinglePart => _parts.length == 1;
  
  /// Start the animation and return a stream of QR code data
  Stream<String> start() {
    if (_controller != null) {
      throw StateError('Animation already started');
    }
    
    _controller = StreamController<String>.broadcast();
    
    if (isSinglePart) {
      // For single-part messages, just emit once
      _controller!.add(_parts[0]);
      _controller!.close();
    } else {
      // Start the animation timer
      _timer = Timer.periodic(_interval, (_) {
        _controller!.add(_parts[_currentIndex]);
        _currentIndex = (_currentIndex + 1) % _parts.length;
      });
      
      // Emit the first part immediately
      _controller!.add(_parts[_currentIndex]);
      _currentIndex = (_currentIndex + 1) % _parts.length;
    }
    
    return _controller!.stream;
  }
  
  /// Stop the animation
  void stop() {
    _timer?.cancel();
    _timer = null;
    _controller?.close();
    _controller = null;
    _currentIndex = 0;
  }
  
  /// Manually advance to the next part
  void nextPart() {
    if (!isSinglePart) {
      _currentIndex = (_currentIndex + 1) % _parts.length;
    }
  }
  
  /// Manually go to the previous part
  void previousPart() {
    if (!isSinglePart) {
      _currentIndex = (_currentIndex - 1 + _parts.length) % _parts.length;
    }
  }
  
  /// Go to a specific part
  void goToPart(int index) {
    if (index >= 0 && index < _parts.length) {
      _currentIndex = index;
    }
  }
  
  /// Get all parts as a list
  List<String> getAllParts() => List.unmodifiable(_parts);
  
  /// Create an animated QR from encoded data
  static AnimatedQR fromEncodedParts(List<String> parts, {Duration? interval}) {
    return AnimatedQR(parts, interval: interval ?? const Duration(milliseconds: 500));
  }
  
  /// Create an animated QR by encoding data
  static AnimatedQR fromData(String type, Uint8List data, {
    int? fragmentLength,
    Duration? interval,
  }) {
    final parts = BCUREncoder.encodeMultiple(type, data, fragmentLength: fragmentLength);
    return AnimatedQR(parts, interval: interval ?? const Duration(milliseconds: 500));
  }
}

/// QR code animation controller with additional features
class QRAnimationController {
  final AnimatedQR _animatedQR;
  bool _isPlaying = false;
  bool _isPaused = false;
  StreamSubscription? _subscription;
  
  QRAnimationController(this._animatedQR);
  
  /// Check if animation is currently playing
  bool get isPlaying => _isPlaying;
  
  /// Check if animation is paused
  bool get isPaused => _isPaused;
  
  /// Get the current part
  String get currentPart => _animatedQR.currentPart;
  
  /// Get the current part index
  int get currentIndex => _animatedQR.currentIndex;
  
  /// Get the total number of parts
  int get partCount => _animatedQR.partCount;
  
  /// Start or resume the animation
  Stream<String> play() {
    if (_isPlaying && !_isPaused) {
      throw StateError('Animation is already playing');
    }
    
    _isPlaying = true;
    _isPaused = false;
    
    return _animatedQR.start();
  }
  
  /// Pause the animation
  void pause() {
    if (_isPlaying && !_isPaused) {
      _isPaused = true;
      _animatedQR.stop();
    }
  }
  
  /// Stop the animation completely
  void stop() {
    _isPlaying = false;
    _isPaused = false;
    _animatedQR.stop();
  }
  
  /// Manually step to next part
  void stepForward() {
    _animatedQR.nextPart();
  }
  
  /// Manually step to previous part
  void stepBackward() {
    _animatedQR.previousPart();
  }
  
  /// Jump to specific part
  void jumpTo(int index) {
    _animatedQR.goToPart(index);
  }
  
  /// Get progress as percentage (0.0 to 1.0)
  double get progress {
    if (_animatedQR.partCount <= 1) return 1.0;
    return _animatedQR.currentIndex / (_animatedQR.partCount - 1);
  }
}