import 'package:material_ui/material_ui.dart';

import 'deck_palette.dart';

/// Visual palette, motion curve, and Material ThemeData builder for ClearDeck
/// Solitaire's sunlit American parlor card table aesthetic.
class ClearDeckTheme {
  const ClearDeckTheme({
    required this.id,
    required this.tableBackground,
    required this.tableCenterGlow,
    required this.tableEdgeVignette,
    required this.tableGrainColor,
    required this.barSurface,
    required this.dockBackground,
    required this.goldTrim,
    required this.chromeHairline,
    required this.chromeButtonSurface,
    required this.slotBorder,
    required this.slotFill,
    required this.cardFace,
    required this.cardFaceTop,
    required this.cardFaceBottom,
    required this.cardBorder,
    required this.cardBack,
    required this.cardBackAccent,
    required this.textOnTable,
    required this.mutedOnTable,
    required this.sheetSurface,
    required this.sheetCard,
    required this.sheetRaised,
    required this.sheetBorder,
    required this.sheetText,
    required this.sheetSecondary,
    required this.sheetMuted,
    required this.sheetAccent,
    required this.sheetAccentText,
    required this.stampFill,
    required this.stampText,
    required this.accent,
    required this.hintHighlight,
    required this.isDarkTable,
  });

  // Unified motion tokens
  static const Curve motionCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve flipCurve = Curves.easeInOutCubic;
  static const Duration feedbackDuration = Duration(milliseconds: 160);
  static const Duration flightDuration = Duration(milliseconds: 210);
  static const Duration autoFlightDuration = Duration(milliseconds: 95);
  static const Duration flipDuration = Duration(milliseconds: 260);
  static const Duration settleDuration = Duration(milliseconds: 280);

  final TableThemeId id;
  final Color tableBackground;
  final Color tableCenterGlow;
  final Color tableEdgeVignette;
  final Color tableGrainColor;
  final Color barSurface;
  final Color dockBackground;
  final Color goldTrim;
  final Color chromeHairline;
  final Color chromeButtonSurface;
  final Color slotBorder;
  final Color slotFill;
  final Color cardFace;
  final Color cardFaceTop;
  final Color cardFaceBottom;
  final Color cardBorder;
  final Color cardBack;
  final Color cardBackAccent;
  final Color textOnTable;
  final Color mutedOnTable;
  final Color sheetSurface;
  final Color sheetCard;
  final Color sheetRaised;
  final Color sheetBorder;
  final Color sheetText;
  final Color sheetSecondary;
  final Color sheetMuted;
  final Color sheetAccent;
  final Color sheetAccentText;
  final Color stampFill;
  final Color stampText;
  final Color accent;
  final Color hintHighlight;
  final bool isDarkTable;

  static const ClearDeckTheme heritageGreen = ClearDeckTheme(
    id: TableThemeId.heritageGreen,
    tableBackground: Color(0xFF1A4D3B),
    tableCenterGlow: Color(0xFF235D48),
    tableEdgeVignette: Color(0xFF113528),
    tableGrainColor: Color(0x00000000),
    barSurface: Color(0xFF12382A),
    dockBackground: Color(0xEE103125),
    goldTrim: Color(0xFFD0AA54),
    chromeHairline: Color(0x1CF8F4EA),
    chromeButtonSurface: Color(0x14F8F4EA),
    slotBorder: Color(0x3CF8F4EA),
    slotFill: Color(0x380B251C),
    cardFace: Color(0xFFFAF6EC),
    cardFaceTop: Color(0xFFFFFDF8),
    cardFaceBottom: Color(0xFFF3EEE1),
    cardBorder: Color(0xFFD4CBB8),
    cardBack: Color(0xFF8F1D22),
    cardBackAccent: Color(0xFFD0AA54),
    textOnTable: Color(0xFFF8F4EA),
    mutedOnTable: Color(0xFFD2E0D8),
    sheetSurface: Color(0xFFF6F2E9),
    sheetCard: Color(0xFFFDFBF6),
    sheetRaised: Color(0xFFECE6DA),
    sheetBorder: Color(0x1A1E1A15),
    sheetText: Color(0xFF1E1A15),
    sheetSecondary: Color(0xFF575046),
    sheetMuted: Color(0xFF6E655A),
    sheetAccent: Color(0xFF1D4B3A),
    sheetAccentText: Color(0xFFFAF6EE),
    stampFill: Color(0xFF1D4B3A),
    stampText: Color(0xFFFAF6EE),
    accent: Color(0xFFD0AA54),
    hintHighlight: Color(0xFFE8A838),
    isDarkTable: true,
  );

