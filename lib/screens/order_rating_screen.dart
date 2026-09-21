import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Order Rating Screen — FoodPanda-style after delivery
class OrderRatingScreen extends StatefulWidget {
  final String orderId;
  final String restaurantName;
  final String riderName;

  const OrderRatingScreen({
    super.key,
    required this.orderId,
    required this.restaurantName,
    required this.riderName,
  });

  @override
  State<OrderRatingScreen> createState() => _OrderRatingScreenState();
}

class _OrderRatingScreenState extends State<OrderRatingScreen> {
  int _foodRating = 0;
  int _riderRating = 0;
  final _feedbackController = TextEditingController();
  String? _selectedFeedback;
  double _tipAmount = 0;
  bool _submitted = false;

  final List<String> _feedbackOptions = [
    'Great food!',
    'Fast delivery!',
    'Friendly rider',
    'Well packed',
    'On time',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submitRating() {
    if (_foodRating == 0 || _riderRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please rate both food and rider'),
          backgroundColor: AppColors.orangeDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _submitted = true);

    // Show success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 12),
            Text('Thanks for your feedback!'),
          ],
        ),
        backgroundColor: AppColors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );

    // Close after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.black;

    AppColors.setLightStatusBar();
    if (_submitted) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: AppColors.orange, size: 64),
              ),
              const SizedBox(height: 24),
              Text('Thank You!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 8),
              Text('Your feedback helps us improve', style: TextStyle(fontSize: 16, color: AppColors.darkGray)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        title: const Text('Rate Your Order', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Restaurant name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.restaurant, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.restaurantName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('How was your experience?', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Food Rating
            _buildRatingSection(
              cardColor: cardColor,
              textColor: textColor,
              title: 'Food Quality',
              rating: _foodRating,
              onRatingChanged: (r) => setState(() => _foodRating = r),
            ),
            const SizedBox(height: 16),

            // Rider Rating
            _buildRatingSection(
              cardColor: cardColor,
              textColor: textColor,
              title: 'Delivery (${widget.riderName})',
              rating: _riderRating,
              onRatingChanged: (r) => setState(() => _riderRating = r),
            ),
            const SizedBox(height: 16),

            // Quick Feedback Chips
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _feedbackOptions.map((option) {
                      final isSelected = _selectedFeedback == option;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFeedback = isSelected ? null : option),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.orange : AppColors.orangePale,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? AppColors.orange : AppColors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Text(option, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.orange)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Additional Feedback
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: TextField(
                controller: _feedbackController,
                maxLines: 3,
                style: TextStyle(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Write additional feedback (optional)',
                  hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.6)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF252525) : AppColors.lightGray,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tip Rider
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: AppColors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text('Tip your rider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [0, 20, 50, 100].map((amount) {
                      final isSelected = _tipAmount == amount.toDouble();
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _tipAmount = amount.toDouble()),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.orange : (isDark ? const Color(0xFF252525) : AppColors.lightGray),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected ? AppColors.orange : Colors.transparent, width: 2),
                              ),
                              child: Text(
                                amount == 0 ? 'None' : 'Rs.$amount',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Submit Rating', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),

            // Skip
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Skip for now', style: TextStyle(color: AppColors.darkGray, fontSize: 14)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection({
    required Color cardColor,
    required Color textColor,
    required String title,
    required int rating,
    required ValueChanged<int> onRatingChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              final isSelected = starIndex <= rating;
              return GestureDetector(
                onTap: () => onRatingChanged(starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: isSelected ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      size: 40,
                      color: isSelected ? AppColors.orange : AppColors.gray,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              rating == 0 ? 'Tap to rate' : ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][rating],
              style: TextStyle(fontSize: 14, color: rating > 0 ? AppColors.orange : AppColors.darkGray, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
