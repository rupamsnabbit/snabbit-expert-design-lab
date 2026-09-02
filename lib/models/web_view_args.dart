class WebViewArgs {
  final String url;
  final String title;
  final bool fetchLocation;
  final void Function()? onPageLoaded;
  final void Function(String reason)? onPageLoadFailed;
  final void Function(String url, bool success)? onExternalUrlOpened;

  /// Re-fetch `current_state` when this webview closes. Set by entry points
  /// whose page can mutate server state the home renders from (the lunch-slots
  /// page changes the runner's slot selection, which drives
  /// `show_lunch_selection`), so the home isn't left showing stale state until
  /// the next poll. Cohort-aware: see
  /// `RunnerRtDataProvider.refreshCurrentStateAfterWebview`.
  final bool refreshCurrentStateOnClose;

  const WebViewArgs({
    required this.url,
    required this.title,
    this.fetchLocation = false,
    this.refreshCurrentStateOnClose = false,
    this.onPageLoaded,
    this.onPageLoadFailed,
    this.onExternalUrlOpened,
  });
}
