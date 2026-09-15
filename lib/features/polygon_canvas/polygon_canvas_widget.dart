import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/utils/geometry.dart';
import '../../core/widgets/app_image_view.dart';
import '../../models/polygon_region.dart';
import 'polygon_painter.dart';

enum CanvasMode { view, draw, edit, highlight }

class PolygonCanvasWidget extends StatefulWidget {
  final String? imageUrl;
  final List<PolygonRegion> regions;
  final String? highlightedRegionId;
  final CanvasMode mode;
  final List<NormalizedPoint>? focusPolygon;
  final Rect? targetFocusBounds;
  final bool initialSnappingEnabled;
  final ValueChanged<bool>? onSnappingChanged;
  final void Function(PolygonRegion region)? onRegionTapped;
  final void Function(List<NormalizedPoint> points)? onPolygonCompleted;
  final VoidCallback? onCancelDrawing;
  final void Function(PolygonRegion region)? onDeleteRegion;
  final void Function(PolygonRegion region, String newLabel)? onRenameRegion;
  final void Function(PolygonRegion updatedRegion)? onRegionUpdated;
  final VoidCallback? onSaveEditSession;

  const PolygonCanvasWidget({
    super.key,
    required this.imageUrl,
    required this.regions,
    this.highlightedRegionId,
    this.mode = CanvasMode.view,
    this.focusPolygon,
    this.targetFocusBounds,
    this.initialSnappingEnabled = true,
    this.onSnappingChanged,
    this.onRegionTapped,
    this.onPolygonCompleted,
    this.onCancelDrawing,
    this.onDeleteRegion,
    this.onRenameRegion,
    this.onRegionUpdated,
    this.onSaveEditSession,
  });

  @override
  State<PolygonCanvasWidget> createState() => _PolygonCanvasWidgetState();
}

