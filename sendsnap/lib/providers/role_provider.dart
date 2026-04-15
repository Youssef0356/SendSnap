import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TransferRole {
  sender,
  receiver,
  unset,
}

/// Provider for the current transfer role (Send vs Receive).
final transferRoleProvider = StateProvider<TransferRole>((ref) => TransferRole.unset);
