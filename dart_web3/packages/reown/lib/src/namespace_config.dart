/// Namespace configuration for WalletConnect v2 protocol.
library;

import 'package:meta/meta.dart';

/// Represents a namespace configuration for WalletConnect v2.
///
/// Namespaces define which chains and methods are supported in a session.
@immutable
class NamespaceConfig {
  NamespaceConfig({
    required this.namespace,
    required this.chains,
    required this.methods,
    required this.events,
    this.accounts = const [],
    this.extension,
  });

  /// Creates a namespace config from JSON.
  factory NamespaceConfig.fromJson(
      String namespace, Map<String, dynamic> json) {
    return NamespaceConfig(
      namespace: namespace,
      chains: (json['chains'] as List?)?.cast<String>() ?? [],
      methods: (json['methods'] as List).cast<String>(),
      events: (json['events'] as List).cast<String>(),
      accounts: (json['accounts'] as List?)?.cast<String>() ?? [],
      extension: json['extension'] as Map<String, dynamic>?,
    );
  }

  /// The namespace identifier (e.g., 'eip155' for Ethereum).
  final String namespace;

  /// List of supported chains in CAIP-2 format (e.g., 'eip155:1' for Ethereum mainnet).
  final List<String> chains;

  /// List of supported methods (e.g., 'eth_sendTransaction', 'personal_sign').
  final List<String> methods;

  /// List of supported events (e.g., 'chainChanged', 'accountsChanged').
  final List<String> events;

  /// List of accounts in CAIP-10 format (e.g., 'eip155:1:0x123...').
  final List<String> accounts;

  /// Optional extension data.
  final Map<String, dynamic>? extension;

