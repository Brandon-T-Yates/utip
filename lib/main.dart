import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const UtipApp());
}

class UtipApp extends StatefulWidget {
  const UtipApp({super.key});

  @override
  UtipAppState createState() => UtipAppState();
}

class UtipAppState extends State<UtipApp> {
  bool _isDarkMode = false;
  bool _isLargeText = false; // NEW

  final Color primaryColor = const Color(0xFF99DB8F);
  final Color darkModeColor = const Color.fromARGB(255, 64, 165, 64);
  final Color darkBackgroundColor = const Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _isLargeText = prefs.getBool('isLargeText') ?? false;
    });
  }

  Future<void> _saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  Future<void> _saveTextScalePreference(bool isLargeText) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLargeText', isLargeText);
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    _saveThemePreference(_isDarkMode);
  }

  void _toggleTextScale() {
    setState(() {
      _isLargeText = !_isLargeText;
    });
    _saveTextScalePreference(_isLargeText);
  }

  @override
  Widget build(BuildContext context) {
    // Pick a scale factor. You can tune these numbers.
    // 1.0 = normal, 1.3 = large (still fits on small screens)
    final double scaleFactor = _isLargeText ? 1.3 : 1.0;

    final ThemeData baseTheme = _isDarkMode
        ? ThemeData.dark().copyWith(
            primaryColor: darkModeColor,
            scaffoldBackgroundColor: darkBackgroundColor,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: darkModeColor,
              ),
            ),
          )
        : ThemeData.light().copyWith(
            primaryColor: primaryColor,
            scaffoldBackgroundColor: Colors.white,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: primaryColor,
              ),
            ),
          );

    return MaterialApp(
      title: 'uTip',
      theme: baseTheme,
      debugShowCheckedModeBanner: false,

      // builder lets us inject our own MediaQuery to scale text app-wide
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(scaleFactor),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: TipCalculator(
        isDarkMode: _isDarkMode,
        onThemeToggle: _toggleTheme,
        primaryColor: primaryColor,
        darkModeColor: darkModeColor,
        isLargeText: _isLargeText,          // pass down
        onTextScaleToggle: _toggleTextScale // pass down
      ),
    );
  }
}

class TipCalculator extends StatefulWidget {
  final bool isDarkMode;
  final bool isLargeText; // NEW
  final VoidCallback onThemeToggle;
  final VoidCallback onTextScaleToggle; // NEW
  final Color primaryColor;
  final Color darkModeColor;

  const TipCalculator({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.primaryColor,
    required this.darkModeColor,
    required this.isLargeText,
    required this.onTextScaleToggle,
  });

  @override
  TipCalculatorState createState() => TipCalculatorState();
}

class TipCalculatorState extends State<TipCalculator> {
  double bill = 0.0;
  double tipPercent = 15.0;
  double tipAmount = 0.0;
  double totalAmount = 0.0;
  double roundedTipPercent = 0.0;
  bool isRounding = false;

