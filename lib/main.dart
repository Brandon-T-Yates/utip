import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calculation/bill_input.dart';
import 'calculation/tip_calculation.dart';
import 'widgets/app_text_scaler.dart';
import 'widgets/bill_input_formatter.dart';

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
  bool _isLargeText = false;

  final Color primaryColor = const Color(0xFF99DB8F);
  final Color darkModeColor = const Color(0xFF203128);
  final Color darkBackgroundColor = const Color(0xFF101713);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
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
    final baseTheme = ThemeData(
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: _isDarkMode ? darkBackgroundColor : Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: primaryColor,
        onPrimary: _isDarkMode ? const Color(0xFF102015) : Colors.black,
        surface: _isDarkMode ? darkModeColor : Colors.white,
        onSurface: _isDarkMode ? const Color(0xFFEDF5EF) : Colors.black,
      ),
    );

    return MaterialApp(
      title: 'uTip',
      theme: baseTheme,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler:
                _isLargeText ? AppTextScaler(mq.textScaler) : mq.textScaler,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: TipCalculator(
        isDarkMode: _isDarkMode,
        onThemeToggle: _toggleTheme,
        primaryColor: primaryColor,
        darkModeColor: darkModeColor,
        isLargeText: _isLargeText,
        onTextScaleToggle: _toggleTextScale,
      ),
    );
  }
}

class TipCalculator extends StatefulWidget {
  final bool isDarkMode;
  final bool isLargeText;
  final VoidCallback onThemeToggle;
  final VoidCallback onTextScaleToggle;
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
  TipCalculation _calculation = TipCalculation.calculate(billCents: 0);

  final TextEditingController _billController = TextEditingController();
  final FocusNode _billFocusNode = FocusNode();
  late final BillInputFormatter _billInputFormatter;
  String _lastCommittedBillText = '';

  String get _percentageLabel => _calculation.isRounded
      ? _calculation.effectiveTipPercent
      : '${_calculation.selectedTipPercent}';

  @override
  void initState() {
    super.initState();
    _billInputFormatter = BillInputFormatter(onInvalidInput: _showFeedback);
    _billController.addListener(_onBillEditingChanged);
    _billFocusNode.addListener(_onBillFocusChanged);
  }

  @override
  void dispose() {
    _billFocusNode.removeListener(_onBillFocusChanged);
    _billController.dispose();
    _billFocusNode.dispose();
    super.dispose();
  }

  void _commitBillInput() {
    final value = _billController.value;
    if (!value.composing.isCollapsed) {
      // Validate the complete value before ending keyboard composition.
      _billController.value = _billInputFormatter.formatEditUpdate(
        value,
        value.copyWith(composing: TextRange.empty),
      );
    }
  }

  void _dismissKeyboard() {
    _commitBillInput();
    _billFocusNode.unfocus();
  }

