import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repositories/credits_repository.dart';
import '../../theme/app_theme.dart';

class StudentWalletScreen extends StatelessWidget {
  const StudentWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final studentId = FirebaseAuth.instance.currentUser?.uid;
    if (studentId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your wallet.')),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Credit Wallet'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Wallet Summary Card ──
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: CreditsRepository.instance.watchStudentWalletSummary(studentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final data = snapshot.data?.data() ?? <String, dynamic>{};
                final double balance = (data['credits'] as num?)?.toDouble() ?? 0.0;
                final double totalEarned = (data['totalCreditsEarned'] as num?)?.toDouble() ?? 0.0;
                final double totalUsed = (data['totalCreditsUsed'] as num?)?.toDouble() ?? 0.0;

                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.buttonGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.glow(alpha: 0.3),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Available Balance',
                            style: textTheme.titleMedium?.copyWith(
                              color: AppTheme.background.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppTheme.background,
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'EGP ${balance.toStringAsFixed(2)}',
                        style: textTheme.headlineLarge?.copyWith(
                          color: AppTheme.background,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL REFUNDED',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppTheme.background.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'EGP ${totalEarned.toStringAsFixed(0)}',
                                style: textTheme.titleMedium?.copyWith(
                                  color: AppTheme.background,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'TOTAL USED',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppTheme.background.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'EGP ${totalUsed.toStringAsFixed(0)}',
                                style: textTheme.titleMedium?.copyWith(
                                  color: AppTheme.background,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Expiry Information Alert ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.fromBorderSide(AppTheme.border()),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Note: Credits expire 6 months from issue date. Expired transaction items are greyed out.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Transaction History Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Text(
                    'Transaction History',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Transaction List ──
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: CreditsRepository.instance.watchStudentTransactions(studentId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: AppTheme.textSecondary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions yet.',
                            style: textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                      final type = (data['type'] ?? 'refund').toString();
                      final reason = (data['reason'] ?? '').toString();
                      final expiresAtStamp = data['expiresAt'];
                      final createdAtStamp = data['createdAt'];

                      final DateTime? expiresAt = expiresAtStamp is Timestamp ? expiresAtStamp.toDate() : null;
                      final DateTime? createdAt = createdAtStamp is Timestamp ? createdAtStamp.toDate() : null;

                      final now = DateTime.now();
                      final isExpired = expiresAt != null && expiresAt.isBefore(now);
                      final isRefund = type == 'refund';

                      // Style variables based on status
                      final itemColor = isExpired
                          ? AppTheme.textSecondary.withValues(alpha: 0.5)
                          : AppTheme.textPrimary;
                      final amountColor = isExpired
                          ? AppTheme.textSecondary.withValues(alpha: 0.5)
                          : (isRefund ? Colors.green[700] : Colors.red[700]);
                      final iconData = isRefund
                          ? Icons.add_circle_outline_rounded
                          : Icons.remove_circle_outline_rounded;
                      final iconColor = isExpired
                          ? AppTheme.textSecondary.withValues(alpha: 0.4)
                          : (isRefund ? Colors.green[600] : Colors.red[600]);

                      return Opacity(
                        opacity: isExpired ? 0.5 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.fromBorderSide(AppTheme.border()),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isExpired
                                    ? Colors.grey[200]
                                    : (isRefund ? Colors.green[50] : Colors.red[50]),
                                child: Icon(iconData, color: iconColor),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reason,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: itemColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      createdAt != null
                                          ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt)
                                          : 'Just now',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    if (isRefund && expiresAt != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        isExpired
                                            ? 'Expired on ${DateFormat('MMM d, yyyy').format(expiresAt)}'
                                            : 'Expires: ${DateFormat('MMM d, yyyy').format(expiresAt)}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: isExpired ? Colors.red[300] : AppTheme.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${isRefund ? '+' : '-'} EGP ${amount.toStringAsFixed(0)}',
                                style: textTheme.titleMedium?.copyWith(
                                  color: amountColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
