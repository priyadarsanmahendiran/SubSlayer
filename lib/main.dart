import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';
import './database/database_helper.dart';
import './screens/add_subscription.dart';
import './helpers/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()),
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
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSubscriptionScreen(
          initialText: initialText,
          initialImagePath: initialImagePath,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.black87,
            child: Column(
              children: [
                const Text(
                  "Monthly Burn",
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  "${totalBurn.toStringAsFixed(0)} ${(_subs.isNotEmpty) ? _subs[0]['currency'] : '--'}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
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

                      return Dismissible(
                        key: Key(item['id'].toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) => _deleteSub(item['id']),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey[100],
                            child: Text(item['name'][0].toUpperCase()),
                          ),
                          title: Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("Renews: $dateStr"),
                          trailing: Text(
                            "${item['price']} ${item['currency']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
