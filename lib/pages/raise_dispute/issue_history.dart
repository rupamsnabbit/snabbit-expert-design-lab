import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/models/issue_data.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/server_requests/raise_dispute_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/error_handler.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/raise_dispute/issue_card.dart'; // Using the intl package for date formatting

// The main widget to display the issue history.
class IssueHistory extends StatefulWidget {
  static const String routeName = '/issue-history';

  const IssueHistory({super.key});

  @override
  State<IssueHistory> createState() => _IssueHistoryState();
}

class _IssueHistoryState extends State<IssueHistory> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<IssueData> _issues = [];
  String _selectedFilter = 'All';
  // cursor-based pagination
  String? _nextPageCursor;
  bool _hasMoreItems = true;
  final ScrollController _scrollController = ScrollController();

  // Filters to display as buttons.
  final List<String> _filters = ['All', 'Open', 'Resolved', 'Rejected', 'Under Review'];
  late LanguageProvider languageProvider;
  bool init = true;
  CustomError? error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Only trigger if we're close to the bottom, not loading more, have more items, and have filtered results
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreItems &&
        _issues.isNotEmpty &&
        _scrollController.position.maxScrollExtent > 0) {
      _fetchMoreIssues();
    }
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      if (_issues.isEmpty) {
        _fetchIssueData();
      }
    }
    super.didChangeDependencies();
  }

  Map<String, dynamic> _buildQueryParams({String? cursor}) {
    return {
      'size': 10, // mirrors leave flow
      'cursor': cursor,
      'status': IssueStatus.fromViewString(_selectedFilter),
    };
  }

  /// Fetches the initial issue data (cursor-based)
  Future<void> _fetchIssueData() async {
    setState(() {
      _isLoading = true;
      _nextPageCursor = null;
      _hasMoreItems = true;
      error = null;
    });

    try {
      final response = await RaiseDisputeHttp.getIssueHistory(
        queryParameters: _buildQueryParams(),
      );
      if (response?.statusCode == 200) {
        final data = response?.data;
        final List<dynamic> itemsJson =
            (data?['items'] ?? data?['issues']) ?? [];
        final List<IssueData> fetchedIssues = itemsJson
            .map<IssueData>((json) => IssueData.fromJson(json))
            .toList();

        setState(() {
          _issues = fetchedIssues;
          _nextPageCursor = data?['next_page'];
          _hasMoreItems = _nextPageCursor != null;
          // _filterIssues(_selectedFilter); // Apply the default filter
        });
      } else {
        if (mounted) {
          ErrorHandler.handleResponseError(
            response: response,
            context: context,
            onError: (context, responseError) {
              if (responseError.errors?.isNotEmpty == true) {
                setState(() {
                  error = responseError.errors?.first;
                });
              }
            },
          );
        }
      }
    } catch (e, _) {
      setState(() {
        _issues = [];
        error = CustomError(
          title: "Something went wrong",
          message: e.toString(),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetches more issues when scrolling to the bottom (cursor-based)
  Future<void> _fetchMoreIssues() async {
    if (_isLoadingMore || !_hasMoreItems) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await RaiseDisputeHttp.getIssueHistory(
        queryParameters: _buildQueryParams(cursor: _nextPageCursor),
      );
      if (response?.statusCode == 200) {
        final data = response?.data;
        final List<dynamic> itemsJson =
            (data?['items'] ?? data?['issues']) ?? [];
        final List<IssueData> fetchedIssues = itemsJson
            .map<IssueData>((json) => IssueData.fromJson(json))
            .toList();

        if (fetchedIssues.isNotEmpty) {
          setState(() {
            _issues.addAll(fetchedIssues);
            _nextPageCursor = data?['next_page'];
            _hasMoreItems = _nextPageCursor != null;
            // _filterIssues(
            //     _selectedFilter); // Reapply filter to include new items
          });
        } else {
          setState(() {
            _hasMoreItems = false;
          });
        }
      }
    } catch (e, _) {
      // Silently handle errors for pagination to avoid disrupting the user experience
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// Refreshes the issue data and resets pagination
  Future<void> _refreshData() async {
    setState(() {
      _issues.clear();
      _nextPageCursor = null;
      _hasMoreItems = true;
    });
    await _fetchIssueData();
  }

  /// Handles filter change and resets pagination if needed
  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    _issues.clear();
    _fetchIssueData();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        elevation: 5.r,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Padding(
              padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title "Issue History"
                  Text(
                    languageProvider.getMessage(
                        'issue_history', 'Issue History'),
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Filter Buttons Row\
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: EdgeInsets.only(right: 8.w),
                            child: GestureDetector(
                              onTap: () => _onFilterChanged(filter),
                              child: Container(
                                height: 25.h,
                                padding: EdgeInsets.symmetric(horizontal: 12.w),
                                decoration: BoxDecoration(
                                  color: isSelected? AppColors.brand : AppColors.n0,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFD8DAE5)
                                        : Colors.transparent,
                                    width: 1.w,
                                  ),
                                  borderRadius: BorderRadius.circular(99.r),
                                ),
                                child: Center(
                                  child: Text(
                                    filter,
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      height: 1.4,
                                      color: isSelected ? AppColors.n0 : const Color(0xFF1D2129),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  SizedBox(height: 16.h),
                  // Issues List
                  if (_issues.isNotEmpty)
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : RefreshIndicator(
                              onRefresh: _refreshData,
                              child: ListView.separated(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _issues.length +
                                    (_hasMoreItems ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _issues.length) {
                                    // Bottom section with loading indicator or end message
                                    return Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 16.h),
                                      child: _isLoadingMore
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : const SizedBox.shrink(),
                                    );
                                  }
                                  return IssueCard(
                                      data: _issues[index]);
                                },
                                separatorBuilder: (context, index) {
                                  if (index == _issues.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return SizedBox(height: 16.h);
                                },
                              ),
                            ),
                    )
                    else if (error != null)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment:
                          CrossAxisAlignment.center, // align left
                          children: [
                            SizedBox(
                              height: 36.h,
                            ),
                            Flexible(
                              child: Text(
                                error?.title ?? '',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall, // title style
                              ),
                            ),
                            const SizedBox(height: 4),
                            Flexible(
                              child: Text(
                                error?.message ?? '',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium, // subtitle style
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!_isLoading && _issues.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              languageProvider.getMessage(
                                  'no_issues_found', 'No issues found'),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppColors.n70,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