  static const ClearDeckTheme warmParlor = ClearDeckTheme(
    id: TableThemeId.warmParlor,
    tableBackground: Color(0xFFE7DEC9),
    tableCenterGlow: Color(0xFFF1E9D7),
    tableEdgeVignette: Color(0xFFDBD0B6),
    tableGrainColor: Color(0x00000000),
    barSurface: Color(0xFFDCD0B6),
    dockBackground: Color(0xF0D5C8AC),
    goldTrim: Color(0xFF966E36),
    chromeHairline: Color(0x1F1E1A15),
    chromeButtonSurface: Color(0x121E1A15),
    slotBorder: Color(0x471E1A15),
    slotFill: Color(0x2EC5B79C),
    cardFace: Color(0xFFFCF9F2),
    cardFaceTop: Color(0xFFFFFFFF),
    cardFaceBottom: Color(0xFFF8F4EA),
    cardBorder: Color(0xFFC4B9A2),
    cardBack: Color(0xFF26483B),
    cardBackAccent: Color(0xFF966E36),
    textOnTable: Color(0xFF1E1A15),
    mutedOnTable: Color(0xFF544D43),
    sheetSurface: Color(0xFFF6F2E9),
    sheetCard: Color(0xFFFDFBF6),
    sheetRaised: Color(0xFFECE6DA),
    sheetBorder: Color(0x1A1E1A15),
    sheetText: Color(0xFF1E1A15),
    sheetSecondary: Color(0xFF575046),
    sheetMuted: Color(0xFF6E655A),
    sheetAccent: Color(0xFF7D5A24),
    sheetAccentText: Color(0xFFFCF9F2),
    stampFill: Color(0xFF7D5A24),
    stampText: Color(0xFFFCF9F2),
    accent: Color(0xFF966E36),
    hintHighlight: Color(0xFFB4690E),
    isDarkTable: false,
  );

  static const ClearDeckTheme coastalSlate = ClearDeckTheme(
    id: TableThemeId.coastalSlate,
    tableBackground: Color(0xFF1E3A56),
    tableCenterGlow: Color(0xFF294B6D),
    tableEdgeVignette: Color(0xFF14283D),
    tableGrainColor: Color(0x00000000),
    barSurface: Color(0xFF142A40),
    dockBackground: Color(0xEE112438),
    goldTrim: Color(0xFFD0B26C),
    chromeHairline: Color(0x1CF6F4EE),
    chromeButtonSurface: Color(0x14F6F4EE),
    slotBorder: Color(0x3CF6F4EE),
    slotFill: Color(0x380B1B2B),
    cardFace: Color(0xFFF7F5EE),
    cardFaceTop: Color(0xFFFCFBF7),
    cardFaceBottom: Color(0xFFF1EDE3),
    cardBorder: Color(0xFFD0C9BA),
    cardBack: Color(0xFF1B3B6F),
    cardBackAccent: Color(0xFFD0B26C),
    textOnTable: Color(0xFFF6F4EE),
    mutedOnTable: Color(0xFFCBD7E3),
    sheetSurface: Color(0xFFF5F6F7),
    sheetCard: Color(0xFFFCFDFE),
    sheetRaised: Color(0xFFE8ECF0),
    sheetBorder: Color(0x18161E29),
    sheetText: Color(0xFF161E29),
    sheetSecondary: Color(0xFF4C5766),
    sheetMuted: Color(0xFF636F80),
    sheetAccent: Color(0xFF1D3E63),
    sheetAccentText: Color(0xFFFAFBFD),
    stampFill: Color(0xFF1D3E63),
    stampText: Color(0xFFFAFBFD),
    accent: Color(0xFFD0B26C),
    hintHighlight: Color(0xFFE8A838),
    isDarkTable: true,
  );

