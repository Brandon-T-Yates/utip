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

  final Color primaryColor =
      Color(0xFF99DB8F); // Light mode primary color (green)
  final Color darkModeColor =
      Color.fromARGB(255, 26, 126, 26); // Dark mode primary color (dark green)
  final Color darkBackgroundColor =
      Color(0xFF121212); // Lighter black background color in dark mode

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  // Function to load saved theme preference
  void _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ??
          false; // Default to light mode if not saved
    });
  }

  // Function to save theme preference
  void _saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'uTip',
      theme: _isDarkMode
          ? ThemeData.dark().copyWith(
              primaryColor: darkModeColor, // Use dark green in dark mode
              scaffoldBackgroundColor:
                  darkBackgroundColor, // Set a lighter black background
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor:
                      darkModeColor, // White text color in dark mode
                ),
              ),
            )
          : ThemeData.light().copyWith(
              primaryColor: primaryColor, // Use light green in light mode
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor:
                      primaryColor, // Black text color in light mode
                ),
              ),
            ),
      debugShowCheckedModeBanner: false,
      home: TipCalculator(
        isDarkMode: _isDarkMode,
        onThemeToggle: _toggleTheme,
        primaryColor: primaryColor,
        darkModeColor: darkModeColor,
      ),
    );
  }

  // Function to toggle between light and dark themes
  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      _saveThemePreference(_isDarkMode); // Save the user's theme preference
    });
  }
}

class TipCalculator extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final Color primaryColor;
  final Color darkModeColor;

  const TipCalculator({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.primaryColor,
    required this.darkModeColor,
  });

  @override
  TipCalculatorState createState() => TipCalculatorState();
}

class TipCalculatorState extends State<TipCalculator> {
  // Initial values
  double bill = 0.0;
  double tipPercent = 15.0;
  double tipAmount = 0.0;
  double totalAmount = 0.0;
  double roundedTipPercent = 0.0;
  bool isRounding = false;

  final TextEditingController _billController = TextEditingController();
  final FocusNode _billFocusNode = FocusNode(); // Add FocusNode

  void calculate() {
  setState(() {
    final text = _billController.text.trim();
    bill = double.tryParse(text) ?? 0.0;

    if (bill > 0) {
      tipAmount = bill * (tipPercent / 100);
      totalAmount = bill + tipAmount;
      // keep current rounding state as-is
    } else {
      // When input is empty or zero, clear computed values & rounding state
      tipAmount = 0.0;
      totalAmount = 0.0;
      roundedTipPercent = 0.0;
      isRounding = false;
    }
  });
}

  void roundUp() {
    if (bill > 0) {
      double tempTotal = totalAmount;
      int roundedUpTotal = tempTotal.ceil();
      double adjustedTipPercent = (roundedUpTotal - bill) / bill * 100;

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
      double tempTotal = totalAmount;
      int roundedDownTotal = tempTotal.floor();
      double adjustedTipPercent = (roundedDownTotal - bill) / bill * 100;

      setState(() {
        roundedTipPercent = adjustedTipPercent;
        tipPercent = roundedTipPercent.clamp(0.0, 30.0);
        calculate();
        isRounding = true;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping anywhere else
        if (!_billFocusNode.hasFocus) return;
        _billFocusNode.unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'uTip',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          centerTitle: true,
          backgroundColor:
              widget.isDarkMode ? widget.darkModeColor : widget.primaryColor,
          actions: [
            IconButton(
              icon: Icon(
                widget.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
                color: widget.isDarkMode
                    ? Colors.white
                    : Colors.black, // Change icon color
              ),
              onPressed: widget.onThemeToggle,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Bill and Tip Inputs
              Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? widget.darkModeColor
                      : widget.primaryColor,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 8.0)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Bill:",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : Colors.black)),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _billController,
                            focusNode: _billFocusNode,
                            keyboardType: TextInputType.numberWithOptions(
                                decimal:
                                    true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(
                                  r'^\d+\.?\d{0,2}')),
                              LengthLimitingTextInputFormatter(
                                  10),
                            ],
                            onChanged: (_) => calculate(),
                            style: TextStyle(
                              fontSize: _billController.text.isEmpty ? 16 : 18,
                              fontWeight: _billController.text.isEmpty
                                  ? FontWeight.normal
                                  : FontWeight
                                      .bold, 
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter Bill',
                              prefixText: '\$', 
                              hintStyle: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : Colors
                                        .black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Tip:",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode
                                ? Colors.white
                                : Colors
                                    .black, // Adjust text color based on the theme
                          ),
                        ),
                        Text(
                          '\$${tipAmount.toStringAsFixed(2)}', // Display the formatted tip amount
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode
                                ? Colors.white
                                : Colors
                                    .black, // Adjust text color based on the theme
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Text("Tip Percentage:",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : Colors.black)),
                        Expanded(
                          child: Slider(
                            value: tipPercent,
                            min: 0,
                            max: 30,
                            divisions: 30,
                            label: '${tipPercent.toStringAsFixed(0)}%',
                            onChanged: (newValue) {
                              if (bill > 0) {
                                setState(() {
                                  tipPercent = newValue;
                                  calculate();
                                  isRounding = false;
                                });
                              }
                            },
                            activeColor:
                                widget.isDarkMode ? Colors.white : Colors.black,
                            inactiveColor: Colors.grey,
                          ),
                        ),
                        Text(
                          '${isRounding ? roundedTipPercent.toStringAsFixed(2) : tipPercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : Colors.black),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Total Amount Box
              Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? widget.darkModeColor
                      : widget.primaryColor,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 8.0)
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total:",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode
                                ? Colors.white
                                : Colors.black)),
                    Text(
                      '\$${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              widget.isDarkMode ? Colors.white : Colors.black),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Two buttons for rounding (centered and primary color)
              Center(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: roundUp,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: widget.isDarkMode
                            ? widget.darkModeColor
                            : widget.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: Text(
                        "Round up to nearest dollar",
                        style: TextStyle(
                          color:
                              widget.isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: roundDown,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: widget.isDarkMode
                            ? widget.darkModeColor
                            : widget.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: Text(
                        "Round down to nearest dollar",
                        style: TextStyle(
                          color:
                              widget.isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
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
