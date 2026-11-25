/// Centralized US English UI strings for ClearDeck Solitaire (ready for i18n).
class AppStrings {
  const AppStrings._();

  static const String appTitle = 'ClearDeck Solitaire';
  static const String betaBadge = 'ClearDeck Solitaire 1.0';

  // Top bar
  static const String movesLabel = 'Moves';
  static const String dailyLabel = 'Daily';
  static const String statsLabel = 'Stats';

  // Bottom bar (4 fixed labeled buttons)
  static const String undoLabel = 'Undo';
  static const String hintLabel = 'Hint';
  static const String newDealLabel = 'New';
  static const String settingsLabel = 'Settings';

  // Gameplay prompts
  static const String autoCompleteLabel = 'Auto-Complete';
  static const String deadEndTitle = 'No Constructive Moves';
  static const String deadEndBody =
      'This hand has reached a dead end. Rewind to your last solvable move or start fresh.';
  static const String smartRewindButton = 'Rewind to Last Solvable Move';
  static const String replayDealButton = 'Replay Same Deal';
  static const String newDealButton = 'Start New Deal';
  static const String dismissButton = 'Keep Looking';

  // Tutorial offer & guidance
  static const String tutorialOfferTitle = 'Would You Like a Quick Guide?';
  static const String tutorialOfferBody =
      'We noticed a few cards wouldn’t place cleanly. Would you like a short hands-on walkthrough of Klondike rules?';
  static const String startTutorialButton = 'Start Guided Tutorial';
  static const String declineTutorialButton = 'No Thanks';
  static const String howToPlayLabel = 'How to Play';

  // Win dialog
  static const String winTitle = 'Hand Complete';
  static const String winSubtitle = 'Well played';
  static const String playNextDealButton = 'Play Next Deal';

  // Settings
  static const String settingsTitle = 'Settings';
  static const String gameplaySection = 'Gameplay';
  static const String appearanceSection = 'Visual comfort';
  static const String audioSection = 'Sound';
  static const String progressSection = 'Progress';
  static const String drawModeLabel = 'Draw Mode';
  static const String dealModeLabel = 'Deal Mode';
  static const String showTimerLabel = 'Show Timer';
  static const String showTimerHint = 'Starts on your first valid move';
  static const String fourColorLabel = '4-Color Deck';
  static const String fourColorHint = 'Blue diamonds and green clubs';
  static const String cardSizeLabel = 'Card Size';
  static const String leftHandedLabel = 'Left-Handed Layout';
  static const String leftHandedHint = 'Places draw deck on the right side';
  static const String tableThemeLabel = 'Table theme';
  static const String cardFaceStyleLabel = 'Card face style';
  static const String cardBackStyleLabel = 'Card back';
  static const String sfxVolumeLabel = 'Card Sounds';
  static const String bgmVolumeLabel = 'Background Music';
  static const String applyRuleChangeNote = 'New rules apply on the next deal';

  // Daily, Stats & Quests
  static const String dailyTitle = 'Daily Challenge';
  static const String dailySubtitle =
      'One solvable deal for every date, offline';
  static const String statsTitle = 'Statistics';
  static const String questsLabel = 'Quests';
  static const String resetStatsButton = 'Reset Statistics';
}
