import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';
import './database/database_helper.dart';
import './screens/add_subscription.dart';
import './helpers/notification_service.dart';
import './models/subscription_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.blueGrey[300],
        colorScheme: ColorScheme.dark(
          primary: Colors.blueGrey[300]!,
          secondary: Colors.blueGrey[300]!,
          surface: const Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.blueGrey[300],
          foregroundColor: const Color(0xFF121212),
          elevation: 4,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blueGrey[300]!, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.white54),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[300],
            foregroundColor: const Color(0xFF121212),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _subs = [];
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _refreshSubs();
    NotificationService().requestPermissions();
    _initShareHandler();
    _processAutoRenewals();
  }

  // --- 0. Process Auto Renewals ---
  Future<void> _processAutoRenewals() async {
    final data = await dbHelper.getSubscriptions();
    DateTime now = DateTime.now();

    for (var subMap in data) {
      final sub = Subscription.fromMap(subMap);

      // The day the reminder was supposed to fire
      DateTime reminderDate = sub.renewalDate.subtract(const Duration(days: 3));
      // The day after the reminder, which means they didn't delete it
      DateTime checkDate = reminderDate.add(const Duration(days: 1));

      if (now.isAfter(checkDate)) {
        // Did not cancel! Auto-renew for another 30 days.
        DateTime newRenewalDate = sub.renewalDate.add(const Duration(days: 30));

        // Update database
        Subscription updatedSub = Subscription(
          id: sub.id,
          name: sub.name,
          price: sub.price,
          currency: sub.currency,
          renewalDate: newRenewalDate,
        );
        await dbHelper.updateSubscription(sub.id!, updatedSub.toMap());

        // Notify user immediately that it renewed
        await NotificationService().showImmediateNotification(
          id:
              sub.id! +
              10000, // Use offset ID for alert so it doesn't cancel scheduled one
          title: '🔄 Auto-Renewed!',
          body: '${sub.name} wasn\'t cancelled. Renewal pushed 30 days.',
        );

        // Schedule next reminder for the new date
        DateTime newReminderDate = newRenewalDate.subtract(
          const Duration(days: 3),
        );
        await NotificationService().scheduleNotification(
          id: sub.id!,
          title: '🔪 Kill ${sub.name}?',
          body:
              '${sub.name} renews in 3 days for ${sub.price} ${sub.currency}.',
          scheduledDate: newReminderDate,
        );
      }
    }

    // Refresh the UI after processing
    _refreshSubs();
  }

  // --- 1. Load Data from SQLite ---
  void _refreshSubs() async {
    final data = await dbHelper.getSubscriptions();
    setState(() {
      _subs = data;
    });
  }

  // --- 2. Handle Incoming Shares ---
  Future<void> _initShareHandler() async {
    final handler = ShareHandlerPlatform.instance;

    // Case A: App was CLOSED and opened via Share (Initial Intent)
    final initialMedia = await handler.getInitialSharedMedia();
    if (initialMedia != null) {
      _processMedia(initialMedia);
    }

    // --- CASE 2: Warm Start (App was in background) ---
    _streamSubscription = handler.sharedMediaStream.listen((SharedMedia media) {
      _processMedia(media);
    });
  }

  void _processMedia(SharedMedia media) {
    if (media.content != null && media.content!.isNotEmpty) {
      _navigateToAddScreen(initialText: media.content);
    } else if (media.attachments != null && media.attachments!.isNotEmpty) {
      // It's an Image! (or file)
      final first = media.attachments!.first;
      if (first != null) {
        _navigateToAddScreen(initialImagePath: first.path);
      }
    }
  }

  // --- 3. Navigation Logic ---
  void _navigateToAddScreen({
    String? initialText,
    String? initialImagePath,
    Subscription? existingSubscription,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSubscriptionScreen(
          initialText: initialText,
          initialImagePath: initialImagePath,
          existingSubscription: existingSubscription,
        ),
      ),
    );
    if (result == true) _refreshSubs();
  }

  // --- 4. Delete Logic (Swipe to Kill) ---
  void _deleteSub(int id) async {
    final db = await dbHelper.database;
    await db.delete('subscriptions', where: 'id = ?', whereArgs: [id]);
    _refreshSubs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription deleted 🗑️')),
        );
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total burn
    double totalBurn = _subs.fold(
      0,
      (sum, item) => sum + (item['price'] as num),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('SubSlayer ⚔️'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      // Simple Dashboard Card
      body: Column(
        children: [
          // Modern Gradient Dashboard Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "Monthly Burn",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${totalBurn.toStringAsFixed(0)} ${(_subs.isNotEmpty) ? _subs[0]['currency'] : ''}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900, // Black
                  ),
                ),
              ],
            ),
          ),

          // The List
          Expanded(
            child: _subs.isEmpty
                ? const Center(child: Text("No subs yet. You are free! 🕊️"))
                : ListView.builder(
                    itemCount: _subs.length,
                    itemBuilder: (context, index) {
                      final item = _subs[index];
                      // Parse date string back to DateTime object
                      final date = DateTime.parse(item['renewalDate']);
                      final dateStr = "${date.year}-${date.month}-${date.day}";

                      return Card(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Dismissible(
                            key: Key(item['id'].toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                              ),
                              child: const Icon(
                                Icons.delete_sweep,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            onDismissed: (direction) => _deleteSub(item['id']),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                onTap: () {
                                  _navigateToAddScreen(
                                    existingSubscription: Subscription.fromMap(
                                      item,
                                    ),
                                  );
                                },
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.2),
                                  child: Text(
                                    item['name'][0].toUpperCase(),
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                subtitle: Text(
                                  "Renews: $dateStr",
                                  style: const TextStyle(color: Colors.white60),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${item['price']}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    Text(
                                      item['currency'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // Floating Action Button (Manual Add)
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddScreen(),
        backgroundColor: Colors.black87,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
