import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/rcmd/widgets/divider_with_text.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class RcmdPage extends StatefulWidget {
  const RcmdPage({super.key});

  @override
  State<RcmdPage> createState() => _RcmdPageState();
}

class _RcmdPageState extends State<RcmdPage>
    with AutomaticKeepAliveClientMixin {
  final controller = Get.put(RcmdController());

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    return Container(
      clipBehavior: .hardEdge,
      margin: const .symmetric(horizontal: Style.safeSpace),
      decoration: const BoxDecoration(borderRadius: Style.mdRadius),
      child: refreshIndicator(
        onRefresh: controller.onRefresh,
        child: CustomScrollView(
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const .only(top: Style.cardSpace, bottom: 100),
              sliver: Obx(
                () => _buildBody(colorScheme, controller.loadingState.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  late final gridDelegate = SliverGridDelegateWithExtentAndRatio(
    mainAxisSpacing: Style.cardSpace,
    crossAxisSpacing: Style.cardSpace,
    maxCrossAxisExtent: Pref.recommendCardWidth,
    childAspectRatio: Style.aspectRatio,
    mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
  );

  Widget _buildBody(
    ColorScheme colorScheme,
    LoadingState<List<dynamic>?> loadingState,
  ) {
    return switch (loadingState) {
      Loading() => _buildSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? _buildSlivers(colorScheme, response)
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget _buildSlivers(ColorScheme colorScheme, List response) {
    final lastRefreshAt = controller.lastRefreshAt;
    final hasNew = lastRefreshAt != null && lastRefreshAt > 0;
    final hasOld = lastRefreshAt == null || lastRefreshAt < response.length;
    return SliverMainAxisGroup(
      slivers: [
        if (hasNew)
          SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemCount: lastRefreshAt,
            itemBuilder: (context, index) => VideoCardV(
              videoItem: response[index],
              onRemove: () {
                controller.lastRefreshAt = lastRefreshAt - 1;
                controller.loadingState
                  ..value.data!.removeAt(index)
                  ..refresh();
              },
            ),
          ),
        if (hasNew && hasOld)
          SliverToBoxAdapter(
            child: DividerWithText(
              text: '上次看到这里 · 点击刷新',
              icon: Icons.history,
              onTap: () => controller
                ..animateToTop()
                ..onRefresh(),
            ),
          ),
        if (hasOld)
          SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemCount: response.length - (lastRefreshAt ?? 0),
            itemBuilder: (context, index) {
              if (index == response.length - (lastRefreshAt ?? 0) - 1) {
                controller.onLoadMore();
              }
              final actualIndex = (lastRefreshAt ?? 0) + index;
              return VideoCardV(
                videoItem: response[actualIndex],
                onRemove: () => controller.loadingState
                  ..value.data!.removeAt(actualIndex)
                  ..refresh(),
              );
            },
          ),
      ],
    );
  }

  Widget get _buildSkeleton => SliverGrid(
    gridDelegate: gridDelegate,
    delegate: SliverSingleChildDelegate(
      count: Pref.refreshCount,
      child: const VideoCardVSkeleton(),
    ),
  );
}
