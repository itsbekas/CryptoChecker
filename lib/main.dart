import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desktop_window/desktop_window.dart';
import 'package:flutter/widgets.dart';
import 'binance/binance.dart';

/* Custom Colors */
var customColors = {
  'background': Color(0xFF212529),
  'primary': Color(0xFFd9d9d9),
  'secondary': Color(0xFFf94144),
  'neutral': Color(0xFFD1D1D1),
};

var rest = Binance();

String? selectedCurrency = 'EUR';
Map<String, IconData> currencyIcon = {
  'EUR': Icons.euro,
  'USDT': Icons.attach_money,
};

void main() => runApp(MyApp());

class RestartWidget extends StatefulWidget {
  RestartWidget({required this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()!.restartApp();
  }

  @override
  _RestartWidgetState createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Home() /*escape 'No MediaQuery widget found' error*/
        );
  }
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    // App warpped arround a RestartWidget needed to reload the app properly
    return RestartWidget(
      child: MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Container(
              child: Stack(
                children: <Widget>[
                  Container(
                    height: size.height,
                    child: BalanceWidget(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        // Create the currency button on top right with some padding
                        margin: const EdgeInsets.only(top: 25.0, right: 15.0),
                        alignment: Alignment.topRight,
                        child: CurrencyWidget(),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          backgroundColor: customColors['background']!,
        ),
      ),
    );
  }
}

class BalanceWidget extends StatefulWidget {
  @override
  _BalanceState createState() => _BalanceState();
}

class CurrencyWidget extends StatefulWidget {
  @override
  _CurrencyState createState() => _CurrencyState();
}

Future<Map<String, List<double>>> _getData(AccountInfo? acc) async {
  Map<String, List<double>> coinInfo = {};
  double total = 0;
  double avgPercentage = 0;

  for (Balance b in acc!.balances)
    if (b.free != 0) {
      AveragedPrice avg =
          await rest.averagePrice('${b.asset}$selectedCurrency');
      TickerStats stat = await rest.dailyStats('${b.asset}$selectedCurrency');

      coinInfo['${b.asset}'] = [
        avg.price * b.free,
        b.free,
        stat.priceChangePercent
      ];
    }

  coinInfo.forEach((key, value) {
    total += value.first;
  });
  coinInfo['Total'] = [total];

  coinInfo.forEach((key, value) {
    if (key != 'Total' && key != 'Percent')
      avgPercentage += value[2] * (value.first / total);
  });

  coinInfo['Percent'] = [avgPercentage];

  return coinInfo;
}

Container _printData(Map<String, List<double>> coinInfo) {
  return Container(
    margin: const EdgeInsets.only(bottom: 30),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (MapEntry entry in coinInfo.entries)
          if (entry.key != 'Total' && entry.key != 'Percent')
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${entry.key}: \n',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 25),
                ),
                Text(
                  '\n${entry.value[1]}\n${(entry.value[0]).toStringAsFixed(2)} $selectedCurrency\n${entry.value[2]} %',
                  style: TextStyle(fontSize: 22),
                ),
              ],
            ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\nTotal: ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
            ),
            Text(
                '\n${(coinInfo['Total']!.first).toStringAsFixed(2)} $selectedCurrency',
                style: TextStyle(fontSize: 22)),
          ],
        ),
      ],
    ),
  );
}

// Select currency Button with clickable dropdown
class _CurrencyState extends State<CurrencyWidget> {
  // Change the currency being used every time the function is called
  void _setCurrency() async {
    String curr = '';

    selectedCurrency == 'EUR' ? curr = 'USDT' : curr = 'EUR';

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', curr);

    if (mounted)
      setState(() {
        selectedCurrency = curr;
      });
  }

  // Save the currency preferences on the device
  void _getCurrency() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? currencyName = prefs.getString('currency');

    if (mounted)
      setState(() {
        if (currencyName != null) selectedCurrency = currencyName;
      });
  }

  // Returns the currency that is not beign used by the user
  String _currencyOption() {
    if (selectedCurrency == 'EUR') return 'USDT';
    return 'EUR';
  }

  // When the widget is created, get the currency preference
  @override
  void initState() {
    _getCurrency();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Wrapping the widget on a Theme so it's possible to disable splashColor and highlightColor
      // This is done in order to not see highlight artifacts arround the rounded border of the dropdown menu
      data: ThemeData(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        dividerColor: Colors.transparent,
      ),
      child: Container(
        // Width and position of the button
        width: 150,
        alignment: Alignment.topRight,
        child: Container(
          // Rounded borders on the ExpansionTile
          decoration: BoxDecoration(
            color: customColors['secondary'],
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
              bottom: Radius.circular(30),
            ),
          ),
          child: ExpansionTile(
            iconColor: Colors.black, // Change the color of the arrow
            // First Row with the current currency
            title: Row(
              children: <Widget>[
                Icon(
                  currencyIcon[selectedCurrency],
                  color: Colors.white,
                ),
                Text(
                  '  $selectedCurrency',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                )
              ],
            ),
            // Second row with the currency avaible to switch
            children: <Widget>[
              Container(
                height: 45.0,
                child: GestureDetector(
                  // onTap change the currency and reload the App
                  onTap: () {
                    _setCurrency();
                    RestartWidget.restartApp(context);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        currencyIcon[_currencyOption()],
                        color: Colors.white,
                      ),
                      Text(
                        '${_currencyOption()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceState extends State<BalanceWidget> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(
        Duration(minutes: 3), (Timer t) => RestartWidget.restartApp(context));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  SizedBox _myLoadingCircle() {
    return SizedBox(
      child: Center(
        child: CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(customColors['primary']!)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountInfo>(
      future: rest.accountInfo(DateTime.now().millisecondsSinceEpoch),
      builder: (BuildContext context, AsyncSnapshot<AccountInfo> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _myLoadingCircle();
        } else {
          return FutureBuilder<Map<String, List<double>>>(
            future: _getData(snapshot.data),
            builder: (context, snap) {
              if (snap.hasData)
                return Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 200),
                      child: Text(
                        '${snap.data!['Percent']!.first > 0 ? '+' : ''}${snap.data!['Percent']!.first.toStringAsFixed(2)}%',
                        style: TextStyle(
                            fontSize: 75,
                            color: snap.data!['Percent']!.first > 0
                                ? Colors.green
                                : Colors.red),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(top: 50),
                        decoration: BoxDecoration(
                          color: customColors['primary'],
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(50)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: _printData(snap.data!),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              return _myLoadingCircle();
            },
          );
        }
      },
    );
  }
}