  final TextEditingController _billController = TextEditingController();
  final FocusNode _billFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _billController.addListener(calculate);
  }

  @override
  void dispose() {
    _billController.dispose();
    _billFocusNode.dispose();
    super.dispose();
  }

  void calculate() {
    setState(() {
      final text = _billController.text.trim();
      bill = double.tryParse(text) ?? 0.0;

      if (bill > 0) {
        tipAmount = bill * (tipPercent / 100);
        totalAmount = bill + tipAmount;
        // don't automatically kill rounding state here
      } else {
        tipAmount = 0.0;
        totalAmount = 0.0;
        roundedTipPercent = 0.0;
        isRounding = false;
      }
    });
  }

  void roundUp() {
    if (bill > 0) {
      final tempTotal = totalAmount;
      final roundedUpTotal = tempTotal.ceil();
      final adjustedTipPercent =
          (roundedUpTotal - bill) / bill * 100;

      setState(() {
        roundedTipPercent = adjustedTipPercent;
        tipPercent = roundedTipPercent.clamp(0.0, 30.0);
        calculate();
        isRounding = true;
      });
    }
  }

  void roundDown() {
    if (bill > 0) {
      final tempTotal = totalAmount;
      final roundedDownTotal = tempTotal.floor();
      final adjustedTipPercent =
          (roundedDownTotal - bill) / bill * 100;

      setState(() {
        roundedTipPercent = adjustedTipPercent;
        tipPercent = roundedTipPercent.clamp(0.0, 30.0);
        calculate();
        isRounding = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = widget.isDarkMode;
    final Color panelColor = dark ? widget.darkModeColor : widget.primaryColor;
    final Color textOnPanel = dark ? Colors.white : Colors.black;
    final Color bgColor =
        dark ? const Color(0xFF121212) : Colors.white;

    return GestureDetector(
      onTap: () {
        if (_billFocusNode.hasFocus) {
          _billFocusNode.unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            'uTip',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 26, // this will still get scaled by textScaleFactor
              color: dark ? Colors.white : Colors.black,
            ),
          ),
          centerTitle: true,
          backgroundColor: panelColor,

          // ACCESSIBILITY: Add tooltips so VoiceOver/TalkBack reads them
          actions: [
            IconButton(
              icon: Icon(
                widget.isLargeText
                    ? Icons.text_decrease
                    : Icons.text_increase,
                color: dark ? Colors.white : Colors.black,
              ),
              tooltip: widget.isLargeText
                  ? 'Reduce text size'
                  : 'Increase text size',
              onPressed: widget.onTextScaleToggle,
            ),
            IconButton(
              icon: Icon(
                dark ? Icons.wb_sunny : Icons.nightlight_round,
                color: dark ? Colors.white : Colors.black,
              ),
              tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
              onPressed: widget.onThemeToggle,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Bill / Tip box
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8.0),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Bill row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bill:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textOnPanel,
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _billController,
                            focusNode: _billFocusNode,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'),
                              ),
                              LengthLimitingTextInputFormatter(10),
                            ],
                            onChanged: (_) => calculate(),
                            style: TextStyle(
                              fontSize:
                                  _billController.text.isEmpty ? 16 : 18,
                              fontWeight: _billController.text.isEmpty
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              color: textOnPanel,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter Bill',
                              prefixText: '\$',
                              labelStyle: TextStyle(
                                color: textOnPanel.withValues(alpha: 0.8),
                              ),
                              hintStyle: TextStyle(
                                color: textOnPanel.withValues(alpha: 0.8),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: textOnPanel.withValues(alpha: 0.8),
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: textOnPanel,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tip row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tip:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textOnPanel,
                          ),
                        ),
                        Text(
                          '\$${tipAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textOnPanel,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tip Percentage row with slider
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'Tip Percentage:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textOnPanel,
                          ),
                        ),

                        // Slider should be accessible: wrap in Semantics
                        Expanded(
                          child: Semantics(
                            label: 'Tip percentage slider',
                            // This will be read like "Tip percentage slider, 19 percent"
                            value:
                                '${tipPercent.toStringAsFixed(0)} percent',
                            increasedValue:
                                '${(tipPercent + 1).clamp(0, 30).toStringAsFixed(0)} percent',
                            decreasedValue:
                                '${(tipPercent - 1).clamp(0, 30).toStringAsFixed(0)} percent',
                            hint:
                                'Swipe up or right to increase. Swipe down or left to decrease.',
                            child: Slider(
                              value: tipPercent,
                              min: 0,
                              max: 30,
                              divisions: 30,
                              label:
                                  '${tipPercent.toStringAsFixed(0)}%',
                              onChanged: (newValue) {
                                if (bill > 0) {
                                  setState(() {
                                    tipPercent = newValue;
                                    calculate();
                                    isRounding = false;
                                  });
                                }
                              },
                              activeColor: dark
                                  ? Colors.white
                                  : Colors.black,
                              inactiveColor: Colors.grey,
                            ),
                          ),
                        ),

                        Text(
                          '${isRounding ? roundedTipPercent.toStringAsFixed(2)
                                         : tipPercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textOnPanel,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Total box
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8.0),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textOnPanel,
                      ),
                    ),
                    Text(
                      '\$${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textOnPanel,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Center(
                child: Column(
                  children: [
                    Semantics(
                      // Help screen reader announce what this does
                      button: true,
                      label:
                          'Round up to nearest whole dollar total',
                      child: ElevatedButton(
                        onPressed: roundUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: panelColor,
                          foregroundColor: textOnPanel,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Round up to nearest dollar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      button: true,
                      label:
                          'Round down to nearest whole dollar total',
                      child: ElevatedButton(
                        onPressed: roundDown,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: panelColor,
                          foregroundColor: textOnPanel,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Round down to nearest dollar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
