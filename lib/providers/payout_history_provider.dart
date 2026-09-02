import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/payout/bank_account.dart';
import 'package:snabbit_runner/models/payout/payout_history_response.dart';
import 'package:snabbit_runner/models/payout/transaction.dart';
import 'package:snabbit_runner/models/payout/transaction_type.dart';
import 'package:snabbit_runner/models/payout/upi_account.dart';
import 'package:snabbit_runner/services/server_requests/payout_history_http.dart';

/// Provider class to manage payout history state and data
class PayoutHistoryProvider with ChangeNotifier {
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  PayoutHistoryResponse? _payoutHistoryData;
  PayoutHistoryFilter _selectedFilter = PayoutHistoryFilter.all;

  // Cursor-based pagination
  String? _nextPageCursor;
  bool _hasMoreItems = true;
  List<Transaction> _allTransactions = [];
  List<TransactionType>? _transactionTypes;
  List<BankAccount>? _bankAccounts;
  List<UpiAccount>? _upiAccounts;

  /// Loading state indicator
  bool get loading => _loading;

  /// Loading more items indicator
  bool get loadingMore => _loadingMore;

  /// Error message if any
  String? get error => _error;

  /// The payout history data
  PayoutHistoryResponse? get payoutHistoryData => _payoutHistoryData;

  /// Currently selected filter tab
  PayoutHistoryFilter get selectedFilter => _selectedFilter;

  /// Next page cursor for pagination
  String? get nextPageCursor => _nextPageCursor;

  /// Whether there are more items to load
  bool get hasMoreItems => _hasMoreItems;

  List<BankAccount> get bankAccounts => _bankAccounts ?? [];
  List<UpiAccount> get upiAccounts => _upiAccounts ?? [];

