import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class MonthlyTransactionData {
  final DateTime month;
  final double deposits;
  final double withdrawals;

  MonthlyTransactionData({
    required this.month,
    required this.deposits,
    required this.withdrawals,
  });
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool isLoading = true;
  String? errorMessage;
  List<MonthlyTransactionData> monthlyData = [];
  double currentBalance = 0.0;

  // For filtering
  int selectedMonthsRange = 6; // Default to 6 months

  @override
  void initState() {
    super.initState();
    _loadTransactionData();
    _loadCurrentBalance();
  }

  Future<void> _loadCurrentBalance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final bankDoc = await FirebaseFirestore.instance
            .collection('bank-account')
            .doc(user.uid)
            .get();

        if (bankDoc.exists) {
          setState(() {
            currentBalance = (bankDoc.data()?['balance'] ?? 0).toDouble();
          });
        }
      }
    } catch (e) {
      print('Error loading balance: $e');
    }
  }

  Future<void> _loadTransactionData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Get current date and calculate date range
        final now = DateTime.now();
        final startDate = DateTime(now.year, now.month - selectedMonthsRange, 1);

        // Modified query to avoid the composite index requirement
        // First, get all user transactions
        final querySnapshot = await FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: user.uid)
            .get();

        // Then filter by date in memory
        final filteredDocs = querySnapshot.docs.where((doc) {
          final timestamp = doc.data()['timestamp'] as Timestamp;
          return timestamp.toDate().isAfter(startDate);
        }).toList();

        // Sort the filtered docs by timestamp
        filteredDocs.sort((a, b) {
          final timestampA = a.data()['timestamp'] as Timestamp;
          final timestampB = b.data()['timestamp'] as Timestamp;
          return timestampA.compareTo(timestampB);
        });

        // Process transactions into monthly data
        final Map<String, MonthlyTransactionData> monthlyMap = {};

        for (var doc in filteredDocs) {
          final data = doc.data();
          final timestamp = data['timestamp'] as Timestamp;
          final date = timestamp.toDate();
          final amount = (data['amount'] as num).toDouble();
          final type = data['type'] as String;

          // Create a key for the month (YYYY-MM)
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';

          // Initialize or update monthly data
          if (!monthlyMap.containsKey(monthKey)) {
            monthlyMap[monthKey] = MonthlyTransactionData(
              month: DateTime(date.year, date.month, 1),
              deposits: type == 'deposit' ? amount : 0,
              withdrawals: type == 'withdraw' ? amount : 0,
            );
          } else {
            final currentData = monthlyMap[monthKey]!;
            if (type == 'deposit') {
              monthlyMap[monthKey] = MonthlyTransactionData(
                month: currentData.month,
                deposits: currentData.deposits + amount,
                withdrawals: currentData.withdrawals,
              );
            } else if (type == 'withdraw') {
              monthlyMap[monthKey] = MonthlyTransactionData(
                month: currentData.month,
                deposits: currentData.deposits,
                withdrawals: currentData.withdrawals + amount,
              );
            }
          }
        }

        // Convert map to sorted list
        final sortedData = monthlyMap.values.toList()
          ..sort((a, b) => a.month.compareTo(b.month));

        setState(() {
          monthlyData = sortedData;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "No user is signed in";
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading transaction data: $e');
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    String amountStr = amount.toStringAsFixed(2);
    List<String> parts = amountStr.split('.');

    // Format money with comma
    String wholeNumber = parts[0];
    String result = '';

    for (int i = 0; i < wholeNumber.length; i++) {
      if (i > 0 && (wholeNumber.length - i) % 3 == 0) {
        result += ',';
      }
      result += wholeNumber[i];
    }

    // Add decimal part back
    return '₱$result.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "Financial Analytics",
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton.outlined(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text("Error: $errorMessage"))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF204887),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Current Balance",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatCurrency(currentBalance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Time range selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Monthly Transactions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                DropdownButton<int>(
                  value: selectedMonthsRange,
                  items: const [
                    DropdownMenuItem(value: 3, child: Text("3 Months")),
                    DropdownMenuItem(value: 6, child: Text("6 Months")),
                    DropdownMenuItem(value: 12, child: Text("1 Year")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedMonthsRange = value;
                      });
                      _loadTransactionData();
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Chart
            monthlyData.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  "No transaction data available for the selected period",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            )
                : Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _calculateMaxY(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String type = rodIndex == 0 ? 'Deposits' : 'Withdrawals';
                        String value = _formatCurrency(rod.toY);
                        return BarTooltipItem(
                          '$type: $value',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= monthlyData.length) {
                            return const SizedBox.shrink();
                          }
                          final month = monthlyData[value.toInt()].month;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('MMM').format(month),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            '₱${value.toInt()}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  barGroups: List.generate(
                    monthlyData.length,
                        (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: monthlyData[index].deposits,
                          color: Colors.green,
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: monthlyData[index].withdrawals,
                          color: const Color(0xFF007BA4),
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem("Deposits", Colors.green),
                const SizedBox(width: 24),
                _buildLegendItem("Withdrawals", const Color(0xFF007BA4)),
              ],
            ),

            const SizedBox(height: 24),

            // Monthly Summary
            const Text(
              "Monthly Summary",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Monthly summary list
            ...monthlyData.reversed.map((data) => _buildMonthlySummaryItem(data)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Widget _buildMonthlySummaryItem(MonthlyTransactionData data) {
    final monthName = DateFormat('MMMM yyyy').format(data.month);
    final netFlow = data.deposits - data.withdrawals;
    final isPositive = netFlow >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              monthName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Deposits: ${_formatCurrency(data.deposits)}",
                      style: const TextStyle(color: Colors.green),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Withdrawals: ${_formatCurrency(data.withdrawals)}",
                      style: const TextStyle(color: Color(0xFF007BA4)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Net Flow:"),
                    Text(
                      _formatCurrency(netFlow.abs()),
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMaxY() {
    if (monthlyData.isEmpty) return 1000;

    double maxDeposit = 0;
    double maxWithdrawal = 0;

    for (var data in monthlyData) {
      if (data.deposits > maxDeposit) maxDeposit = data.deposits;
      if (data.withdrawals > maxWithdrawal) maxWithdrawal = data.withdrawals;
    }

    // Return the maximum value plus some padding
    return (maxDeposit > maxWithdrawal ? maxDeposit : maxWithdrawal) * 1.2;
  }
}
