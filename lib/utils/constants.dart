import 'package:intl/intl.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

DateFormat dateFormat = DateFormat("yyyy-MM-dd");
DateFormat dateFormatVisual = DateFormat("dd MMM yyyy");
DateFormat dateFormatVisual2 = DateFormat("dd/MM/yyyy");
DateFormat dateFormatVisual3 = DateFormat("dd MMM");
DateFormat dateFormatVisual4 = DateFormat("dd MMM, EEEE");
DateFormat dateFormatVisual5 = DateFormat("dd MMMM yyyy");
DateFormat dateFormatVisual6 = DateFormat("dd MMMM");
DateFormat monthFormatVisual1 = DateFormat("MMM");
DateTime payoutDefaultStart = DateTime.now().subtract(const Duration(days: 1));
DateTime payoutMonthlyDefaultStart =
    DateTime(payoutDefaultStart.year, payoutDefaultStart.month, 1);
DateTime payoutMonthlyDefaultEnd = payoutMonthlyDefaultStart
    .add(Duration(days: daysInCurrentMonth(payoutMonthlyDefaultStart) - 1));
const int highestRating = 5;

const int secondsAfterBreakApiCall = -10;

const int leavePageSize = 25;

const int qrPaymentMaxPollCount = 36;
