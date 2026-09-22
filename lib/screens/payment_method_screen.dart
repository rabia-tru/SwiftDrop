import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Payment method types
class PaymentMethodScreen extends StatefulWidget {
  final double totalAmount;

  const PaymentMethodScreen({super.key, required this.totalAmount});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

/// Payment Method Selection Screen — FoodPanda-style
class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  bool _isCard = false; // false = Cash on Delivery (default)
  final _cardNumberController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _saveCard = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardNameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _selectMethod(bool isCard) {
    setState(() => _isCard = isCard);
  }

  void _confirmPayment() {
    // Validate card details when card is selected
    if (_isCard) {
      if (_cardNumberController.text.length < 16) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter a valid card number'),
            backgroundColor: AppColors.orangeDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
    }

    // Return selected payment method to cart
    final paymentInfo = _getPaymentInfo();
    Navigator.of(context).pop(paymentInfo);
  }

  Map<String, String> _getPaymentInfo() {
    if (_isCard) {
      final maskedCard = '•••• ${_cardNumberController.text.substring(max(0, _cardNumberController.text.length - 4))}';
      return {
        'type': 'card',
        'label': 'Card',
        'detail': '$maskedCard',
        'icon': 'credit_card',
      };
    }
    return {
      'type': 'cod',
      'label': 'Cash on Delivery',
      'detail': 'Pay Rs.${widget.totalAmount.toStringAsFixed(0)} when delivered',
      'icon': 'payments',
    };
  }

  int max(int a, int b) => a > b ? a : b;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.black;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : AppColors.darkGray;

    AppColors.setLightStatusBar();
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        title: const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total amount header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.orange, AppColors.orangeDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Amount to Pay', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('Rs.${widget.totalAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Choose Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 16),

            // Card Option
            _buildPaymentOption(
              cardColor: cardColor,
              textColor: textColor,
              subTextColor: subTextColor,
              icon: Icons.credit_card,
              title: 'Credit / Debit Card',
              subtitle: 'Visa, Mastercard, Rupay',
              isSelected: _isCard,
              onTap: () => _selectMethod(true),
            ),
            if (_isCard) ...[
              const SizedBox(height: 12),
              _buildCardInput(cardColor, textColor, isDark),
            ],
            const SizedBox(height: 12),

            // Cash on Delivery Option
            _buildPaymentOption(
              cardColor: cardColor,
              textColor: textColor,
              subTextColor: subTextColor,
              icon: Icons.payments,
              title: 'Cash on Delivery',
              subtitle: 'Pay when your order arrives',
              isSelected: !_isCard,
              onTap: () => _selectMethod(false),
            ),
            const SizedBox(height: 32),

            // Security note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.orangePale.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, color: AppColors.orange, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your payment information is secure and encrypted',
                      style: TextStyle(fontSize: 12, color: AppColors.darkGray),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _confirmPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Pay Rs.${widget.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.orange : AppColors.gray.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.orange : AppColors.orangePale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : AppColors.orange, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: subTextColor)),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? AppColors.orange : AppColors.gray, width: 2),
                color: isSelected ? AppColors.orange : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardInput(Color cardColor, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Card Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 12),
          // Card number
          TextField(
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            maxLength: 16,
            style: TextStyle(fontSize: 15, color: textColor, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: '1234 5678 9012 3456',
              hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.6)),
              prefixIcon: const Icon(Icons.credit_card, color: AppColors.orange, size: 20),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              filled: true,
              fillColor: AppColors.lightGray,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          // Cardholder name
          TextField(
            controller: _cardNameController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: 15, color: textColor),
            decoration: InputDecoration(
              hintText: 'Cardholder Name',
              hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.6)),
              prefixIcon: const Icon(Icons.person, color: AppColors.orange, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              filled: true,
              fillColor: AppColors.lightGray,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          // Expiry + CVV
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiryController,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  style: TextStyle(fontSize: 15, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'MM/YY',
                    hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.6)),
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: AppColors.lightGray,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cvvController,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  obscureText: true,
                  style: TextStyle(fontSize: 15, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'CVV',
                    hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.6)),
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: AppColors.lightGray,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Save card checkbox
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _saveCard,
                  onChanged: (v) => setState(() => _saveCard = v ?? false),
                  activeColor: AppColors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 10),
              Text('Save this card for future payments', style: TextStyle(fontSize: 13, color: textColor)),
            ],
          ),
        ],
      ),
    );
  }
}
