import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart'
    show RcmdVideoItemAppModel;
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

class RcmdController extends CommonListController {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  final bool appRcmd = Pref.appRcmd;

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;

  /// ponytail: App 端推荐的单次返回条数由服务端写死 —— 实测 phone 参数下固定 10 条，
  /// 且 `ps` / `page_size` / `limit` / `count` 之类的条数参数**一律被忽略**
  /// （`device`/`column`/`flush` 也不影响条数）。所以想凑够用户设定的条数，
  /// 只能连续取几批再合并。这个循环上限是防呆，正常 2 批就够（17 条设定值时）。
  static const int _maxAppBatches = 3;

  /// ponytail: 客户端还会过滤掉广告/直播/拉黑/分区视频与用户自定义屏蔽词，
  /// 服务端给的原始条目未必条条可用，所以多要几条抵消损耗。
  static const int _filterSlack = 3;

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    queryData();
  }

  @override
  Future<LoadingState> customGetData() async {
    final int want = Pref.refreshCount;

    if (!appRcmd) {
      // Web 端推荐接口尊重 ps（实测 ps=N 就返回 N 条），一次请求即可
      return VideoHttp.rcmdVideoList(
        freshIdx: page,
        ps: want + _filterSlack,
      );
    }

    // 同一 freshIdx 重复请求会返回**互不重复**的新推荐（实测 4 次 40 条零重叠），
    // 因此这里重复取同一 page，既能凑数，也不会和上拉加载的 idx 语义打架。
    final list = <RcmdVideoItemAppModel>[];
    final seen = <int?>{};
    for (int i = 0; i < _maxAppBatches && list.length < want; i++) {
      final res = await VideoHttp.rcmdVideoListApp(freshIdx: page);
      if (res is! Success<List<RcmdVideoItemAppModel>>) {
        // 一条都没拿到 → 原样上报错误；已拿到若干条 → 用手上的，不让整次刷新失败
        if (list.isEmpty) return res;
        break;
      }
      final batch = res.response;
      if (batch.isEmpty) break;
      for (final e in batch) {
        if (seen.add(e.id)) list.add(e);
      }
    }
    if (list.length > want) list.removeRange(want, list.length);
    return Success(list);
  }

  @override
  bool handleError(String? errMsg) {
    return enableSaveLastData;
  }

  @override
  void handleListResponse(List dataList) {
    if (enableSaveLastData && page == 0) {
      if (loadingState.value case Success(:final response)) {
        if (response != null && response.isNotEmpty) {
          if (savedRcmdTip) {
            lastRefreshAt = dataList.length;
          }
          if (response.length > 200) {
            dataList.addAll(response.take(50));
          } else {
            dataList.addAll(response);
          }
        }
      }
    }
  }

  @override
  Future<void> onRefresh() {
    page = 0;
    isEnd = false;
    return queryData();
  }
}