  /// Sets the selected filter tab
  void setSelectedFilter(PayoutHistoryFilter filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  /// Builds query parameters for API request
  Map<String, dynamic> _buildQueryParams(
      {String? cursor, PayoutHistoryFilter? filter}) {
    final Map<String, dynamic> params = {
      'size': 10, // Page size
    };

    if (cursor != null) {
      params['cursor'] = cursor;
    }

    // Add filter parameter if needed
    if (filter != null) {
      switch (filter) {
        case PayoutHistoryFilter.successful:
          params['transaction_type'] = 'successful';
          break;
        case PayoutHistoryFilter.failed:
          params['transaction_type'] = 'failed';
          break;
        case PayoutHistoryFilter.all:
          // No filter parameter needed
          break;
      }
    }

    return params;
  }

  /// Fetches payout history data from the server (initial load)
  Future<void> fetchPayoutHistory() async {
    _loading = true;
    _error = null;
    _nextPageCursor = null;
    _hasMoreItems = true;
    _allTransactions.clear();
    notifyListeners();

    try {
      final response = await PayoutHistoryService.getPayoutHistory(
        queryParameters: _buildQueryParams(filter: _selectedFilter),
      );

      if (response == null || response.data == null) {
        _error = 'Failed to fetch data';
        _loading = false;
        notifyListeners();
        return;
      }

      if (response.statusCode == 200) {
        final data = response.data;

        // Parse metadata (transaction types, bank accounts, UPI accounts)
        // These are typically returned only on first page
        if (data['transaction_types'] != null) {
          _transactionTypes = (data['transaction_types'] as List)
              .map((item) => TransactionType.fromJson(item))
              .toList();
        }
        if (data['bank_accounts'] != null) {
          _bankAccounts = (data['bank_accounts'] as List)
              .map((item) => BankAccount.fromJson(item))
              .toList();
        }
        if (data['upi_accounts'] != null) {
          _upiAccounts = (data['upi_accounts'] as List)
              .map((item) => UpiAccount.fromJson(item))
              .toList();
        }

        // Parse transactions
        final List<dynamic> transactionsJson = data['transactions'] ?? [];
        final List<Transaction> fetchedTransactions = transactionsJson
            .map<Transaction>((json) => Transaction.fromJson(json))
            .toList();

        _allTransactions = fetchedTransactions;
        _nextPageCursor = data['next_page'];
        _hasMoreItems = _nextPageCursor != null;

        // Update the full response object for backward compatibility
        _payoutHistoryData = PayoutHistoryResponse(
          transactionTypes: _transactionTypes,
          bankAccounts: _bankAccounts,
          upiAccounts: _upiAccounts,
          transactions: _allTransactions,
        );
      } else {
        _error = 'Failed to fetch data';
      }

      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      _payoutHistoryData = null;
      _allTransactions.clear();
      notifyListeners();
    }
  }

  /// Fetches more transactions when scrolling (pagination)
  Future<void> fetchMoreTransactions() async {
    if (_loadingMore || !_hasMoreItems || _nextPageCursor == null) return;

    _loadingMore = true;
    notifyListeners();

    try {
      final response = await PayoutHistoryService.getPayoutHistory(
        queryParameters: _buildQueryParams(
          cursor: _nextPageCursor,
          filter: _selectedFilter,
        ),
      );

      if (response?.statusCode == 200) {
        final data = response?.data;
        final List<dynamic> transactionsJson = data?['transactions'] ?? [];
        final List<Transaction> fetchedTransactions = transactionsJson
            .map<Transaction>((json) => Transaction.fromJson(json))
            .toList();

        if (fetchedTransactions.isNotEmpty) {
          _allTransactions.addAll(fetchedTransactions);
          _nextPageCursor = data?['next_page'];
          _hasMoreItems = _nextPageCursor != null;

          // Update the full response object
          _payoutHistoryData = PayoutHistoryResponse(
            transactionTypes: _transactionTypes,
            bankAccounts: _bankAccounts,
            upiAccounts: _upiAccounts,
            transactions: _allTransactions,
          );
        } else {
          _hasMoreItems = false;
        }
      }
    } catch (e) {
      // Silently handle errors for pagination to avoid disrupting the user experience
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Refreshes the payout history data and resets pagination
  Future<void> refreshPayoutHistory() async {
    _allTransactions.clear();
    _nextPageCursor = null;
    _hasMoreItems = true;
    await fetchPayoutHistory();
  }

  /// Handles filter change and resets pagination
  void onFilterChanged(PayoutHistoryFilter filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    _allTransactions.clear();
    _nextPageCursor = null;
    _hasMoreItems = true;
    fetchPayoutHistory();
  }

  /// Gets filtered transactions based on the selected filter
  List<Transaction> getFilteredTransactions() {
    if (_allTransactions.isEmpty) {
      return [];
    }

    switch (_selectedFilter) {
      case PayoutHistoryFilter.all:
        return _allTransactions;
      case PayoutHistoryFilter.successful:
        return _allTransactions.where((t) => t.transactionTypeId == 1).toList();
      case PayoutHistoryFilter.failed:
        return _allTransactions.where((t) => t.transactionTypeId == 2).toList();
    }
  }

  /// Gets transaction type name by ID
  String? getTransactionTypeName(int? transactionTypeId) {
    if (_transactionTypes == null || transactionTypeId == null) {
      return null;
    }
    try {
      return _transactionTypes!
          .firstWhere(
            (type) => type.transactionTypeId == transactionTypeId,
            orElse: () => TransactionType(),
          )
          .typeName;
    } catch (e) {
      return null;
    }
  }

  /// Gets bank account by ID
  BankAccount? getBankAccount(int? bankAccountId) {
    if (_bankAccounts == null || bankAccountId == null) {
      return null;
    }
    try {
      return _bankAccounts!
          .firstWhere((account) => account.bankAccountId == bankAccountId);
    } catch (e) {
      return null;
    }
  }

  /// Gets UPI account by ID
  UpiAccount? getUpiAccount(int? upiAccountId) {
    if (_upiAccounts == null || upiAccountId == null) {
      return null;
    }
    try {
      return _upiAccounts!
          .firstWhere((account) => account.upiAccountId == upiAccountId);
    } catch (e) {
      return null;
    }
  }

  void reset() {
    _loading = false;
    _loadingMore = false;
    _error = null;
    _payoutHistoryData = null;
    _allTransactions.clear();
    _nextPageCursor = null;
    _hasMoreItems = true;
    _selectedFilter = PayoutHistoryFilter.all;
  }
}

/// Enum to represent the selected filter tab in payout history
enum PayoutHistoryFilter {
  all,
  successful,
  failed,
}
