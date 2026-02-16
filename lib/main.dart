import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple ToDo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

/// ===== Model =====
class Todo {
  final String id;
  final String title;
  bool done;

  Todo({required this.id, required this.title, this.done = false});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      done: (json['done'] ?? false) as bool,
    );
  }
}

/// ===== HomeShell: state + tabs =====
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Tabs
  int _index = 0;

  // Data
  final List<Todo> _tasks = [];
  final Set<int> _revealedPanels = {};
  String? _backgroundImagePath;
  final List<String> _clearedImages = [];

  // UI
  final TextEditingController _controller = TextEditingController();

  // Keys
  static const String _tasksKey = 'tasks_key';
  static const String _bgKey = 'bg_path';
  static const String _panelsKey = 'revealed_panels';
  static const String _galleryKey = 'cleared_gallery';

  // Panel grid
  static const int rows = 6;
  static const int cols = 10;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadTasks();
    await _loadPanels();
    await _loadBackground();
    await _loadGallery();
  }

  // ===== Tasks =====
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_tasksKey);
    if (saved == null) return;

    setState(() {
      _tasks
        ..clear()
        ..addAll(
          saved.map(
            (s) => Todo.fromJson(jsonDecode(s) as Map<String, dynamic>),
          ),
        );
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _tasks.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_tasksKey, data);
  }

  Future<void> _addTask() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _tasks.add(
        Todo(id: DateTime.now().millisecondsSinceEpoch.toString(), title: text),
      );
      _controller.clear();
    });

    await _saveTasks();
  }

  Future<void> _deleteTask(int index) async {
    setState(() {
      _tasks.removeAt(index);
    });
    await _saveTasks();
  }

  Future<void> _toggleTask(int index, bool value) async {
    setState(() {
      _tasks[index].done = value;
    });

    await _saveTasks();

    final completed = _tasks.where((t) => t.done).length;
    final totalPanels = rows * cols;

    if (completed >= totalPanels) {
      _onAllPanelsCleared();
    }
  }

  // ===== Background =====
  Future<void> _pickBackground() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return;

    final path = result.files.single.path;
    if (path == null) return;

    setState(() {
      _backgroundImagePath = path;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bgKey, path);
  }

  Future<void> _loadBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_bgKey);
    if (path == null || path.isEmpty) return;

    // ファイルが消えている可能性に備える
    if (!File(path).existsSync()) return;

    setState(() {
      _backgroundImagePath = path;
    });
  }

  // ===== Panels =====
  /*void _revealPanel() {
    final total = rows * cols;

    final hidden = List.generate(
      total,
      (i) => i,
    ).where((i) => !_revealedPanels.contains(i)).toList();

    if (hidden.isEmpty) return;

    hidden.shuffle();
    final selected = hidden.first;

    setState(() {
      _revealedPanels.add(selected);
    });

    _savePanels();

    // ✅ 全開になったらクリア処理
    if (_revealedPanels.length == total) {
      _onAllPanelsCleared();
    }
  }*/

  Future<void> _savePanels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _panelsKey,
      _revealedPanels.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _loadPanels() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_panelsKey);
    if (saved == null) return;

    setState(() {
      _revealedPanels
        ..clear()
        ..addAll(saved.map(int.parse));
    });
  }

  // ===== Gallery =====
  Future<void> _loadGallery() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_galleryKey);
    if (saved == null) return;

    setState(() {
      _clearedImages
        ..clear()
        ..addAll(saved.where((p) => File(p).existsSync()));
    });
  }

  Future<void> _saveGallery() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_galleryKey, _clearedImages);
  }

  // ✅ 全パネルが開いたときの処理
  Future<void> _onAllPanelsCleared() async {
    // いまの背景画像をギャラリーに保存
    final bg = _backgroundImagePath;
    if (bg != null && bg.isNotEmpty && File(bg).existsSync()) {
      if (!_clearedImages.contains(bg)) {
        setState(() {
          _clearedImages.add(bg);
        });
        await _saveGallery();
      }
    }

    if (!mounted) return;

    // クリア通知 + 次の画像選択へ
    final chooseNext = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('クリア！'),
          content: const Text('すべてのパネルが開きました。\n次の背景画像を選びますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('あとで'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('選ぶ'),
            ),
          ],
        );
      },
    );

    if (chooseNext != true) {
      // あとで選ぶ：Progressのまま（全開状態）
      // ギャラリーは保存済みなのでOK
      return;
    }

    // 次の背景画像を選択
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    if (picked == null || picked.files.single.path == null) return;

    final newPath = picked.files.single.path!;

    setState(() {
      _backgroundImagePath = newPath;
      _revealedPanels.clear(); // ✅ 次ステージ：パネルをリセット
      _index = 1; // Progressタブへ
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bgKey, newPath);
    await _savePanels(); // 空を保存
  }

  // ===== Dev reset (あなたが入れている場合に合わせて維持) =====
  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() {
      _tasks.clear();
      _revealedPanels.clear();
      _backgroundImagePath = null;
      _clearedImages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTodoTab = _index == 0;
    final isProgressTab = _index == 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTodoTab
              ? 'ToDo List'
              : isProgressTab
              ? 'Progress'
              : 'Gallery',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.lightBlue,
        surfaceTintColor: Colors.transparent,
        actions: [
          // Progressタブのときだけ背景選択
          if (isProgressTab)
            IconButton(
              icon: const Icon(Icons.image, color: Colors.white),
              onPressed: _pickBackground,
              tooltip: '背景画像を選ぶ',
            ),

          // 開発用リセット（常に表示）
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: _clearAllData,
            tooltip: 'データを全削除',
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          TodoPage(
            tasks: _tasks,
            controller: _controller,
            onAdd: _addTask,
            onDelete: _deleteTask,
            onToggle: _toggleTask,
          ),
          ProgressPage(
            backgroundImagePath: _backgroundImagePath,
            revealedPanels: _revealedPanels,
            rows: rows,
            cols: cols,
            completedCount: _tasks.where((t) => t.done).length,
            totalCount: _tasks.length,
          ),
          GalleryPage(images: _clearedImages),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'ToDo'),
          BottomNavigationBarItem(icon: Icon(Icons.image), label: 'Progress'),
          BottomNavigationBarItem(
            icon: Icon(Icons.collections),
            label: 'Gallery',
          ),
        ],
      ),
    );
  }
}