  static const ClearDeckTheme midnightMahogany = ClearDeckTheme(
    id: TableThemeId.midnightMahogany,
    tableBackground: Color(0xFF181310),
    tableCenterGlow: Color(0xFF211A16),
    tableEdgeVignette: Color(0xFF100C09),
    tableGrainColor: Color(0x00000000),
    barSurface: Color(0xFF130F0C),
    dockBackground: Color(0xF014100D),
    goldTrim: Color(0xFFC89B54),
    chromeHairline: Color(0x1AEFE9DE),
    chromeButtonSurface: Color(0x14EFE9DE),
    slotBorder: Color(0x38EFE9DE),
    slotFill: Color(0x450E0B08),
    cardFace: Color(0xFFE7DDCC),
    cardFaceTop: Color(0xFFEDE4D4),
    cardFaceBottom: Color(0xFFE0D5C2),
    cardBorder: Color(0xFFBBAFA0),
    cardBack: Color(0xFF4E2A23),
    cardBackAccent: Color(0xFFC89B54),
    textOnTable: Color(0xFFEFE9DE),
    mutedOnTable: Color(0xFFBDB3A4),
    sheetSurface: Color(0xFF161412),
    sheetCard: Color(0xFF1E1B18),
    sheetRaised: Color(0xFF282420),
    sheetBorder: Color(0x1AEFE9DE),
    sheetText: Color(0xFFEFE9DE),
    sheetSecondary: Color(0xFFB3AAA0),
    sheetMuted: Color(0xFF948B80),
    sheetAccent: Color(0xFFEFE9DE),
    sheetAccentText: Color(0xFF181411),
    stampFill: Color(0xFF2E261E),
    stampText: Color(0xFFEFE9DE),
    accent: Color(0xFFC89B54),
    hintHighlight: Color(0xFFE8A838),
    isDarkTable: true,
  );

  static ClearDeckTheme fromId(TableThemeId id) {
    switch (id) {
      case TableThemeId.heritageGreen:
        return heritageGreen;
      case TableThemeId.warmParlor:
        return warmParlor;
      case TableThemeId.coastalSlate:
        return coastalSlate;
      case TableThemeId.midnightMahogany:
        return midnightMahogany;
    }
  }

  ThemeData toMaterialTheme() {
    final sheetIsDark = id == TableThemeId.midnightMahogany;
    final brightness = sheetIsDark ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: sheetAccent,
      brightness: brightness,
      primary: sheetAccent,
      onPrimary: sheetAccentText,
      surface: sheetSurface,
      onSurface: sheetText,
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tableBackground,
      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: sheetText,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: sheetText,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: sheetText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: sheetSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: sheetText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: sheetAccent,
          foregroundColor: sheetAccentText,
          shape: controlShape,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: sheetCard,
          foregroundColor: sheetText,
          side: BorderSide(color: sheetBorder, width: 1.0),
          shape: controlShape,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: sheetSecondary,
          shape: controlShape,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return sheetAccentText;
          }
          return sheetMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return sheetAccent;
          }
          return sheetRaised;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return sheetBorder;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: sheetAccent,
        inactiveTrackColor: sheetRaised,
        thumbColor: sheetAccent,
        overlayColor: sheetAccent.withValues(alpha: 0.12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sheetCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: sheetBorder, width: 1.0),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: sheetText,
        ),
        contentTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.45,
          color: sheetSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
