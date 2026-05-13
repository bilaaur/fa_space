import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import Screen & Service
import 'firebase_options.dart';
import 'services/background_service.dart';
import 'ui/screens/add_plan_screen.dart'; 
import 'ui/screens/conflict_screen.dart';
import 'ui/screens/period_tracker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (!kIsWeb) {
    await initializeService(); 
  }
  
  runApp(const FASpaceApp());
}

class FASpaceApp extends StatelessWidget {
  const FASpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FA Space',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF48FB1),
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  
  // --- LOGIC MOOD STREAK ---
  Future<int> getMoodStreak() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('moods')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get();

    int streak = 0;
    DateTime? lastDate;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('label') || data['timestamp'] == null) continue;
      
      String mood = data['label'] ?? '';
      DateTime currentDate = (data['timestamp'] as Timestamp).toDate();
      DateTime normalizedCurrent = DateTime(currentDate.year, currentDate.month, currentDate.day);

      if (mood.toLowerCase() == 'happy') {
        if (lastDate == null) {
          streak = 1;
          lastDate = normalizedCurrent;
        } else {
          int diff = lastDate.difference(normalizedCurrent).inDays;
          if (diff == 1) {
            streak++;
            lastDate = normalizedCurrent;
          } else if (diff == 0) {
            continue; 
          } else {
            break; 
          }
        }
      } else {
        if (streak > 0) break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FA Space', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddPlanScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('status').doc('farid').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final statusData = snapshot.data!.data() as Map<String, dynamic>?;

          var lastSeenRaw = statusData?['lastSeen'];
          DateTime lastSeen = (lastSeenRaw != null && lastSeenRaw is Timestamp) 
              ? lastSeenRaw.toDate() 
              : DateTime.now();

          int battery = statusData?['battery'] ?? 0;
          bool isCharging = statusData?['isCharging'] ?? false;

          double? lat = (statusData != null && statusData.containsKey('lat')) 
              ? statusData['lat']?.toDouble() : null;
          double? lng = (statusData != null && statusData.containsKey('lng')) 
              ? statusData['lng']?.toDouble() : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- SECTION 1: ANNIVERSARY & STREAK ---
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text("Days Since We Started ❤️", style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 5),
                      Text(
                        "${DateTime.now().difference(DateTime(2026, 3, 26)).inDays} Days", 
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      
                      // WIDGET MOOD STREAK
                      FutureBuilder<int>(
                        future: getMoodStreak(),
                        builder: (context, streakSnapshot) {
                          if (streakSnapshot.hasData && streakSnapshot.data! > 0) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text("🔥", style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${streakSnapshot.data} Days Happy Streak!",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- SECTION 2: STATUS DEVICE ---
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Farid's Phone", style: TextStyle(fontSize: 14, color: Colors.grey)),
                              const SizedBox(height: 5),
                              Text(
                                isCharging ? "⚡ Charging..." : "🔋 On Battery",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: battery / 100,
                                color: battery < 20 ? Colors.red : Colors.green,
                                strokeWidth: 6,
                              ),
                              Text("$battery%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                      const Divider(height: 30),
                      Row(
                        children: [
                          const Icon(Icons.history, size: 20, color: Colors.blue),
                          const SizedBox(width: 10),
                          Text("Last Seen: ${DateFormat('HH:mm').format(lastSeen)} WIB"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- SECTION 3: ZENLY STYLE MAPS (OSM) ---
              const Text("Where is Farid?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                height: 300,
                clipBehavior: Clip.antiAlias, 
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: (lat != null && lng != null)
                    ? FlutterMap(
                        options: MapOptions(
                          initialCenter: ll.LatLng(lat, lng), 
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.farid.fa_space',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: ll.LatLng(lat, lng),
                                width: 80,
                                height: 80,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.redAccent,
                                  size: 45,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Center(child: Text("Waiting for location...")),
                      ),
              ),
              const SizedBox(height: 24),

              // --- SECTION 4: MOOD TRACKER ---
              const Text("How's Our Vibe Today?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _moodButton(context, "😊", "Happy"),
                  _moodButton(context, "🥺", "Miss You"),
                  _moodButton(context, "😡", "Mad"),
                  _moodButton(context, "😴", "Flat"),
                ],
              ),
              const SizedBox(height: 24),

              // --- SECTION 5: PERIOD TRACKER ---
              Card(
                color: Colors.redAccent.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.redAccent),
                  title: const Text("Aura's Flo Calendar", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Tap to see cycle prediction"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const PeriodTrackerScreen())
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),


              // --- SECTION: MONTHLY PLANS (COMING SOON) ---
const Text("Coming Soon Plans 📅", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
const SizedBox(height: 10),
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('plans')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
      .orderBy('date', descending: false)
      .limit(3)
      .snapshots(),
  builder: (context, planSnapshot) {
    if (!planSnapshot.hasData) return const LinearProgressIndicator();
    
    var plans = planSnapshot.data!.docs;
    if (plans.isEmpty) return const Text("No upcoming plans yet.", style: TextStyle(color: Colors.grey));

    return Column(
      children: plans.map((doc) {
        DateTime date = (doc['date'] as Timestamp).toDate();
        return Card(
          child: ListTile(
            leading: const Icon(Icons.event, color: Colors.pinkAccent),
            title: Text(doc['title']),
            subtitle: Text(DateFormat('EEEE, dd MMMM').format(date)),
            trailing: IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () => doc.reference.delete(), // Hapus kalau sudah selesai
            ),
          ),
        );
      }).toList(),
    );
  },
),
const SizedBox(height: 24),

              // --- SECTION 6: CONFLICT RESOLUTION ---
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (context) => const ConflictScreen())
                ),
                icon: const Icon(Icons.psychology),
                label: const Text("Conflict Resolution (AI)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _moodButton(BuildContext context, String emoji, String label) {
    return InkWell(
      onTap: () {
        FirebaseFirestore.instance.collection('moods').add({
          'emoji': emoji,
          'label': label,
          'timestamp': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Mood $label sent!")));
        setState(() {}); // Refresh untuk update streak 🔥
      },
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}