/// ===== Page: ToDo =====
class TodoPage extends StatelessWidget {
  const TodoPage({
    super.key,
    required this.tasks,
    required this.controller,
    required this.onAdd,
    required this.onDelete,
    required this.onToggle,
  });

  final List<Todo> tasks;
  final TextEditingController controller;
  final Future<void> Function() onAdd;
  final Future<void> Function(int index) onDelete;
  final Future<void> Function(int index, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 入力欄 + 追加
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: '新しいタスクを入力',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: onAdd, child: const Text('追加')),
            ],
          ),
        ),
        const Divider(height: 0),

        // 一覧
        Expanded(
          child: tasks.isEmpty
              ? const Center(
                  child: Text(
                    'タスクはまだありません',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return CheckboxListTile(
                      title: Text(task.title),
                      value: task.done,
                      onChanged: (value) {
                        if (value == null) return;
                        onToggle(index, value);
                      },
                      secondary: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => onDelete(index),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// ===== Page: Progress =====
class ProgressPage extends StatelessWidget {
  const ProgressPage({
    super.key,
    required this.backgroundImagePath,
    required this.revealedPanels,
    required this.rows,
    required this.cols,
    required this.completedCount,
    required this.totalCount,
  });

  final String? backgroundImagePath;
  final Set<int> revealedPanels;
  final int rows;
  final int cols;
  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final totalPanels = rows * cols;
    final revealedCount = revealedPanels.length;

    return Column(
      children: [
        // 進捗表示（モチベ用）
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Text('Tasks: $completedCount / $totalCount'),
              const SizedBox(width: 16),
              Text('Panels: $revealedCount / $totalPanels'),
            ],
          ),
        ),

        // 背景 + 黒パネル
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (backgroundImagePath != null)
                Image.file(File(backgroundImagePath!), fit: BoxFit.cover)
              else
                const Center(
                  child: Text(
                    '右上のアイコンから背景画像を選んでください',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: totalPanels,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                    ),
                    itemBuilder: (context, index) {
                      final isRevealed = index < completedCount;
                      return Container(
                        decoration: BoxDecoration(
                          color: isRevealed ? Colors.transparent : Colors.black,
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ===== Page: Gallery =====
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key, required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const Center(
        child: Text('まだクリアした画像がありません', style: TextStyle(color: Colors.grey)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final path = images[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullscreenImagePage(path: path),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(path), fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

class FullscreenImagePage extends StatelessWidget {
  const FullscreenImagePage({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cleared Image')),
      body: Center(child: Image.file(File(path), fit: BoxFit.contain)),
    );
  }
}