  /// Converts the namespace config to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'chains': chains,
      'methods': methods,
      'events': events,
    };

    if (accounts.isNotEmpty) {
      json['accounts'] = accounts;
    }

    if (extension != null) {
      json['extension'] = extension;
    }

    return json;
  }

  /// Creates a copy with updated values.
  NamespaceConfig copyWith({
    String? namespace,
    List<String>? chains,
    List<String>? methods,
    List<String>? events,
    List<String>? accounts,
    Map<String, dynamic>? extension,
  }) {
    return NamespaceConfig(
      namespace: namespace ?? this.namespace,
      chains: chains ?? this.chains,
      methods: methods ?? this.methods,
      events: events ?? this.events,
      accounts: accounts ?? this.accounts,
      extension: extension ?? this.extension,
    );
  }

  /// Checks if this namespace supports a specific chain.
  bool supportsChain(String chainId) {
    return chains.contains('$namespace:$chainId') || chains.contains(chainId);
  }

  /// Checks if this namespace supports a specific method.
  bool supportsMethod(String method) {
    return methods.contains(method);
  }

  /// Checks if this namespace supports a specific event.
  bool supportsEvent(String event) {
    return events.contains(event);
  }

  /// Adds an account to this namespace.
  NamespaceConfig addAccount(String account) {
    // ignore: avoid_returning_this
    if (accounts.contains(account)) return this;
    return copyWith(accounts: [...accounts, account]);
  }

  /// Removes an account from this namespace.
  NamespaceConfig removeAccount(String account) {
    // ignore: avoid_returning_this
    if (!accounts.contains(account)) return this;
    return copyWith(accounts: accounts.where((a) => a != account).toList());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NamespaceConfig &&
          runtimeType == other.runtimeType &&
          namespace == other.namespace &&
          _listEquals(chains, other.chains) &&
          _listEquals(methods, other.methods) &&
          _listEquals(events, other.events) &&
          _listEquals(accounts, other.accounts) &&
          _mapEquals(extension, other.extension);

  @override
  int get hashCode =>
      namespace.hashCode ^
      chains.hashCode ^
      methods.hashCode ^
      events.hashCode ^
      accounts.hashCode ^
      (extension?.hashCode ?? 0);

  @override
  String toString() {
    return 'NamespaceConfig(namespace: $namespace, chains: $chains, methods: $methods, events: $events, accounts: $accounts)';
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (var index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  bool _mapEquals<T, U>(Map<T, U>? a, Map<T, U>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }
}

/// Predefined namespace configurations for common blockchains.
class NamespaceConfigs {
  NamespaceConfigs._();

  /// Ethereum namespace configuration.
  static NamespaceConfig ethereum({
    List<String>? chains,
    List<String>? methods,
    List<String>? events,
    List<String>? accounts,
  }) {
    return NamespaceConfig(
      namespace: 'eip155',
      chains: chains ??
          [
            'eip155:1', // Ethereum Mainnet
            'eip155:5', // Goerli
            'eip155:11155111', // Sepolia
          ],
      methods: methods ??
          [
            'eth_sendTransaction',
            'eth_signTransaction',
            'eth_sign',
            'personal_sign',
            'eth_signTypedData',
            'eth_signTypedData_v3',
            'eth_signTypedData_v4',
            'wallet_switchEthereumChain',
            'wallet_addEthereumChain',
            'wallet_watchAsset',
          ],
      events: events ??
          [
            'chainChanged',
            'accountsChanged',
            'connect',
            'disconnect',
          ],
      accounts: accounts ?? [],
    );
  }

  /// Polygon namespace configuration.
  static NamespaceConfig polygon({
    List<String>? chains,
    List<String>? methods,
    List<String>? events,
    List<String>? accounts,
  }) {
    return NamespaceConfig(
      namespace: 'eip155',
      chains: chains ??
          [
            'eip155:137', // Polygon Mainnet
            'eip155:80001', // Mumbai Testnet
          ],
      methods: methods ??
          [
            'eth_sendTransaction',
            'eth_signTransaction',
            'eth_sign',
            'personal_sign',
            'eth_signTypedData',
            'eth_signTypedData_v4',
          ],
      events: events ??
          [
            'chainChanged',
            'accountsChanged',
          ],
      accounts: accounts ?? [],
    );
  }

  /// Arbitrum namespace configuration.
  static NamespaceConfig arbitrum({
    List<String>? chains,
    List<String>? methods,
    List<String>? events,
    List<String>? accounts,
  }) {
    return NamespaceConfig(
      namespace: 'eip155',
      chains: chains ??
          [
            'eip155:42161', // Arbitrum One
            'eip155:421613', // Arbitrum Goerli
          ],
      methods: methods ??
          [
            'eth_sendTransaction',
            'eth_signTransaction',
            'eth_sign',
            'personal_sign',
            'eth_signTypedData_v4',
          ],
      events: events ??
          [
            'chainChanged',
            'accountsChanged',
          ],
      accounts: accounts ?? [],
    );
  }

  /// Optimism namespace configuration.
  static NamespaceConfig optimism({
    List<String>? chains,
    List<String>? methods,
    List<String>? events,
    List<String>? accounts,
  }) {
    return NamespaceConfig(
      namespace: 'eip155',
      chains: chains ??
          [
            'eip155:10', // Optimism Mainnet
            'eip155:420', // Optimism Goerli
          ],
      methods: methods ??
          [
            'eth_sendTransaction',
            'eth_signTransaction',
            'eth_sign',
            'personal_sign',
            'eth_signTypedData_v4',
          ],
      events: events ??
          [
            'chainChanged',
            'accountsChanged',
          ],
      accounts: accounts ?? [],
    );
  }

  /// BSC (Binance Smart Chain) namespace configuration.
  static NamespaceConfig bsc({
    List<String>? chains,
    List<String>? methods,
    List<String>? events,
    List<String>? accounts,
  }) {
    return NamespaceConfig(
      namespace: 'eip155',
      chains: chains ??
          [
            'eip155:56', // BSC Mainnet
            'eip155:97', // BSC Testnet
          ],
      methods: methods ??
          [
            'eth_sendTransaction',
            'eth_signTransaction',
            'eth_sign',
            'personal_sign',
            'eth_signTypedData_v4',
          ],
      events: events ??
          [
            'chainChanged',
            'accountsChanged',
          ],
      accounts: accounts ?? [],
    );
  }

  /// Solana namespace configuration.
  static NamespaceConfig solana({
    List<String>? chains,
    List<String>? methods,
    List<String>? events,
    List<String>? accounts,
  }) {
    return NamespaceConfig(
      namespace: 'solana',
      chains: chains ??
          [
            'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp', // Mainnet
            'solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1', // Devnet
          ],
      methods: methods ??
          [
            'solana_signTransaction',
            'solana_signMessage',
            'solana_signAndSendTransaction',
          ],
      events: events ??
          [
            'accountsChanged',
            'chainChanged',
          ],
      accounts: accounts ?? [],
    );
  }

  /// Creates a multi-chain namespace configuration.
  static List<NamespaceConfig> multiChain({
    bool includeEthereum = true,
    bool includePolygon = false,
    bool includeArbitrum = false,
    bool includeOptimism = false,
    bool includeBsc = false,
    bool includeSolana = false,
    List<String>? accounts,
  }) {
    final namespaces = <NamespaceConfig>[];

    if (includeEthereum) {
      namespaces.add(ethereum(accounts: accounts));
    }
    if (includePolygon) {
      namespaces.add(polygon(accounts: accounts));
    }
    if (includeArbitrum) {
      namespaces.add(arbitrum(accounts: accounts));
    }
    if (includeOptimism) {
      namespaces.add(optimism(accounts: accounts));
    }
    if (includeBsc) {
      namespaces.add(bsc(accounts: accounts));
    }
    if (includeSolana) {
      namespaces.add(solana(accounts: accounts));
    }

    return namespaces;
  }

  /// Creates a custom EVM namespace configuration.
  static NamespaceConfig customEvm({
    required List<String> chainIds,
    List<String>? methods,
    List<String>? events,
    List<String>? accounts,
  }) {
    return NamespaceConfig(
      namespace: 'eip155',
      chains: chainIds.map((id) => 'eip155:$id').toList(),
      methods: methods ??
          [
            'eth_sendTransaction',
            'eth_signTransaction',
            'eth_sign',
            'personal_sign',
            'eth_signTypedData_v4',
          ],
      events: events ??
          [
            'chainChanged',
            'accountsChanged',
          ],
      accounts: accounts ?? [],
    );
  }
}

/// Utilities for working with CAIP identifiers.
class CaipUtils {
  CaipUtils._();

  /// Parses a CAIP-2 chain identifier.
  /// Format: namespace:reference
  /// Example: eip155:1
  static (String namespace, String reference) parseChainId(String chainId) {
    final parts = chainId.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid CAIP-2 chain ID format: $chainId');
    }
    return (parts[0], parts[1]);
  }

  /// Parses a CAIP-10 account identifier.
  /// Format: namespace:reference:account_address
  /// Example: eip155:1:0x1234567890123456789012345678901234567890
  static (String namespace, String reference, String address) parseAccountId(
      String accountId) {
    final parts = accountId.split(':');
    if (parts.length != 3) {
      throw ArgumentError('Invalid CAIP-10 account ID format: $accountId');
    }
    return (parts[0], parts[1], parts[2]);
  }

  /// Creates a CAIP-2 chain identifier.
  static String createChainId(String namespace, String reference) {
    return '$namespace:$reference';
  }

  /// Creates a CAIP-10 account identifier.
  static String createAccountId(
      String namespace, String reference, String address) {
    return '$namespace:$reference:$address';
  }

  /// Extracts the chain ID from an account ID.
  static String getChainIdFromAccount(String accountId) {
    final (namespace, reference, _) = parseAccountId(accountId);
    return createChainId(namespace, reference);
  }

  /// Extracts the address from an account ID.
  static String getAddressFromAccount(String accountId) {
    final (_, _, address) = parseAccountId(accountId);
    return address;
  }

  /// Checks if a chain ID is valid CAIP-2 format.
  static bool isValidChainId(String chainId) {
    try {
      parseChainId(chainId);
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  /// Checks if an account ID is valid CAIP-10 format.
  static bool isValidAccountId(String accountId) {
    try {
      parseAccountId(accountId);
      return true;
    } on Object catch (_) {
      return false;
    }
  }
}