class _PolygonCanvasWidgetState extends State<PolygonCanvasWidget>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  final List<NormalizedPoint> _draftPoints = [];
  NormalizedPoint? _draftCursorPoint;
  String? _selectedRegionId;
  late List<PolygonRegion> _activeRegions;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late bool _snappingEnabled;
  double? _imageAspectRatio;
  bool _isZoomedIntoFocus = false;
  Rect? _activeFocusBounds;

  // Vertex Dragging & Edit Mode State
  bool _isDrawingActive = false;
  int? _activeDragVertexIndex;

  @override
  void initState() {
    super.initState();
    _snappingEnabled = widget.initialSnappingEnabled;
    _activeRegions = List.from(widget.regions);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _resolveImageDimensions();
    _checkFocusBounds();
  }

  @override
  void didUpdateWidget(covariant PolygonCanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolveImageDimensions();
    }
    if (oldWidget.focusPolygon != widget.focusPolygon ||
        oldWidget.targetFocusBounds != widget.targetFocusBounds) {
      _checkFocusBounds();
    }
    if (oldWidget.regions != widget.regions) {
      setState(() {
        _activeRegions = List.from(widget.regions);
        // Clear selection if selected region no longer exists
        if (_selectedRegionId != null &&
            !_activeRegions.any((r) => r.id == _selectedRegionId)) {
          _selectedRegionId = null;
        }
      });
    }
    if (oldWidget.mode != widget.mode) {
      setState(() {
        _isDrawingActive = widget.mode == CanvasMode.draw;
        if (widget.mode == CanvasMode.view) {
          _selectedRegionId = null;
          _activeDragVertexIndex = null;
          _draftPoints.clear();
        }
      });
    }
  }

  void _resolveImageDimensions() {
    if (widget.imageUrl == null || widget.imageUrl!.trim().isEmpty) {
      setState(() => _imageAspectRatio = 16 / 9);
      return;
    }

    try {
      final url = widget.imageUrl!.trim();
      ImageProvider provider;
      if (url.startsWith('data:image/') || url.contains(';base64,')) {
        final commaIdx = url.indexOf(',');
        final base64Data = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        provider = MemoryImage(base64Decode(base64Data));
      } else {
        provider = NetworkImage(url);
      }

      final configuration = ImageConfiguration.empty;
      provider.resolve(configuration).addListener(
        ImageStreamListener(
          (ImageInfo info, bool _) {
            if (mounted) {
              final w = info.image.width.toDouble();
              final h = info.image.height.toDouble();
              if (h > 0) {
                setState(() {
                  _imageAspectRatio = w / h;
                });
              }
            }
          },
          onError: (error, stackTrace) {
            if (mounted) {
              setState(() => _imageAspectRatio = 16 / 9);
            }
          },
        ),
      );
    } catch (_) {
      setState(() => _imageAspectRatio = 16 / 9);
    }
  }

  void _checkFocusBounds() {
    Rect? bounds = widget.targetFocusBounds;
    if (bounds == null && widget.focusPolygon != null && widget.focusPolygon!.isNotEmpty) {
      bounds = GeometryUtils.calculateBoundingBox(widget.focusPolygon!);
    }
    _activeFocusBounds = bounds;

    if (bounds != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _zoomToFocusBounds(bounds!);
      });
    }
  }

  void _zoomToFocusBounds(Rect bounds) {
    // Zoom in using transformationController
    final fitMatrix = GeometryUtils.calculateFitMatrix(bounds, const Size(1, 1));
    _transformController.value = fitMatrix;
    setState(() {
      _isZoomedIntoFocus = true;
    });
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _isZoomedIntoFocus = false;
    });
  }

  void _toggleFocusZoom() {
    if (_isZoomedIntoFocus) {
      _resetZoom();
    } else if (_activeFocusBounds != null) {
      _zoomToFocusBounds(_activeFocusBounds!);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  int? _hitTestVertex(Offset localPosition, Size canvasSize) {
    if (_selectedRegionId == null) return null;
    final regionIdx = _activeRegions.indexWhere((r) => r.id == _selectedRegionId);
    if (regionIdx == -1) return null;
    final points = _activeRegions[regionIdx].points;
    for (int i = 0; i < points.length; i++) {
      final vertexOffset = points[i].toOffset(canvasSize);
      if ((localPosition - vertexOffset).distance <= 24.0) {
        return i;
      }
    }
    return null;
  }

  void _handleTapUp(TapUpDetails details, Size renderSize) {
    if (renderSize.width <= 0 || renderSize.height <= 0) return;

    final localPosition = details.localPosition;
    var normalized = NormalizedPoint.fromOffset(localPosition, renderSize);

    final isDrawingMode = widget.mode == CanvasMode.draw ||
        (widget.mode == CanvasMode.edit && _isDrawingActive);

    if (isDrawingMode) {
      if (_snappingEnabled) {
        // 1. Vertex Snapping: collect all vertices in existing regions + previous draft points
        final candidateVertices = <NormalizedPoint>[
          for (final reg in _activeRegions) ...reg.points,
          ..._draftPoints,
        ];

        normalized = GeometryUtils.snapNormalizedToNearestVertex(
          normalized,
          candidateVertices,
          snapThreshold: 0.035,
        );

        // 2. Angle Snapping: snap relative to the previous point in draft
        if (_draftPoints.isNotEmpty) {
          normalized = GeometryUtils.snapNormalizedAngle(
            _draftPoints.last,
            normalized,
            toleranceDegrees: 10.0,
          );
        }
      }

      setState(() {
        _draftPoints.add(normalized);
      });
    } else {
      // Hit-test existing polygons
      PolygonRegion? hitRegion;
      for (final region in _activeRegions.reversed) {
        final offsets =
            region.points.map((p) => p.toOffset(renderSize)).toList();
        if (GeometryUtils.isPointInPolygon(localPosition, offsets)) {
          hitRegion = region;
          break;
        }
      }

      setState(() {
        _selectedRegionId = hitRegion?.id;
        _activeDragVertexIndex = null;
      });

      if (hitRegion != null &&
          widget.mode == CanvasMode.view &&
          widget.onRegionTapped != null) {
        widget.onRegionTapped!(hitRegion);
      }
    }
  }

  void _finishDrawing() {
    if (_draftPoints.length >= 3) {
      final completed = List<NormalizedPoint>.from(_draftPoints);
      setState(() {
        _draftPoints.clear();
        _draftCursorPoint = null;
        _isDrawingActive = false;
        _selectedRegionId = null;
        _activeDragVertexIndex = null;
      });
      widget.onPolygonCompleted?.call(completed);
    }
  }

  void _undoLastPoint() {
    if (_draftPoints.isNotEmpty) {
      setState(() {
        _draftPoints.removeLast();
      });
    }
  }

  void _cancelDrawing() {
    setState(() {
      _draftPoints.clear();
      _draftCursorPoint = null;
      _isDrawingActive = false;
    });
    widget.onCancelDrawing?.call();
  }

  void _toggleSnapping() {
    setState(() {
      _snappingEnabled = !_snappingEnabled;
    });
    widget.onSnappingChanged?.call(_snappingEnabled);
  }

  Future<void> _handleRenameSelectedRegion() async {
    if (_selectedRegionId == null) return;
    final region = _activeRegions.firstWhere((r) => r.id == _selectedRegionId);
    final textController = TextEditingController(text: region.label);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Rename Polygon', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Polygon Label',
            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != region.label) {
      final regionIdx = _activeRegions.indexWhere((r) => r.id == _selectedRegionId);
      if (regionIdx != -1) {
        final updated = _activeRegions[regionIdx].copyWith(label: newName);
        setState(() {
          _activeRegions[regionIdx] = updated;
        });
        widget.onRenameRegion?.call(region, newName);
        widget.onRegionUpdated?.call(updated);
      }
    }
  }

  void _handleDeleteSelectedRegion() {
    if (_selectedRegionId == null) return;
    final region = _activeRegions.firstWhere((r) => r.id == _selectedRegionId);
    widget.onDeleteRegion?.call(region);
  }

  void _handleCommitSelectedRegion() {
    if (_selectedRegionId == null) return;
    final regionIdx = _activeRegions.indexWhere((r) => r.id == _selectedRegionId);
    if (regionIdx != -1) {
      final updated = _activeRegions[regionIdx];
      widget.onRegionUpdated?.call(updated);
    }
    setState(() {
      _selectedRegionId = null;
      _activeDragVertexIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAspectRatio = _imageAspectRatio ?? 16 / 9;
    final isDrawingMode = widget.mode == CanvasMode.draw ||
        (widget.mode == CanvasMode.edit && _isDrawingActive);
    final isEditMode = widget.mode == CanvasMode.edit;

    return Column(
      children: [
        // Mode Banner / Toolbar when in Drawing Mode
        if (widget.mode == CanvasMode.draw)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(Icons.gesture, color: Color(0xFF6366F1), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Tap to place points (${_draftPoints.length} added)',
                  style:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                // Snapping toggle button in toolbar
                IconButton(
                  tooltip: _snappingEnabled
                      ? 'Snapping: ON (45° / Vertices)'
                      : 'Snapping: OFF',
                  icon: Icon(
                    Icons.straighten,
                    size: 20,
                    color: _snappingEnabled
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF64748B),
                  ),
                  onPressed: _toggleSnapping,
                ),
                IconButton(
                  tooltip: 'Undo point',
                  icon: const Icon(Icons.undo, size: 20),
                  onPressed: _draftPoints.isNotEmpty ? _undoLastPoint : null,
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Complete'),
                  onPressed: _draftPoints.length >= 3 ? _finishDrawing : null,
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _cancelDrawing,
                ),
              ],
            ),
          ),

        // Main Interactive Canvas
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformController,
            panEnabled: _activeDragVertexIndex == null,
            scaleEnabled: _activeDragVertexIndex == null,
            minScale: 0.5,
            maxScale: 6.0,
            boundaryMargin: const EdgeInsets.all(40),
            child: Center(
              child: AspectRatio(
                aspectRatio: effectiveAspectRatio,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvasSize =
                        Size(constraints.maxWidth, constraints.maxHeight);

                    return Listener(
                      onPointerDown: (event) {
                        if (_selectedRegionId != null && !isDrawingMode) {
                          final hit = _hitTestVertex(event.localPosition, canvasSize);
                          if (hit != null) {
                            setState(() {
                              _activeDragVertexIndex = hit;
                            });
                          }
                        }
                      },
                      onPointerUp: (_) {
                        if (_activeDragVertexIndex != null) {
                          setState(() {
                            _activeDragVertexIndex = null;
                          });
                        }
                      },
                      onPointerCancel: (_) {
                        if (_activeDragVertexIndex != null) {
                          setState(() {
                            _activeDragVertexIndex = null;
                          });
                        }
                      },
                      child: GestureDetector(
                        onTapUp: (details) => _handleTapUp(details, canvasSize),
                        onPanUpdate: (details) {
                          if (_activeDragVertexIndex != null && _selectedRegionId != null) {
                            final regionIdx = _activeRegions.indexWhere((r) => r.id == _selectedRegionId);
                            if (regionIdx != -1) {
                              var normalized = NormalizedPoint.fromOffset(details.localPosition, canvasSize);
                              normalized = NormalizedPoint(
                                x: normalized.x.clamp(0.0, 1.0),
                                y: normalized.y.clamp(0.0, 1.0),
                              );

                              if (_snappingEnabled) {
                                final region = _activeRegions[regionIdx];
                                final candidateVertices = <NormalizedPoint>[
                                  for (int r = 0; r < _activeRegions.length; r++)
                                    for (int p = 0; p < _activeRegions[r].points.length; p++)
                                      if (r != regionIdx || p != _activeDragVertexIndex)
                                        _activeRegions[r].points[p],
                                ];

                                normalized = GeometryUtils.snapNormalizedToNearestVertex(
                                  normalized,
                                  candidateVertices,
                                  snapThreshold: 0.035,
                                );

                                final n = region.points.length;
                                final prevIndex = (_activeDragVertexIndex! - 1 + n) % n;
                                normalized = GeometryUtils.snapNormalizedAngle(
                                  region.points[prevIndex],
                                  normalized,
                                  toleranceDegrees: 10.0,
                                );
                              }

                              final updatedPoints = List<NormalizedPoint>.from(_activeRegions[regionIdx].points);
                              updatedPoints[_activeDragVertexIndex!] = normalized;

                              setState(() {
                                _activeRegions[regionIdx] = _activeRegions[regionIdx].copyWith(points: updatedPoints);
                              });
                            }
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            // Base Image (fill aspect ratio container exactly)
                            AppImageView(
                              imageUrl: widget.imageUrl,
                              fit: BoxFit.fill,
                              borderRadius: BorderRadius.circular(8),
                              fallbackWidget: _buildFallbackPlaceholder(),
                            ),

                            // Animated Polygon Painter Layer
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, _) {
                                return CustomPaint(
                                  size: canvasSize,
                                  painter: PolygonPainter(
                                    regions: _activeRegions,
                                    highlightedRegionId:
                                        widget.highlightedRegionId,
                                    selectedRegionId: _selectedRegionId,
                                    draftPoints: _draftPoints,
                                    draftCursorPoint: _draftCursorPoint,
                                    pulseAnimationValue: _pulseAnimation.value,
                                    isDrawing: isDrawingMode,
                                    activeVertexIndex: _activeDragVertexIndex,
                                  ),
                                );
                              },
                            ),

                            // On-Canvas Floating Controls (Snapping & Compass/Viewport Zoom)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Snapping Quick Indicator/Toggle - only visible in draw or edit mode
                                  if (widget.mode == CanvasMode.draw || widget.mode == CanvasMode.edit)
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: _toggleSnapping,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A)
                                                .withValues(alpha: 0.85),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: _snappingEnabled
                                                  ? const Color(0xFF38BDF8)
                                                  : const Color(0xFF334155),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.straighten,
                                                size: 14,
                                                color: _snappingEnabled
                                                    ? const Color(0xFF38BDF8)
                                                    : const Color(0xFF94A3B8),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _snappingEnabled
                                                    ? 'Snap: ON'
                                                    : 'Snap: OFF',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _snappingEnabled
                                                      ? const Color(0xFF38BDF8)
                                                      : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Mini-Compass / Focus Viewport Reset Toggle
                                  if (_activeFocusBounds != null) ...[
                                    const SizedBox(width: 8),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: _toggleFocusZoom,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A)
                                                .withValues(alpha: 0.85),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: _isZoomedIntoFocus
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _isZoomedIntoFocus
                                                    ? Icons.zoom_out_map
                                                    : Icons.center_focus_strong,
                                                size: 14,
                                                color: _isZoomedIntoFocus
                                                    ? const Color(0xFF10B981)
                                                    : Colors.white,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _isZoomedIntoFocus
                                                    ? 'Full View'
                                                    : 'Focus Area',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _isZoomedIntoFocus
                                                      ? const Color(0xFF10B981)
                                                      : Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],

                                  // Floating Save Button in Edit Mode (visible whenever not mid-draft so user can exit)
                                  if (isEditMode && _draftPoints.isEmpty && _selectedRegionId == null) ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        elevation: 4,
                                      ),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text(
                                        'Save',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      onPressed: () {
                                        widget.onSaveEditSession?.call();
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Floating Drawing Tool Palette with Undo, Save, and Delete options
                            if (isDrawingMode && _draftPoints.isNotEmpty)
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 16,
                                child: _buildDrawingToolPalette(),
                              ),

                            // Bottom-Right Floating Edit Tool Palette
                            if (isEditMode && _draftPoints.isEmpty)
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: _buildEditToolPalette(),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditToolPalette() {
    if (_selectedRegionId != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF818CF8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFF87171), size: 22),
              tooltip: 'Delete mapping or item',
              onPressed: _handleDeleteSelectedRegion,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_note, color: Color(0xFF38BDF8), size: 24),
              tooltip: 'Rename polygon',
              onPressed: _handleRenameSelectedRegion,
            ),
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _handleCommitSelectedRegion,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 18, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isDrawingActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 18, color: Color(0xFF818CF8)),
            SizedBox(width: 8),
            Text(
              'Tap photo to draw next polygon',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return FloatingActionButton.extended(
      heroTag: 'add_polygon_fab',
      backgroundColor: const Color(0xFF6366F1),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add, size: 20),
      label: const Text('New Polygon', style: TextStyle(fontWeight: FontWeight.bold)),
      onPressed: () {
        setState(() {
          _isDrawingActive = true;
          _draftPoints.clear();
        });
      },
    );
  }

  Widget _buildDrawingToolPalette() {
    final canSave = _draftPoints.length >= 3;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Points counter badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_draftPoints.length} ${_draftPoints.length == 1 ? "pt" : "pts"}',
                style: const TextStyle(
                  color: Color(0xFF818CF8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 1. Undo option
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.undo, size: 16, color: Color(0xFF38BDF8)),
              label: const Text('Undo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: _undoLastPoint,
            ),
            const SizedBox(width: 4),

            // 2. Delete / Discard draft option
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF87171),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFF87171)),
              label: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: _cancelDrawing,
            ),
            const SizedBox(width: 6),

            // 3. Save / Complete polygon option
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: canSave ? const Color(0xFF10B981) : const Color(0xFF334155),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: canSave ? _finishDrawing : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF131B2E), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF263352)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.image_outlined, size: 48, color: Color(0xFF64748B)),
            SizedBox(height: 8),
            Text(
              'No photo attached yet',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
