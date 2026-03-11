import 'package:flutter/material.dart';

Color sessionStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'booked':
    case 'confirmed':
    case 'approved':
      return Colors.green;
    case 'completed':
      return Colors.blue;
    case 'pending':
    case 'pending_payment_verification':
      return Colors.orange;
    case 'payment_rejected':
    case 'rejected':
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.blueGrey;
  }
}

String sessionStatusLabel(String status) {
  switch (status) {
    case 'pending_payment_verification':
      return 'Pending';
    case 'payment_rejected':
      return 'Payment Rejected';
    default:
      return status;
  }
}
