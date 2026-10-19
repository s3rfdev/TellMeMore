/// Сырые метрики компьютерного зрения (Blendshapes, Gaze, HeadPose)
class FaceBlendshapeScores {
  final Map<String, double> values;

  const FaceBlendshapeScores(this.values);

  factory FaceBlendshapeScores.empty() => const FaceBlendshapeScores({});

  double get(String key) => values[key] ?? 0.0;

  // Ключевые FACS Action Units через 52 ARKit Blendshapes:
  double get browDownLeft => get('browDownLeft');
  double get browDownRight => get('browDownRight');
  double get browInnerUp => get('browInnerUp');
  double get browOuterUpLeft => get('browOuterUpLeft');
  double get browOuterUpRight => get('browOuterUpRight');

  double get eyeBlinkLeft => get('eyeBlinkLeft');
  double get eyeBlinkRight => get('eyeBlinkRight');
  double get eyeSquintLeft => get('eyeSquintLeft');
  double get eyeSquintRight => get('eyeSquintRight');
  double get eyeWideLeft => get('eyeWideLeft');
  double get eyeWideRight => get('eyeWideRight');

  double get eyeLookDownLeft => get('eyeLookDownLeft');
  double get eyeLookDownRight => get('eyeLookDownRight');
  double get eyeLookInLeft => get('eyeLookInLeft');
  double get eyeLookInRight => get('eyeLookInRight');
  double get eyeLookOutLeft => get('eyeLookOutLeft');
  double get eyeLookOutRight => get('eyeLookOutRight');
  double get eyeLookUpLeft => get('eyeLookUpLeft');
  double get eyeLookUpRight => get('eyeLookUpRight');

  double get jawOpen => get('jawOpen');
  double get jawForward => get('jawForward');
  double get jawLeft => get('jawLeft');
  double get jawRight => get('jawRight');

  double get mouthSmileLeft => get('mouthSmileLeft');
  double get mouthSmileRight => get('mouthSmileRight');
  double get mouthFrownLeft => get('mouthFrownLeft');
  double get mouthFrownRight => get('mouthFrownRight');
  double get mouthPressLeft => get('mouthPressLeft');
  double get mouthPressRight => get('mouthPressRight');
  double get mouthPucker => get('mouthPucker');
  double get mouthRollLower => get('mouthRollLower');
  double get mouthRollUpper => get('mouthRollUpper');
  double get mouthShrugLower => get('mouthShrugLower');
  double get mouthShrugUpper => get('mouthShrugUpper');
  double get noseSneerLeft => get('noseSneerLeft');
  double get noseSneerRight => get('noseSneerRight');

  // Производные метрики:
  double get browDownAvg => (browDownLeft + browDownRight) / 2.0;
  double get eyeBlinkAvg => (eyeBlinkLeft + eyeBlinkRight) / 2.0;
  double get eyeSquintAvg => (eyeSquintLeft + eyeSquintRight) / 2.0;
  double get mouthSmileAvg => (mouthSmileLeft + mouthSmileRight) / 2.0;
  double get mouthPressAvg => (mouthPressLeft + mouthPressRight) / 2.0;
  double get smileAsymmetry => (mouthSmileLeft - mouthSmileRight).abs();
}

/// Направление взгляда (положение зрачка/радужки относительно центра глаза)
enum GazeDirectionType {
  center,
  upLeft,
  upRight,
  upCenter,
  downLeft,
  downRight,
  downCenter,
  left,
  right,
  averted, // Резко ушёл от контакта
}

class GazeVector {
  final double yaw;   // Горизонтальный угол (-1.0 лево, +1.0 право)
  final double pitch; // Вертикальный угол (-1.0 низ, +1.0 верх)
  final GazeDirectionType direction;

  const GazeVector({
    required this.yaw,
    required this.pitch,
    required this.direction,
  });

  factory GazeVector.center() => const GazeVector(
        yaw: 0.0,
        pitch: 0.0,
        direction: GazeDirectionType.center,
      );
}

/// Положение головы в пространстве (Pitch, Yaw, Roll в градусах)
class HeadPose {
  final double pitch; // Наклон вперед/назад (+ вверх, - вниз)
  final double yaw;   // Поворот влево/вправо
  final double roll;  // Наклон к плечу

  const HeadPose({
    required this.pitch,
    required this.yaw,
    required this.roll,
  });

  factory HeadPose.neutral() => const HeadPose(pitch: 0, yaw: 0, roll: 0);
}

