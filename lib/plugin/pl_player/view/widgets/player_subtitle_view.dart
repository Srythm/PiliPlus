import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerSubtitleView extends StatefulWidget {
  const PlayerSubtitleView({
    super.key,
    required this.controller,
    required this.configuration,
    this.backgroundColor,
    this.enableDragSubtitle = false,
    this.onUpdatePadding,
  });

  final VideoController controller;
  final SubtitleViewConfiguration configuration;
  final Color? backgroundColor;
  final bool enableDragSubtitle;
  final ValueChanged<EdgeInsets>? onUpdatePadding;

  @override
  State<PlayerSubtitleView> createState() => _PlayerSubtitleViewState();
}

class _PlayerSubtitleViewState extends State<PlayerSubtitleView> {
  late Subtitle _subtitle = widget.controller.player.state.subtitle;
  late EdgeInsets _padding = widget.configuration.padding;
  final Duration _duration = const Duration(milliseconds: 100);
  StreamSubscription<Subtitle>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.player.stream.subtitle.listen((value) {
      setState(() => _subtitle = value);
    });
  }

  @override
  void didUpdateWidget(PlayerSubtitleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _padding = widget.configuration.padding;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Widget _buildText(TextStyle style) => Text(
    _subtitle.toString(),
    style: style,
    textAlign: widget.configuration.textAlign,
    textScaler: TextScaler.noScaling,
  );

  Widget _buildSubtitle() {
    final Widget text;
    if (widget.configuration.strokeStyle case final strokeStyle?) {
      text = Stack(
        clipBehavior: Clip.none,
        children: [
          _buildText(strokeStyle),
          _buildText(widget.configuration.style),
        ],
      );
    } else {
      text = _buildText(widget.configuration.style);
    }

    if (widget.backgroundColor case final backgroundColor?) {
      return ColoredBox(color: backgroundColor, child: text);
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildSubtitle();
    return AnimatedContainer(
      margin: _padding,
      duration: _duration,
      alignment: Alignment.bottomCenter,
      child: widget.enableDragSubtitle
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                final bottom = clampDouble(
                  _padding.bottom - details.delta.dy,
                  0,
                  200,
                );
                setState(() {
                  _padding = _padding.copyWith(bottom: bottom);
                });
              },
              onVerticalDragEnd: (_) {
                widget.onUpdatePadding?.call(_padding);
              },
              child: subtitle,
            )
          : subtitle,
    );
  }
}
