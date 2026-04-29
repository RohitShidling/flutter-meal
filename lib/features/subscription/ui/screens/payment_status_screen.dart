import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String txnId;
  final String orderId;

  const PaymentStatusScreen({
    super.key,
    required this.txnId,
    required this.orderId,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  Map<String, dynamic>? _statusData;
  bool _isPolling = true;
  int _retryCount = 0;
  final int _maxRetries = 10;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  Future<void> _startPolling() async {
    while (_isPolling && _retryCount < _maxRetries) {
      final data = await context.read<PaymentProvider>().checkStatus(widget.txnId);
      
      if (mounted) {
        setState(() {
          _statusData = data;
          if (data != null && (data['status'] == 'COMPLETED' || data['status'] == 'FAILED')) {
            _isPolling = false;
          }
        });
      }

      if (_isPolling) {
        await Future.delayed(const Duration(seconds: 3));
        _retryCount++;
      }
    }

    if (mounted && _isPolling) {
      setState(() {
        _isPolling = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _statusData?['status'] ?? 'PENDING';
    final isSuccess = status == 'COMPLETED' || status == 'SUCCESS';
    final isFailed = status == 'FAILED';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              if (_isPolling)
                _buildLoadingUI()
              else if (isSuccess)
                _buildSuccessUI(isDark)
              else if (isFailed)
                _buildFailureUI(isDark)
              else
                _buildPendingUI(isDark),
              const Spacer(),
              if (!_isPolling)
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text('Back to App'),
                ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingUI() {
    return Column(
      children: [
        const CupertinoActivityIndicator(radius: 20),
        const SizedBox(height: 24),
        const Text(
          'Verifying Payment Status',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please do not close the app or press back.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildSuccessUI(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 40),
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        const Text(
          'Payment Successful!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Text(
          'Your subscription for ${_statusData?['plan_name'] ?? 'Plan'} is now active.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 32),
        AppleCard(
          child: Column(
            children: [
              _buildStatusRow('Order ID', widget.orderId),
              _buildStatusRow('Amount', '₹${_statusData?['amount']}'),
              _buildStatusRow('Transaction ID', widget.txnId),
            ],
          ),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildFailureUI(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 40),
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        const Text(
          'Payment Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        const Text(
          'Something went wrong with your transaction. Please try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildPendingUI(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          child: const Icon(CupertinoIcons.clock, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 24),
        const Text(
          'Payment is Pending',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        const Text(
          'We are still waiting for confirmation from your bank. It should update shortly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
