/// Connect Wallet Screen - WalletConnect v2 integration.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ledger_flutter/ledger_flutter.dart' as lf;

import '../../../../core/services/ledger_service.dart';
import '../../../../shared/providers/reown_provider.dart';
import '../../../../shared/providers/ledger_provider.dart';

/// Screen for connecting external wallets via WalletConnect v2.
class ConnectWalletScreen extends ConsumerStatefulWidget {
  const ConnectWalletScreen({super.key});

  @override
  ConsumerState<ConnectWalletScreen> createState() => _ConnectWalletScreenState();
}

class _ConnectWalletScreenState extends ConsumerState<ConnectWalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isLedgerScanning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeReown();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeReown() async {
    final service = ref.read(reownServiceProvider);
    
    // TODO: Replace with your WalletConnect Cloud project ID
    // Get one at https://cloud.walletconnect.com
    await service.initialize(projectId: 'YOUR_PROJECT_ID');
    
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _createPairing() async {
    setState(() => _isLoading = true);
    
    final service = ref.read(reownServiceProvider);
    final uri = await service.createPairing();
    
    if (uri != null) {
      // Also propose session after pairing
      await service.proposeEvmSession(chainIds: [1, 137]); // Eth + Polygon
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnect() async {
    await ref.read(reownServiceProvider).disconnect();
  }

  void _copyUri() {
    final uri = ref.read(reownServiceProvider).pairingUri;
    if (uri != null) {
      Clipboard.setData(ClipboardData(text: uri));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URI copied to clipboard')),
      );
    }
  }

  Future<void> _scanLedger() async {
    setState(() => _isLedgerScanning = true);
    await ref.read(ledgerServiceProvider).scanForDevices();
    if (mounted) {
      setState(() => _isLedgerScanning = false);
    }
  }

  Future<void> _connectLedger(lf.LedgerDevice device) async {
    setState(() => _isLedgerScanning = true); // reused for connecting indicator
    await ref.read(ledgerServiceProvider).connect(device);
    if (mounted) {
      setState(() => _isLedgerScanning = false);
    }
  }

  Future<void> _disconnectLedger() async {
    await ref.read(ledgerServiceProvider).disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Wallet'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'WalletConnect', icon: Icon(Icons.qr_code_scanner)),
            Tab(text: 'Hardware', icon: Icon(Icons.usb)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildReownTab(),
            _buildLedgerTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildReownTab() {
    final service = ref.watch(reownServiceProvider);
    final status = service.status;
    final wallet = service.connectedWallet;
    final pairingUri = service.pairingUri;
    final error = service.error;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: _buildContent(status, wallet, pairingUri, error),
    );
  }

  Widget _buildLedgerTab() {
    final status = ref.watch(ledgerConnectionStatusProvider);
    final devices = ref.watch(discoveredDevicesProvider);
    final connectedDevice = ref.watch(connectedLedgerDeviceProvider);
    final error = ref.watch(ledgerErrorProvider);

    if (status == LedgerStatus.connected && connectedDevice != null) {
      return _buildLedgerConnectedState(connectedDevice);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: devices.isEmpty && !_isLedgerScanning
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_searching, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          'No devices found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Make sure Bluetooth is on and your Ledger is in the Ethereum app.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.usb),
                          title: Text(device.name),
                          subtitle: Text(device.id),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _connectLedger(device),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLedgerScanning ? null : _scanLedger,
              icon: _isLedgerScanning 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.refresh),
              label: Text(_isLedgerScanning ? 'Scanning...' : 'Scan for Devices'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerConnectedState(lf.LedgerDevice device) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.usb,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ledger Connected!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            device.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _disconnectLedger,
            icon: const Icon(Icons.link_off),
            label: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    ReownConnectionStatus status,
    ConnectedWallet? wallet,
    String? pairingUri,
    String? error,
  ) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == ReownConnectionStatus.sessionActive && wallet != null) {
      return _buildConnectedState(wallet);
    }

    if (status == ReownConnectionStatus.sessionPending && pairingUri != null) {
      return _buildQrCodeState(pairingUri);
    }

    return _buildDisconnectedState(error);
  }

  Widget _buildDisconnectedState(String? error) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.qr_code_2,
          size: 80,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 24),
        Text(
          'WalletConnect',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Scan QR code with your mobile wallet to connect.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _createPairing,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code),
            label: Text(_isLoading ? 'Connecting...' : 'New Connection'),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeState(String pairingUri) {
    return Column(
      children: [
        Text(
          'Scan with Wallet',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Open your wallet app and scan this QR code',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: pairingUri,
            version: QrVersions.auto,
            size: 250,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _copyUri,
              icon: const Icon(Icons.copy),
              label: const Text('Copy URI'),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          'Waiting for connection...',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildConnectedState(ConnectedWallet wallet) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: wallet.walletIcon != null
              ? ClipOval(
                  child: Image.network(
                    wallet.walletIcon!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.check_circle,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
              : Icon(
                  Icons.check_circle,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
        ),
        const SizedBox(height: 24),
        Text(
          'Wallet Connected!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        if (wallet.walletName != null)
          Text(
            wallet.walletName!,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'Address',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              SelectableText(
                '${wallet.address.substring(0, 6)}...${wallet.address.substring(wallet.address.length - 4)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Chain ID',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              Text(
                wallet.chainId.toString(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect'),
            ),
          ],
        ),
      ],
    );
  }
}
