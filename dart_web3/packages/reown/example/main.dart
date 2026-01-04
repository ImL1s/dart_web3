import 'package:web3_universal_reown/web3_universal_reown.dart';

void main() async {
  // Initialize Reown AppKit/WalletConnect
  final appKit = ReownAppKit(
    projectId: 'YOUR_PROJECT_ID',
    metadata: {
      'name': 'Web3 Universal Example',
      'description': 'Dart Web3 Universal SDK Example',
      'url': 'https://github.com/ImL1s/web3_universal',
      'icons': ['https://reown.com/favicon.ico'],
    },
  );

  await appKit.init();
  print('Reown initialized');

  // appKit.onSessionEvent.subscribe((args) {
  //   print('Session Event: ${args}');
  // });
}
