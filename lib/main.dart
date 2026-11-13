import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:candlesticks/candlesticks.dart';

void main() => runApp(const CryptoTradingApp());

class CryptoTradingApp extends StatelessWidget {
  const CryptoTradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0E11),
        cardColor: const Color(0xFF181A20),
      ),
      home: const TradingDashboard(),
    );
  }
}

class TradingDashboard extends StatefulWidget {
  const TradingDashboard({super.key});

  @override
  State<TradingDashboard> createState() => _TradingDashboardState();
}

class _TradingDashboardState extends State<TradingDashboard> {
  String selectedSymbol = 'BTCUSDT';
  String selectedTimeframe = '15m';
  String tradeMode = 'SPOT';
  double leverage = 10.0;
  double currentPrice = 0.0;
  double supportLevel = 0.0;
  double resistanceLevel = 0.0;
  String botSignal = 'Inachambua soko...';
  String botReason = '';
  Color signalColor = Colors.amber;

  List<Candle> candles = [];
  List<String> notifications = [];
  final TextEditingController amountController = TextEditingController();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    scanMarket();
    timer = Timer.periodic(const Duration(seconds: 10), (_) => scanMarket());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> scanMarket() async {
    final url = Uri.parse(
        'https://api.binance.com/api/v3/klines?symbol=$selectedSymbol&interval=$selectedTimeframe&limit=60');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<Candle> fetchedCandles = [];
        List<double> closes = [];
        double minLow = double.infinity;
        double maxHigh = 0.0;

        for (var item in data) {
          double open = double.parse(item[1].toString());
          double high = double.parse(item[2].toString());
          double low = double.parse(item[3].toString());
          double close = double.parse(item[4].toString());
          double volume = double.parse(item[5].toString());

          closes.add(close);
          if (low < minLow) minLow = low;
          if (high > maxHigh) maxHigh = high;

          fetchedCandles.add(Candle(
            date: DateTime.fromMillisecondsSinceEpoch(item[0]),
            high: high,
            low: low,
            open: open,
            close: close,
            volume: volume,
          ));
        }

        double ema9 = _calculateEMA(closes, 9);
        double ema21 = _calculateEMA(closes, 21);
        String newSignal = 'SUBIRI (NEUTRAL)';
        String reason = 'Soko halina mwelekeo thabiti.';
        Color sColor = Colors.amber;

        if (ema9 > ema21) {
          newSignal = 'NUNUA (BUY)';
          reason = 'Mwelekeo wa kupanda (EMA9 imevuka EMA21 juu).';
          sColor = const Color(0xFF0ECB81);
        } else if (ema9 < ema21) {
          newSignal = 'UZA (SELL)';
          reason = 'Mwelekeo wa kushuka (EMA9 iko chini ya EMA21).';
          sColor = const Color(0xFFF6465D);
        }

        setState(() {
          candles = fetchedCandles.reversed.toList();
          currentPrice = closes.last;
          supportLevel = minLow;
          resistanceLevel = maxHigh;
          botSignal = newSignal;
          botReason = reason;
          signalColor = sColor;
        });

        _addNotification('Scan ($selectedSymbol $selectedTimeframe): $newSignal');
      }
    } catch (e) {
      _addNotification('Hitilafu ya mtandao: Imeshindwa kupata data.');
    }
  }

  double _calculateEMA(List<double> prices, int period) {
    double multiplier = 2 / (period + 1);
    double ema = prices.take(period).reduce((a, b) => a + b) / period;
    for (int i = period; i < prices.length; i++) {
      ema = (prices[i] - ema) * multiplier + ema;
    }
    return ema;
  }

  void _addNotification(String msg) {
    setState(() {
      notifications.insert(0, '[${TimeOfDay.now().format(context)}] $msg');
      if (notifications.length > 10) notifications.removeLast();
    });
  }

  void _executeOrder(String side) {
    String amount = amountController.text.isEmpty ? '50' : amountController.text;
    String levText = tradeMode == 'FUTURES' ? ' (${leverage.toInt()}x)' : '';
    _addNotification('ODA IMETUMWA: $side $selectedSymbol \$$amount [$tradeMode$levText]');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Oda ya $side imewekwa kikamilifu!'),
        backgroundColor: side == 'BUY' ? const Color(0xFF0ECB81) : const Color(0xFFF6465D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto Live Pro', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF181A20),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: scanMarket),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: selectedSymbol,
                  items: ['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'BNBUSDT', 'XRPUSDT']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => selectedSymbol = val!);
                    scanMarket();
                  },
                ),
                DropdownButton<String>(
                  value: selectedTimeframe,
                  items: ['1m', '5m', '15m', '1h', '4h', '1d']
                      .map((tf) => DropdownMenuItem(value: tf, child: Text(tf)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => selectedTimeframe = val!);
                    scanMarket();
                  },
                ),
                Text(
                  '\$${currentPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0ECB81)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 320,
              decoration: BoxDecoration(
                color: const Color(0xFF181A20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: candles.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : Candlesticks(candles: candles),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Boti la Uchambuzi:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(botSignal, style: TextStyle(fontWeight: FontWeight.bold, color: signalColor, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(botReason, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Support: \$${supportLevel.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF0ECB81))),
                        Text('Resistance: \$${resistanceLevel.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFF6465D))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('SPOT TRADE')),
                            selected: tradeMode == 'SPOT',
                            onSelected: (_) => setState(() => tradeMode = 'SPOT'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('FUTURES TRADE')),
                            selected: tradeMode == 'FUTURES',
                            onSelected: (_) => setState(() => tradeMode = 'FUTURES'),
                          ),
                        ),
                      ],
                    ),
                    if (tradeMode == 'FUTURES') ...[
                      const SizedBox(height: 10),
                      Text('Leverage: ${leverage.toInt()}x'),
                      Slider(
                        value: leverage,
                        min: 1,
                        max: 100,
                        divisions: 99,
                        onChanged: (val) => setState(() => leverage = val),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kiasi cha USDT',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0ECB81), foregroundColor: Colors.black),
                            onPressed: () => _executeOrder('BUY'),
                            child: const Text('BUY / LONG', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF6465D), foregroundColor: Colors.white),
                            onPressed: () => _executeOrder('SELL'),
                            child: const Text('SELL / SHORT', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Arifa za Soko (Live Logs)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...notifications.map((n) => Text(n, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          ],
        ),
      ),
    );
  }
}
