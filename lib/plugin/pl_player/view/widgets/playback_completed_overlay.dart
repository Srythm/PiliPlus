import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PlaybackCompletedOverlay extends StatelessWidget {
  final PlPlayerController plPlayerController;
  final bool isPortrait;

  const PlaybackCompletedOverlay({
    super.key,
    required this.plPlayerController,
    required this.isPortrait,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ponytail: full-area dim, same alpha family as other pl_player overlays (0.6 keeps finished state readable without crushing the thumbnail)
        const Positioned.fill(
          child: ColoredBox(color: Color(0x99000000)),
        ),
        Positioned.fill(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '视频已播放完成',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: plPlayerController.onDoubleTapCenter,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(CustomIcons.replay_rounded, size: 18),
                  label: const Text(
                    '重新播放',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isPortrait) _buildTopLeftButtons(),
      ],
    );
  }

  Widget _buildTopLeftButtons() {
    // 与播放控件顶部按钮 (pages/video/widgets/header_control.dart) 对齐:
    // 尺寸 42x34、垂直内边距 12,水平安全区由 ViewSafeArea 提供。
    // 这里不加 Positioned 的 hardcoded 偏移,也不加顶部安全区 —— 控件那边
    // 由 AppBarAni 只传 left/right,top 不叠加,保持两者纵向一致。
    const btnWidth = 42.0;
    const btnHeight = 34.0;
    const btnStyle = ButtonStyle(padding: WidgetStatePropertyAll(.zero));
    return Positioned.fill(
      child: Align(
        alignment: Alignment.topLeft,
        child: ViewSafeArea(
          top: false,
          left: true,
          right: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: btnWidth,
                  height: btnHeight,
                  child: IconButton(
                    tooltip: '返回',
                    style: btnStyle,
                    icon: const Icon(
                      FontAwesomeIcons.arrowLeft,
                      size: 15,
                      color: Colors.white,
                    ),
                    onPressed: () =>
                        plPlayerController.onPopInvokedWithResult(false, null),
                  ),
                ),
                SizedBox(
                  width: btnWidth,
                  height: btnHeight,
                  child: IconButton(
                    tooltip: '返回主页',
                    style: btnStyle,
                    icon: const Icon(
                      FontAwesomeIcons.house,
                      size: 15,
                      color: Colors.white,
                    ),
                    onPressed: plPlayerController.onCloseAll,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
