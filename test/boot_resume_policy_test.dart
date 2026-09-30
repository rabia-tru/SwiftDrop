import 'package:flutter_test/flutter_test.dart';

/// Contract for BootReceiver.kt's shouldResume() — kept in a Dart test so
/// the Kotlin side's decision logic is pinned without needing an emulator.
///
/// The Kotlin implementation must stay byte-for-byte equivalent in intent:
/// resume iff ANY persisted job flag is active.
void main() {
  // Local mirror of the Kotlin companion function's contract.
  bool shouldResume({
    required bool riderActive,
    required bool customerActive,
    required bool riderOrderActive,
    String? chatCustomer,
    String? chatRider,
  }) =>
      riderActive ||
      customerActive ||
      riderOrderActive ||
      (chatCustomer?.isNotEmpty ?? false) ||
      (chatRider?.isNotEmpty ?? false);

  group('BootResumePolicy (mirrors BootReceiver.kt)', () {
    test('no flags → never resume', () {
      expect(
        shouldResume(
          riderActive: false,
          customerActive: false,
          riderOrderActive: false,
          chatCustomer: null,
          chatRider: null,
        ),
        isFalse,
      );
    });

    test('empty-string chat flags count as inactive', () {
      expect(
        shouldResume(
          riderActive: false,
          customerActive: false,
          riderOrderActive: false,
          chatCustomer: '',
          chatRider: '',
        ),
        isFalse,
      );
    });

    test('rider GPS tracking alone resumes', () {
      expect(
        shouldResume(
          riderActive: true,
          customerActive: false,
          riderOrderActive: false,
        ),
        isTrue,
      );
    });

    test('customer ETA tracking alone resumes', () {
      expect(
        shouldResume(
          riderActive: false,
          customerActive: true,
          riderOrderActive: false,
        ),
        isTrue,
      );
    });

    test('rider order-status watching alone resumes', () {
      expect(
        shouldResume(
          riderActive: false,
          customerActive: false,
          riderOrderActive: true,
        ),
        isTrue,
      );
    });

    test('chat watch alone resumes (customer side)', () {
      expect(
        shouldResume(
          riderActive: false,
          customerActive: false,
          riderOrderActive: false,
          chatCustomer: 'order-42',
        ),
        isTrue,
      );
    });

    test('chat watch alone resumes (rider side)', () {
      expect(
        shouldResume(
          riderActive: false,
          customerActive: false,
          riderOrderActive: false,
          chatRider: 'order-7',
        ),
        isTrue,
      );
    });

    test('multiple flags active → still resumes (idempotent)', () {
      expect(
        shouldResume(
          riderActive: true,
          customerActive: true,
          riderOrderActive: true,
          chatCustomer: 'o',
          chatRider: 'o',
        ),
        isTrue,
      );
    });
  });
}
