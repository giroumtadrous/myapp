import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/firebase_options.dart';

void main() {
  testWidgets('Dump Firestore contents', (tester) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      print('--- SESSIONS ---');
      final sessionsSnap = await FirebaseFirestore.instance.collection('sessions').get();
      for (final doc in sessionsSnap.docs) {
        print('Session ID: ${doc.id}');
        print('Data: ${doc.data()}');
      }

      print('--- STUDENTS WALLET ---');
      // Let's get student IDs from users/students collection
      final studentsSnap = await FirebaseFirestore.instance.collection('users').get();
      for (final doc in studentsSnap.docs) {
        final data = doc.data();
        if (data['role']?.toString().toLowerCase() == 'student' || true) {
          final summarySnap = await FirebaseFirestore.instance
              .collection('students')
              .doc(doc.id)
              .collection('wallet')
              .doc('summary')
              .get();
          print('Student ID: ${doc.id} (${data['name']})');
          print('  Wallet Summary: ${summarySnap.data()}');

          final txSnap = await FirebaseFirestore.instance
              .collection('students')
              .doc(doc.id)
              .collection('wallet')
              .doc('summary')
              .collection('credit_transactions')
              .get();
          print('  Transactions Count: ${txSnap.docs.length}');
          for (final txDoc in txSnap.docs) {
            print('    Tx ID: ${txDoc.id} => ${txDoc.data()}');
          }
        }
      }

      print('--- TUTORS WALLET ---');
      final tutorsSnap = await FirebaseFirestore.instance.collection('tutors').get();
      for (final doc in tutorsSnap.docs) {
        final data = doc.data();
        final summarySnap = await FirebaseFirestore.instance
            .collection('tutors')
            .doc(doc.id)
            .collection('wallet')
            .doc('summary')
            .get();
        print('Tutor ID: ${doc.id} (${data['name']})');
        print('  Wallet Summary: ${summarySnap.data()}');
      }
    } catch (e) {
      print('Error during dump: $e');
    }
  });
}
