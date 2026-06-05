import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../repositories/payment_repository.dart';
import '../../services/payment_screenshot_storage_service.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/pressable_scale.dart';
import '../dashboard/main_navigation_screen.dart';

class ManualPaymentScreen extends StatefulWidget {
  const ManualPaymentScreen({
    super.key,
    required this.sessionId,
    required this.tutorId,
    required this.subject,
    required this.date,
    required this.time,
    required this.timeDisplay,
    required this.sessionDateTime,
    required this.amount,
    required this.durationMinutes,
    required this.slotCount,
    required this.reservedSlots,
  });

  final String sessionId;
  final String tutorId;
  final String subject;
  final String date;
  final String time;
  final String timeDisplay;
  final DateTime sessionDateTime;
  final double amount;
  final int durationMinutes;
  final int slotCount;
  final List<String> reservedSlots;

  @override
  State<ManualPaymentScreen> createState() => _ManualPaymentScreenState();
}

class _ManualPaymentScreenState extends State<ManualPaymentScreen> {
  static const String _instaPayNumber = '+201283567813';

  final PaymentRepository _paymentRepository = PaymentRepository();
  
  // Selected payment method: 'card' (Visa/Mastercard) or 'instapay'
  String _selectedMethod = 'card';

  // InstaPay Form Controllers
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final PaymentScreenshotStorageService _screenshotStorage =
      PaymentScreenshotStorageService.instance;
  XFile? _screenshotImage;
  DateTime? _transferTime;

  // Credit Card Form Controllers & Focus Node
  final TextEditingController _cardNameController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();
  final FocusNode _cvvFocusNode = FocusNode();
  
  bool _submitting = false;
  bool _isCvvFocused = false;

  @override
  void initState() {
    super.initState();
    _cvvFocusNode.addListener(() {
      setState(() {
        _isCvvFocused = _cvvFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _timeController.dispose();
    _noteController.dispose();
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cvvFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickTransferDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now,
      initialDate: _transferTime ?? now,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transferTime ?? now),
    );
    if (pickedTime == null || !mounted) return;

    final value = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _transferTime = value;
      _timeController.text = DateFormat('yyyy-MM-dd HH:mm').format(value);
    });
  }

