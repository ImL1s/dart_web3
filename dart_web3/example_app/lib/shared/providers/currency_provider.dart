import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'currency_provider.g.dart';

enum Currency {
  usd('USD', '\$'),
  eur('EUR', '€'),
  twd('TWD', 'NT\$'),
  jpy('JPY', '¥');

  final String code;
  final String symbol;
  const Currency(this.code, this.symbol);
}

@riverpod
class CurrencyNotifier extends _$CurrencyNotifier {
  static const _key = 'currency';

  @override
  Currency build() {
    _loadState();
    return Currency.usd;
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = Currency.values.firstWhere(
        (e) => e.code == saved,
        orElse: () => Currency.usd,
      );
    }
  }

  Future<void> setCurrency(Currency currency) async {
    state = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, currency.code);
  }
}