  void _onBillFocusChanged() {
    if (!_billFocusNode.hasFocus) _commitBillInput();
    setState(() {});
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Semantics(liveRegion: true, child: Text(message)),
      ));
  }

  void _onBillEditingChanged() {
    if (!_billController.value.composing.isCollapsed) return;
    final text = _billController.text;
    if (text == _lastCommittedBillText) return;
    final input = parseBillInput(text);
    if (!input.isValid) return;
    _lastCommittedBillText = text;
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _calculation = TipCalculation.calculate(
        billCents: input.cents!,
        tipPercent: _calculation.selectedTipPercent,
      );
    });
  }

  bool _hasCommittedBill() {
    if (_billController.value.composing.isCollapsed) return true;
    _showFeedback('Finish entering the bill before rounding.');
    return false;
  }

  void roundUp() {
    if (!_hasCommittedBill() || _calculation.billCents == 0) return;
    setState(() => _calculation = _calculation.roundUp());
    if (_calculation.exceedsSliderRange) {
      _showFeedback(
        'Rounded total: \$${formatCents(_calculation.totalCents)} '
        'with a ${_calculation.effectiveTipPercent}% tip. '
        'Adjust the slider to return to a regular tip.',
      );
    }
  }

  void roundDown() {
    if (!_hasCommittedBill() || _calculation.billCents == 0) return;
    final rounded = _calculation.roundDown();
    if (rounded == null) {
      _showFeedback(
        'Rounding down would reduce the original bill. Total left unchanged.',
      );
      return;
    }
    setState(() => _calculation = rounded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = widget.isDarkMode;
    final panelColor = dark ? widget.darkModeColor : widget.primaryColor;
    final textOnPanel = theme.colorScheme.onSurface;
    final labelStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: textOnPanel,
    );
    final showKeyboardDone = theme.platform == TargetPlatform.iOS &&
        _billFocusNode.hasFocus &&
        MediaQuery.viewInsetsOf(context).bottom > 0;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          // Let the title grow with accessibility text without clipping.
          toolbarHeight: (MediaQuery.textScalerOf(context).scale(26) * 1.2 + 16)
              .clamp(kToolbarHeight, double.infinity),
          title: Text(
            'uTip',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle.copyWith(fontSize: 26),
          ),
          centerTitle: true,
          backgroundColor:
              dark ? theme.scaffoldBackgroundColor : widget.primaryColor,
          foregroundColor: textOnPanel,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle:
              dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          actions: [
            IconButton(
              icon: Icon(
                widget.isLargeText ? Icons.text_decrease : Icons.text_increase,
                color: dark ? widget.primaryColor : textOnPanel,
              ),
              tooltip: widget.isLargeText
                  ? 'Reduce text size'
                  : 'Increase text size',
              onPressed: widget.onTextScaleToggle,
            ),
            IconButton(
              icon: Icon(
                dark ? Icons.wb_sunny : Icons.nightlight_round,
                color: dark ? widget.primaryColor : textOnPanel,
              ),
              tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
              onPressed: widget.onThemeToggle,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: const ValueKey('calculatorScroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _card(
                  key: const ValueKey('billCard'),
                  color: panelColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _billRow(labelStyle),
                      const SizedBox(height: 16),
                      _AmountRow(
                        label: 'Tip:',
                        value: r'$' + formatCents(_calculation.tipCents),
                        valueKey: const ValueKey('tipAmount'),
                        style: labelStyle,
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                          builder: (context, constraints) => Row(
                                key: const ValueKey('percentageHeader'),
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Tip Percentage:',
                                      style: labelStyle,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth / 2),
                                    child: Semantics(
                                      label: _calculation.isRounded
                                          ? 'Effective rounded tip percentage'
                                          : 'Tip percentage',
                                      value: '$_percentageLabel percent',
                                      excludeSemantics: true,
                                      child: Tooltip(
                                        message: _calculation.isRounded
                                            ? 'Effective tip after rounding. Slider selection: '
                                                '${_calculation.selectedTipPercent}%.'
                                            : 'Selected tip percentage',
                                        child: Text(
                                          '$_percentageLabel%',
                                          key: const ValueKey('tipPercentage'),
                                          textAlign: TextAlign.end,
                                          style: labelStyle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Tip percentage slider',
                        value: '${_calculation.selectedTipPercent} percent',
                        increasedValue:
                            '${(_calculation.selectedTipPercent + 1).clamp(0, 30)} percent',
                        decreasedValue:
                            '${(_calculation.selectedTipPercent - 1).clamp(0, 30)} percent',
                        hint:
                            'Swipe up or right to increase. Swipe down or left to decrease. '
                            'Adjusting clears dollar rounding.',
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            showValueIndicator: ShowValueIndicator.onDrag,
                            valueIndicatorColor:
                                dark ? widget.primaryColor : Colors.black,
                            valueIndicatorTextStyle:
                                theme.textTheme.labelMedium!.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: dark
                                  ? theme.colorScheme.onPrimary
                                  : Colors.white,
                            ),
                          ),
                          child: Slider(
                            value: _calculation.selectedTipPercent.toDouble(),
                            semanticFormatterCallback: (value) =>
                                '${value.round()} percent',
                            min: 0,
                            max: 30,
                            divisions: 30,
                            label: '${_calculation.selectedTipPercent}%',
                            onChanged: (newValue) {
                              if (_calculation.billCents > 0) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                setState(() {
                                  _calculation = TipCalculation.calculate(
                                    billCents: _calculation.billCents,
                                    tipPercent: newValue.round(),
                                  );
                                });
                              }
                            },
                            activeColor:
                                dark ? widget.primaryColor : Colors.black,
                            inactiveColor: dark
                                ? widget.primaryColor.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  key: const ValueKey('totalCard'),
                  color: panelColor,
                  child: _AmountRow(
                    label: 'Total:',
                    value: r'$' + formatCents(_calculation.totalCents),
                    valueKey: const ValueKey('totalAmount'),
                    style: labelStyle,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      _roundingButton(
                        key: const ValueKey('roundUp'),
                        label: 'Round up to nearest dollar',
                        semanticsLabel:
                            'Round up to nearest whole dollar total',
                        onPressed: roundUp,
                        background: widget.primaryColor,
                        foreground: theme.colorScheme.onPrimary,
                      ),
                      const SizedBox(height: 8),
                      _roundingButton(
                        key: const ValueKey('roundDown'),
                        label: 'Round down to nearest dollar',
                        semanticsLabel:
                            'Round down to nearest whole dollar total',
                        onPressed: roundDown,
                        background: panelColor,
                        foreground: textOnPanel,
                        subtle: dark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Reserve keyboard space in the footer so Scaffold also positions
        // validation messages above the Done control.
        bottomNavigationBar: showKeyboardDone
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ColoredBox(
                  color: dark ? panelColor : Colors.white,
                  child: Align(
                    heightFactor: 1,
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton(
                        key: const ValueKey('keyboardDone'),
                        onPressed: _dismissKeyboard,
                        style: TextButton.styleFrom(
                          foregroundColor:
                              dark ? widget.primaryColor : Colors.black,
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _billRow(TextStyle style) {
    final field = TextField(
      key: const ValueKey('billInput'),
      // Flutter strips newlines before custom formatters for maxLines: 1.
      // Keep validation of the complete pasted value.
      minLines: 1,
      maxLines: 2,
      controller: _billController,
      focusNode: _billFocusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onEditingComplete: _dismissKeyboard,
      inputFormatters: [_billInputFormatter],
      textAlign: TextAlign.end,
      textAlignVertical: TextAlignVertical.center,
      style: style,
      cursorColor: style.color,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        hintText: 'Enter Bill',
        prefixText:
            _billController.text.trimLeft().startsWith(r'$') ? null : r'$',
        prefixStyle: style,
        hintStyle: style.copyWith(
          fontWeight: FontWeight.normal,
          color: style.color!.withValues(alpha: 0.8),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: style.color!.withValues(alpha: 0.8)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: style.color!, width: 2),
        ),
      ),
    );
    return LayoutBuilder(builder: (context, constraints) {
      final minimumRowWidth = _textWidth(context, 'Bill:', style) +
          16 +
          _textWidth(context, r'$Enter Bill', style);
      final label =
          Text('Bill:', key: const ValueKey('billLabel'), style: style);
      if (minimumRowWidth > constraints.maxWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 8),
            Semantics(label: 'Bill amount', child: field),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          label,
          const SizedBox(width: 16),
          Expanded(child: Semantics(label: 'Bill amount', child: field))
        ],
      );
    });
  }

  Widget _card(
          {required Key key, required Color color, required Widget child}) =>
      Container(
        key: key,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8),
          ],
        ),
        child: child,
      );

  Widget _roundingButton({
    required Key key,
    required String label,
    required String semanticsLabel,
    required VoidCallback onPressed,
    required Color background,
    required Color foreground,
    bool subtle = false,
  }) =>
      Semantics(
        button: true,
        label: semanticsLabel,
        child: ElevatedButton(
          key: key,
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            surfaceTintColor: Colors.transparent,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: subtle ? 0 : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: subtle
                  ? BorderSide(
                      color: widget.primaryColor.withValues(alpha: 0.4))
                  : BorderSide.none,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
}

/// Measure the actual scaled text, so rows adapt to both available width and
/// accessibility settings rather than a device-specific breakpoint.
double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.style,
  });

  final String label;
  final String value;
  final Key valueKey;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(label, style: style);
          final valueWidget = Text(
            value,
            key: valueKey,
            textAlign: TextAlign.end,
            style: style,
          );
          if (_textWidth(context, label, style) +
                  16 +
                  _textWidth(context, value, style) >
              constraints.maxWidth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                labelWidget,
                const SizedBox(height: 8),
                valueWidget,
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [labelWidget, const SizedBox(width: 16), valueWidget],
          );
        },
      );
}
