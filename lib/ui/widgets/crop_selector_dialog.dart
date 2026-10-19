import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/window_service.dart';
import '../../session.dart';
import '../theme.dart';

/// Диалог интерактивного выбора области экрана (Crop Box) для анализа оппонента в звонке
class CropSelectorDialog extends StatefulWidget {
  const CropSelectorDialog({super.key, required this.session});

  final Session session;

  static Future<void> show(BuildContext context, Session session) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CropSelectorDialog(session: session),
    );
  }

  @override
  State<CropSelectorDialog> createState() => _CropSelectorDialogState();
}

class _CropSelectorDialogState extends State<CropSelectorDialog> {
  Uint8List? _screenSnapshot;
  bool _loading = true;
  String? _error;

  // Координаты рамки кропа в относительных долях (0.0 .. 1.0)
  Rect _normRect = const Rect.fromLTWH(0.25, 0.20, 0.50, 0.50);

  @override
  void initState() {
    super.initState();
    _takeSnapshot();
  }

  Future<void> _takeSnapshot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await WindowService.captureScreen();
      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          _screenSnapshot = bytes;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Не удалось захватить экран. Проверьте права «Запись экрана».';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка захвата: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Palette.bg.withValues(alpha: 0.95),
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Palette.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Шапка
              Row(
                children: [
                  const Icon(Icons.crop_free, size: 18, color: Palette.them),
                  const SizedBox(width: 8),
                  const Text(
                    'Выбор области лица (Screen Crop)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Palette.pri,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18, color: Palette.sec),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Перетащите зеленую рамку на лицо оппонента (в окне Zoom, YouTube, Meet или Photo Booth).',
                style: TextStyle(fontSize: 12, color: Palette.sec),
              ),
              const SizedBox(height: 12),

              // Область предпросмотра со скриншотом и интерактивной рамкой
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Palette.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildPreviewArea(),
                ),
              ),

              const SizedBox(height: 12),
              // Нижняя панель действий
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _takeSnapshot,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Обновить снимок', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Palette.sec,
                      side: const BorderSide(color: Palette.border),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена', style: TextStyle(color: Palette.sec, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _screenSnapshot != null ? _applyCrop : null,
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Зафиксировать область', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: Palette.them),
            SizedBox(height: 12),
            Text('Захват экрана...', style: TextStyle(fontSize: 12, color: Palette.sec)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 28, color: Palette.red),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12, color: Palette.pri)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _takeSnapshot,
              child: const Text('Повторить попытку'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final rectPx = Rect.fromLTWH(
          _normRect.left * w,
          _normRect.top * h,
          _normRect.width * w,
          _normRect.height * h,
        );

        return Stack(
          children: [
            // Изображение всего экрана
            Positioned.fill(
              child: Image.memory(
                _screenSnapshot!,
                fit: BoxFit.fill,
              ),
            ),

            // Полупрозрачное затемнение вокруг выбранной области
            Positioned.fill(
              child: CustomPaint(
                painter: _DimOverlayPainter(selectionRect: rectPx),
              ),
            ),

            // Интерактивная рамка выбора
            Positioned(
              left: rectPx.left,
              top: rectPx.top,
              width: rectPx.width,
              height: rectPx.height,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    final newLeft = (_normRect.left + details.delta.dx / w).clamp(0.0, 1.0 - _normRect.width);
                    final newTop = (_normRect.top + details.delta.dy / h).clamp(0.0, 1.0 - _normRect.height);
                    _normRect = Rect.fromLTWH(newLeft, newTop, _normRect.width, _normRect.height);
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Palette.green, width: 2),
                    color: Palette.green.withValues(alpha: 0.12),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(Icons.face, size: 32, color: Palette.green),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              final newW = (_normRect.width + details.delta.dx / w).clamp(0.1, 1.0 - _normRect.left);
                              final newH = (_normRect.height + details.delta.dy / h).clamp(0.1, 1.0 - _normRect.top);
                              _normRect = Rect.fromLTWH(_normRect.left, _normRect.top, newW, newH);
                            });
                          },
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Palette.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.aspect_ratio, size: 11, color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _applyCrop() {
    double screenW = 1920.0;
    double screenH = 1080.0;
    try {
      final view = View.of(context);
      final dpr = view.display.devicePixelRatio;
      if (view.display.size.width > 0 && dpr > 0) {
        screenW = view.display.size.width / dpr;
        screenH = view.display.size.height / dpr;
      }
    } catch (_) {}

    final pixelRect = Rect.fromLTWH(
      _normRect.left * screenW,
      _normRect.top * screenH,
      _normRect.width * screenW,
      _normRect.height * screenH,
    );

    widget.session.setCropRect(pixelRect);
    widget.session.setVisionMode(VisionMode.screenCrop);
    if (!widget.session.isCropAnalyzing) {
      widget.session.toggleCropAnalysis();
    }
    Navigator.of(context).pop();
  }
}

class _DimOverlayPainter extends CustomPainter {
  final Rect selectionRect;

  _DimOverlayPainter({required this.selectionRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final path = Path()
      ..addRect(fullRect)
      ..addRect(selectionRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DimOverlayPainter oldDelegate) =>
      oldDelegate.selectionRect != selectionRect;
}
