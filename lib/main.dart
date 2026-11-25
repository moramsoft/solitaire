import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/analytics_service.dart';
import 'services/audio_service.dart';
import 'services/monetization_service.dart';
import 'services/persistence_service.dart';
import 'state/game_controller.dart';
import 'state/quest_controller.dart';
import 'state/settings_controller.dart';
import 'state/stats_controller.dart';
import 'theme/app_theme.dart';
import 'ui/game_screen.dart';
import 'ui/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final persistence = SharedPrefsPersistenceService(prefs);
  final audio = AssetAudioService();
  final analytics = DebugAnalyticsService();
  const monetization = BetaFreeMonetizationService();

  final settingsController = SettingsController(
    persistence: persistence,
    audio: audio,
  );
  final statsController = StatsController(persistence: persistence);
  final questController = QuestController(persistence: persistence);
  final gameController = GameController(
    persistence: persistence,
    settings: settingsController,
    stats: statsController,
    audio: audio,
    analytics: analytics,
    monetization: monetization,
    quests: questController,
  );

  await settingsController.initialize();
  await statsController.initialize();
  await questController.initialize();
  await gameController.initialize();

  runApp(
    ClearDeckApp(
      gameController: gameController,
      settingsController: settingsController,
      statsController: statsController,
      questController: questController,
    ),
  );
}

/// Root widget for ClearDeck Solitaire handling theme updates and lifecycle
/// persistence/audio cleanup.
class ClearDeckApp extends StatefulWidget {
  const ClearDeckApp({
    super.key,
    required this.gameController,
    required this.settingsController,
    required this.statsController,
    this.questController,
  });

  final GameController gameController;
  final SettingsController settingsController;
  final StatsController statsController;
  final QuestController? questController;

  @override
  State<ClearDeckApp> createState() => _ClearDeckAppState();
}

class _ClearDeckAppState extends State<ClearDeckApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.gameController.handleLifecycleChange(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, _) {
        final clearDeckTheme = ClearDeckTheme.fromId(
          widget.settingsController.settings.tableTheme,
        );
        return MaterialApp(
          title: AppStrings.appTitle,
          debugShowCheckedModeBanner: false,
          theme: clearDeckTheme.toMaterialTheme(),
          home: GameScreen(
            gameController: widget.gameController,
            settingsController: widget.settingsController,
            statsController: widget.statsController,
            questController: widget.questController,
          ),
        );
      },
    );
  }
}
