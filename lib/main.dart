import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAdFHCUAu2fGiYHV3EEs4REvwDRtCWy6xg",
      authDomain: "vit-chennai-lost-and-found.firebaseapp.com",
      projectId: "vit-chennai-lost-and-found",
      storageBucket: "vit-chennai-lost-and-found.firebasestorage.app",
      messagingSenderId: "826536706665",
      appId: "1:826536706665:web:08ec73c2b929ed4337d8f8",
      measurementId: "G-YKY8X57DXD",
      databaseURL: "https://vit-chennai-lost-and-found-default-rtdb.asia-southeast1.firebasedatabase.app",
    ),
  );
  runApp(const LostFoundApp());
}

class LostFoundApp extends StatelessWidget {
  const LostFoundApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VIT Lost & Found',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: const AuthWrapper(),
      );
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) =>
            snapshot.hasData ? const MainScreen() : const LoginScreen(),
      );
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _signIn(BuildContext context) async {
    try {
      final gUser = await GoogleSignIn().signIn();
      if (gUser == null) return;
      final gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Card(
            elevation: 12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded, size: 90, color: Colors.blue),
                  const SizedBox(height: 20),
                  const Text("VIT Lost & Found",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => _signIn(context),
                    icon: const Icon(Icons.login_rounded, size: 32),
                    label: const Text("Sign in with Google", style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;
  final user = FirebaseAuth.instance.currentUser!;
  final db = FirebaseDatabase.instance.ref("items");
  final searchController = TextEditingController();

  static const List<Map<String, dynamic>> tabs = [
    {"icon": Icons.all_inclusive_rounded, "label": "All Items", "type": null},
    {"icon": Icons.search_off_rounded, "label": "Lost", "type": "Lost"},
    {"icon": Icons.check_circle_rounded, "label": "Found", "type": "Found"},
    {"icon": Icons.person_rounded, "label": "My Posts", "type": "mine"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VIT Lost & Found", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Logout",
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user.displayName ?? "User"),
              accountEmail: Text(user.email ?? ""),
              currentAccountPicture: CircleAvatar(backgroundImage: NetworkImage(user.photoURL ?? "")),
              decoration: const BoxDecoration(color: Colors.blue),
            ),
            ...tabs.asMap().entries.map((e) => ListTile(
                  leading: Icon(e.value["icon"]),
                  title: Text(e.value["label"]),
                  selected: selectedIndex == e.key,
                  selectedTileColor: Colors.blue.withOpacity(0.2),
                  onTap: () {
                    setState(() => selectedIndex = e.key);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue,
        onPressed: _showPostDialog,
        label: const Text("Post Item"),
        icon: const Icon(Icons.post_add_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search titles or description...",
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                filled: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: db.orderByChild("timestamp").onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text("No items yet"));
                }

                final Map items = snapshot.data!.snapshot.value as Map;
                var list = items.entries.map((e) => {...e.value, "key": e.key}).toList()
                  ..sort((a, b) => (b["timestamp"] ?? 0).compareTo(a["timestamp"] ?? 0));

                final search = searchController.text.toLowerCase();
                final currentTab = tabs[selectedIndex]["type"];

                list = list.where((item) {
                  final matchesSearch = search.isEmpty ||
                      (item["title"]?.toString().toLowerCase().contains(search) ?? false) ||
                      (item["description"]?.toString().toLowerCase().contains(search) ?? false);
                  if (currentTab == "mine") return item["userId"] == user.uid;
                  if (currentTab != null) return item["category"] == currentTab;
                  return matchesSearch;
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final item = list[i];
                    final isLost = item["category"] == "Lost";

                    return Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLost ? Colors.red.shade100 : Colors.green.shade100,
                          child: Icon(isLost ? Icons.search_off_rounded : Icons.check_circle_rounded,
                              color: isLost ? Colors.red : Colors.green),
                        ),
                        title: Text(item["title"] ?? "No title",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item["description"] ?? ""),
                            if (item["location"] != null && item["location"].toString().isNotEmpty)
                              Text("📍 ${item["location"]}", style: const TextStyle(fontStyle: FontStyle.italic)),
                            const SizedBox(height: 6),
                            Text(
                              "— ${item["userName"] ?? "Anonymous"} • ${DateFormat('dd MMM • HH:mm').format(DateTime.fromMillisecondsSinceEpoch(item["timestamp"] ?? 0))}",
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPostDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String category = "Lost";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("New Post"),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                maxLines: 4),
            const SizedBox(height: 12),
            TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(
                  labelText: "Location",
                  hintText: "e.g., TT Block, Canteen, Library",
                  border: OutlineInputBorder(),
                )),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
              items: ["Lost", "Found"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => category = v!,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                db.push().set({
                  "title": titleCtrl.text.trim(),
                  "description": descCtrl.text.trim(),
                  "location": locationCtrl.text.trim(),
                  "category": category,
                  "userId": user.uid,
                  "userName": user.displayName,
                  "timestamp": ServerValue.timestamp,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text("Posted successfully!")));
              }
            },
            child: const Text("Post", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}