/// Снимок детекции лица за один фрейм (30-60 FPS)
class FaceFrameSnapshot {
  final DateTime timestamp;
  final bool hasFace;
  final double confidence;
  final FaceBlendshapeScores blendshapes;
  final GazeVector gaze;
  final HeadPose headPose;

  const FaceFrameSnapshot({
    required this.timestamp,
    required this.hasFace,
    required this.confidence,
    required this.blendshapes,
    required this.gaze,
    required this.headPose,
  });

  factory FaceFrameSnapshot.empty() => FaceFrameSnapshot(
        timestamp: DateTime.now(),
        hasFace: false,
        confidence: 0.0,
        blendshapes: FaceBlendshapeScores.empty(),
        gaze: GazeVector.center(),
        headPose: HeadPose.neutral(),
      );

  factory FaceFrameSnapshot.fromNativeAppleVision(Map<String, dynamic> j) {
    final detected = j['detected'] as bool? ?? false;
    if (!detected) return FaceFrameSnapshot.empty();

    final ear = (j['ear'] as num?)?.toDouble() ?? 0.28;
    final isBlinking = j['isBlinking'] as bool? ?? false;
    final blinkDurationMs = (j['blinkDurationMs'] as num?)?.toDouble() ?? 0.0;
    final isEyeBlocking = j['isEyeBlocking'] as bool? ?? false;

    final gazeX = (j['gazeX'] as num?)?.toDouble() ?? 0.0;
    final gazeY = (j['gazeY'] as num?)?.toDouble() ?? 0.0;

    final browFurrow = (j['browFurrow'] as num?)?.toDouble() ?? 0.0;
    final browRaise = (j['browRaise'] as num?)?.toDouble() ?? 0.0;
    final lipCompression = (j['lipCompression'] as num?)?.toDouble() ?? 0.0;
    final smileAsymmetry = (j['smileAsymmetry'] as num?)?.toDouble() ?? 0.0;
    final noseWrinkle = (j['noseWrinkle'] as num?)?.toDouble() ?? 0.0;

    final headRoll = (j['headRoll'] as num?)?.toDouble() ?? 0.0;
    final headYaw = (j['headYaw'] as num?)?.toDouble() ?? 0.0;
    final headPitch = (j['headPitch'] as num?)?.toDouble() ?? 0.0;
    final isFaceFreezing = j['isFaceFreezing'] as bool? ?? false;

    final direction = _calculateDirection(gazeX, gazeY);

    return FaceFrameSnapshot(
      timestamp: DateTime.now(),
      hasFace: true,
      confidence: 0.95,
      blendshapes: FaceBlendshapeScores({
        'browDownLeft': browFurrow,
        'browDownRight': browFurrow,
        'browInnerUp': browRaise,
        'eyeBlinkLeft': isBlinking ? 1.0 : (1.0 - (ear / 0.3)).clamp(0.0, 1.0),
        'eyeBlinkRight': isBlinking ? 1.0 : (1.0 - (ear / 0.3)).clamp(0.0, 1.0),
        'mouthPressLeft': lipCompression,
        'mouthPressRight': lipCompression,
        'noseSneerLeft': noseWrinkle,
        'noseSneerRight': noseWrinkle,
        'smileAsymmetry': smileAsymmetry,
        'isEyeBlocking': isEyeBlocking ? 1.0 : 0.0,
        'isFaceFreezing': isFaceFreezing ? 1.0 : 0.0,
        'blinkDurationMs': blinkDurationMs,
      }),
      gaze: GazeVector(yaw: gazeX, pitch: gazeY, direction: direction),
      headPose: HeadPose(pitch: headPitch, yaw: headYaw, roll: headRoll),
    );
  }

  static GazeDirectionType _calculateDirection(double x, double y) {
    if (x.abs() < 0.25 && y.abs() < 0.25) return GazeDirectionType.center;
    if (x < -0.35 && y < -0.35) return GazeDirectionType.downLeft;
    if (x > 0.35 && y < -0.35) return GazeDirectionType.downRight;
    if (x < -0.35 && y > 0.35) return GazeDirectionType.upLeft;
    if (x > 0.35 && y > 0.35) return GazeDirectionType.upRight;
    if (y < -0.4) return GazeDirectionType.downCenter;
    if (y > 0.4) return GazeDirectionType.upCenter;
    if (x < -0.4) return GazeDirectionType.left;
    if (x > 0.4) return GazeDirectionType.right;
    return GazeDirectionType.center;
  }
}
