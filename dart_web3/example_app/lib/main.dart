import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: Web3WalletApp(),
    ),
  );
}

// Assuming Web3WalletApp is defined in 'app.dart' and looks something like this:
// class Web3WalletApp extends ConsumerWidget {
//   const Web3WalletApp({super.key});

//   @override
//       ],
//       routerConfig: router,
//     );
//   }
// }
