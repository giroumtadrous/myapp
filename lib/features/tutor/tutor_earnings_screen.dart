import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/wallet_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_loading_indicator.dart';

class TutorEarningsScreen extends StatefulWidget {
  final String tutorId;

  const TutorEarningsScreen({super.key, required this.tutorId});

  @override
  State<TutorEarningsScreen> createState() => _TutorEarningsScreenState();
}

class _TutorEarningsScreenState extends State<TutorEarningsScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _requestingPayout = false;

  Stream<WalletSummary> _summaryStream() {
    return _firestore
        .collection('tutors')
        .doc(widget.tutorId)
        .collection('wallet')
        .doc('summary')
        .snapshots()
        .map((doc) => WalletSummary.fromFirestore(doc));
  }

  Stream<List<WalletTransaction>> _transactionsStream() {
    return _firestore
        .collection('tutors')
        .doc(widget.tutorId)
        .collection('wallet')
        .doc('transactions')
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final txList = snap.docs
          .map((doc) => WalletTransaction.fromFirestore(doc))
          .toList();

      // Enrich with student names
      final studentIds =
          txList.map((t) => t.studentId ?? '').where((s) => s.isNotEmpty).toSet();
      final studentNames = <String, String>{};
      for (final id in studentIds) {
        try {
          final userDoc = await _firestore.collection('users').doc(id).get();
          studentNames[id] =
              (userDoc.data()?['name'] ?? 'Unknown Student').toString();
        } catch (_) {
          studentNames[id] = 'Unknown Student';
        }
      }

      return txList.map((tx) {
        if (tx.studentId != null && studentNames.containsKey(tx.studentId)) {
          return WalletTransaction(
            id: tx.id,
            sessionId: tx.sessionId,
            amount: tx.amount,
            status: tx.status,
            createdAt: tx.createdAt,
            subject: tx.subject,
            studentId: tx.studentId,
            studentName: studentNames[tx.studentId],
          );
        }
        return tx;
      }).toList();
    });
  }

  Future<void> _requestPayout(double pendingAmount) async {
    if (pendingAmount <= 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Payout'),
        content: Text(
          'Are you sure you want to request a payout of EGP ${pendingAmount.toStringAsFixed(0)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _requestingPayout = true);

    try {
      // Get tutor name
      String tutorName = '';
      final tutorDoc =
          await _firestore.collection('tutors').doc(widget.tutorId).get();
      if (tutorDoc.exists) {
        tutorName = (tutorDoc.data()?['name'] ?? '').toString();
      }

      await _firestore.collection('payout_requests').add({
        'tutorId': widget.tutorId,
        'amount': pendingAmount,
        'status': 'pending',
        'tutorName': tutorName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payout request submitted ✓'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit payout request: $e')),
      );
    } finally {
      if (mounted) setState(() => _requestingPayout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(title: const Text('Earnings')),
      body: StreamBuilder<WalletSummary>(
        stream: _summaryStream(),
        builder: (context, summarySnap) {
          final summary = summarySnap.data ?? const WalletSummary();

          return StreamBuilder<List<WalletTransaction>>(
            stream: _transactionsStream(),
            builder: (context, txSnap) {
              if (summarySnap.connectionState == ConnectionState.waiting &&
                  txSnap.connectionState == ConnectionState.waiting) {
                return const AppLoadingIndicator(
                    message: 'Loading earnings...');
              }

              final transactions = txSnap.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Summary Cards ──
                  Row(
                    children: [
                      _EarningsCard(
                        label: 'Total Earned',
                        amount: summary.totalEarned,
                        icon: Icons.account_balance_wallet_outlined,
                        gradientColors: const [
                          Color(0xFF22C55E),
                          Color(0xFF16A34A),
                        ],
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _EarningsCard(
                        label: 'Pending',
                        amount: summary.pendingPayout,
                        icon: Icons.schedule_outlined,
                        gradientColors: const [
                          Color(0xFFF59E0B),
                          Color(0xFFD97706),
                        ],
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _EarningsCard(
                        label: 'Paid Out',
                        amount: summary.paidOut,
                        icon: Icons.check_circle_outline,
                        gradientColors: const [
                          Color(0xFF3B82F6),
                          Color(0xFF2563EB),
                        ],
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Request Payout Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: summary.pendingPayout > 0 && !_requestingPayout
                          ? () => _requestPayout(summary.pendingPayout)
                          : null,
                      icon: _requestingPayout
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.payments_outlined),
                      label: Text(
                        _requestingPayout
                            ? 'Submitting...'
                            : 'Request Payout (EGP ${summary.pendingPayout.toStringAsFixed(0)})',
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Transaction History ──
                  Text(
                    'Transaction History',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (transactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurface
                            : AppTheme.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.fromBorderSide(
                            AppTheme.border(isDark: isDark)),
                      ),
                      child: Center(
                        child: Text(
                          'No transactions yet. Complete sessions to start earning!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    ...transactions
                        .map((tx) => _TransactionTile(
                              transaction: tx,
                              isDark: isDark,
                            )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Earnings Card ───────────────────────────────────────────────────────────
class _EarningsCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final List<Color> gradientColors;
  final bool isDark;

  const _EarningsCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.gradientColors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'EGP ${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: gradientColors.first,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction Tile ────────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;
  final bool isDark;

  const _TransactionTile({required this.transaction, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isPaid = transaction.status == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isPaid ? const Color(0xFF22C55E) : const Color(0xFFF59E0B))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPaid ? Icons.check_circle_outline : Icons.schedule,
              color: isPaid ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.subject ?? 'Session',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.studentName ?? 'Student',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'EGP ${transaction.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isPaid
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isPaid ? 'PAID' : 'PENDING',
                  style: TextStyle(
                    color: isPaid
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFF59E0B),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (transaction.createdAt != null) ...[
                const SizedBox(height: 3),
                Text(
                  DateFormat.MMMd().format(transaction.createdAt!),
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