  Future<void> _submitInstaPay() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }

    if (_screenshotImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo of your payment screenshot.')),
      );
      return;
    }

    if (_transferTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide transfer time.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final screenshotUrl = await _screenshotStorage.uploadPaymentScreenshot(
        image: _screenshotImage!,
        userId: user.uid,
        sessionId: widget.sessionId,
      );

      await _paymentRepository.submitManualPayment(
        sessionId: widget.sessionId,
        studentId: user.uid,
        tutorId: widget.tutorId,
        subject: widget.subject,
        sessionDateTime: widget.sessionDateTime,
        date: widget.date,
        time: widget.time,
        timeDisplay: widget.timeDisplay,
        amount: widget.amount,
        durationMinutes: widget.durationMinutes,
        slotCount: widget.slotCount,
        reservedSlots: widget.reservedSlots,
        transferTime: _transferTime!,
        screenshotUrl: screenshotUrl,
        note: _noteController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        AppTransitions.fade(page: const MainNavigationScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment submitted. Waiting for manual verification.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit manual payment: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _submitCardPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }

    final cardName = _cardNameController.text.trim();
    final cardNumber = _cardNumberController.text.replaceAll(' ', '');
    final cardExpiry = _cardExpiryController.text.trim();
    final cardCvv = _cardCvvController.text.trim();

    if (cardName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter cardholder name.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (cardNumber.length < 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 16-digit card number.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (cardExpiry.length < 5 || !cardExpiry.contains('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expiry date (MM/YY).'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (cardCvv.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid CVV code.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await _paymentRepository.submitCardPayment(
        sessionId: widget.sessionId,
        studentId: user.uid,
        tutorId: widget.tutorId,
        subject: widget.subject,
        sessionDateTime: widget.sessionDateTime,
        date: widget.date,
        time: widget.time,
        timeDisplay: widget.timeDisplay,
        amount: widget.amount,
        durationMinutes: widget.durationMinutes,
        slotCount: widget.slotCount,
        reservedSlots: widget.reservedSlots,
        cardholderName: cardName,
        cardNumber: cardNumber,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        AppTransitions.fade(page: const MainNavigationScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card payment approved! Session confirmed instantly.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Direct card processing failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _pickScreenshot(ImageSource source) async {
    if (_submitting) return;

    try {
      final image = source == ImageSource.camera
          ? await _screenshotStorage.pickFromCamera()
          : await _screenshotStorage.pickFromGallery();
      if (image == null || !mounted) return;
      setState(() => _screenshotImage = image);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  Widget _screenshotPreview() {
    if (_screenshotImage == null) {
      return Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 40, color: Color(0xFF94A3B8)),
            SizedBox(height: 8),
            Text(
              'No payment screenshot yet',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<Uint8List>(
            future: _screenshotImage!.readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: Text('Could not load preview')),
                );
              }
              return Image.memory(
                snapshot.data!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
            ),
            onPressed: _submitting ? null : () => setState(() => _screenshotImage = null),
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove photo',
          ),
        ),
      ],
    );
  }

  String _detectCardType(String number) {
    if (number.startsWith('4')) return 'Visa';
    if (number.startsWith('5')) return 'Mastercard';
    return 'Card';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Details'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Session Checkout Overview Summary Card
              Card(
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.subject,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4051B5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.durationMinutes} mins',
                              style: const TextStyle(
                                color: Color(0xFF4051B5),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.date} @ ${widget.timeDisplay}',
                            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFFE2E8F0)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount Due',
                            style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '\$${widget.amount.toStringAsFixed(2)}',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4051B5),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Select Payment Method',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),

              // Payment Selection Row
              Row(
                children: [
                  Expanded(
                    child: _buildMethodTab(
                      id: 'card',
                      title: 'Direct Card',
                      subtitle: 'Visa / Mastercard',
                      icon: Icons.credit_card_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMethodTab(
                      id: 'instapay',
                      title: 'InstaPay',
                      subtitle: 'Manual Transfer',
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Conditional Forms Display
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _selectedMethod == 'card' 
                  ? _buildCreditCardForm(textTheme)
                  : _buildInstaPayForm(textTheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodTab({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedMethod == id;
    final themeColor = id == 'card' ? const Color(0xFF4051B5) : Colors.teal;

    return PressableScale(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? themeColor : const Color(0xFFE2E8F0),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected 
              ? [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? themeColor.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? themeColor : const Color(0xFF64748B),
                  size: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditCardForm(TextTheme textTheme) {
    final rawNumber = _cardNumberController.text.replaceAll(' ', '');
    final cardType = _detectCardType(rawNumber);

    return Column(
      key: const ValueKey('card_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reactive Credit Card Design mockup
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 190,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E1B4B).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _isCvvFocused
              ? _buildCardBack()
              : _buildCardFront(rawNumber, cardType),
        ),
        const SizedBox(height: 24),

        // Text Fields
        TextField(
          controller: _cardNameController,
          enabled: !_submitting,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
            labelText: 'Cardholder Name',
            hintText: 'John Doe',
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _cardNumberController,
          enabled: !_submitting,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CardNumberInputFormatter(),
          ],
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.payment_rounded, color: Color(0xFF64748B)),
            labelText: 'Card Number',
            hintText: '4111 2222 3333 4444',
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                cardType == 'Visa' 
                  ? Icons.credit_card_rounded 
                  : (cardType == 'Mastercard' ? Icons.filter_b_and_w_rounded : Icons.credit_card),
                color: const Color(0xFF4051B5),
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _cardExpiryController,
                enabled: !_submitting,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CardExpiryInputFormatter(),
                ],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.date_range_rounded, color: Color(0xFF64748B)),
                  labelText: 'Expiry Date',
                  hintText: 'MM/YY',
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _cardCvvController,
                focusNode: _cvvFocusNode,
                enabled: !_submitting,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.security_rounded, color: Color(0xFF64748B)),
                  labelText: 'CVV',
                  hintText: '***',
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: PressableScale(
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submitCardPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4051B5),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.lock_rounded, size: 18),
              label: Text(
                _submitting ? 'Processing...' : 'Pay & Confirm Session',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardFront(String rawNumber, String cardType) {
    String formattedNum = '';
    for (int i = 0; i < 16; i++) {
      if (i < rawNumber.length) {
        formattedNum += rawNumber[i];
      } else {
        formattedNum += '•';
      }
      if ((i + 1) % 4 == 0 && i != 15) {
        formattedNum += ' ';
      }
    }

    final name = _cardNameController.text.trim();
    final expiry = _cardExpiryController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Zelp Card',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
            ),
            Text(
              cardType.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        Row(
          children: [
            // Gold Microchip mockup
            Container(
              width: 38,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.wifi, color: Colors.white, size: 20),
          ],
        ),
        Text(
          formattedNum,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CARDHOLDER',
                    style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name.isEmpty ? 'JOHN DOE' : name.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'EXPIRES',
                  style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  expiry.isEmpty ? 'MM/YY' : expiry,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardBack() {
    final cvv = _cardCvvController.text.trim();
    String formattedCvv = '';
    for (int i = 0; i < 3; i++) {
      if (i < cvv.length) {
        formattedCvv += '*';
      } else {
        formattedCvv += '•';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 10),
        // Magnetic Strip mockup
        Container(
          height: 38,
          color: Colors.black,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Container(
                height: 30,
                color: Colors.white.withValues(alpha: 0.8),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 10),
                child: const Text(
                  'XXXX XXXX XXXX',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Container(
                height: 30,
                color: const Color(0xFFFFD700),
                alignment: Alignment.center,
                child: Text(
                  formattedCvv,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'AUTHORIZED SIGNATURE',
              style: TextStyle(color: Colors.white54, fontSize: 7, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstaPayForm(TextTheme textTheme) {
    return Column(
      key: const ValueKey('instapay_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // InstaPay Info Alert Box
        Card(
          elevation: 0,
          color: Colors.teal.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.teal.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.teal, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'How to pay with InstaPay',
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.teal),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '1. Open the InstaPay app on your phone.\n'
                  '2. Make a transfer to the number shown below.\n'
                  '3. Take a screenshot of the confirmation page.\n'
                  '4. Upload the photo here as proof.',
                  style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF1E293B)),
                ),
                const Divider(height: 24, color: Color(0xFFE2E8F0)),
                const Text(
                  'InstaPay Phone Number:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SelectableText(
                      _instaPayNumber,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.teal,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: _instaPayNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied number to clipboard!'), duration: Duration(seconds: 1)),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.copy_rounded, color: Colors.teal, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Payment screenshot',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        _screenshotPreview(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : () => _pickScreenshot(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take photo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : () => _pickScreenshot(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _timeController,
          readOnly: true,
          onTap: _submitting ? null : _pickTransferDateTime,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.schedule_rounded, color: Color(0xFF64748B)),
            labelText: 'Transfer Time',
            hintText: 'Select date and time',
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _noteController,
          enabled: !_submitting,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF64748B)),
            labelText: 'Reference Note (optional)',
            hintText: 'Transaction reference, sender name, etc.',
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          minLines: 2,
          maxLines: 3,
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: PressableScale(
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitInstaPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Submit Payment Proof',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// Reusable custom card text formatting classes with zero dependencies
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 16) text = text.substring(0, 16);
    
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      int nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 4) text = text.substring(0, 4);
    
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      int nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }
    
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
