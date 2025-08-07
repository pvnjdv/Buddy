import 'package:flutter/material.dart';
import '../services/task_service.dart';

class TaskerScreen extends StatefulWidget {
  const TaskerScreen({super.key});

  @override
  State<TaskerScreen> createState() => _TaskerScreenState();
}

class _TaskerScreenState extends State<TaskerScreen> {
  List<dynamic> _tasks = [];
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = true;

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _loading = true);
    _tasks = await TaskService.getTasks();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _createTask() async {
    await TaskService.createTask(_titleController.text, _descController.text);
    _titleController.clear();
    _descController.clear();
    await _loadTasks();
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            ElevatedButton(
              onPressed: _createTask,
              child: const Text('Add Task'),
            ),
            const SizedBox(height: 16),
            _loading
                ? const CircularProgressIndicator()
                : Expanded(
                    child: ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return ListTile(
                          title: Text(task['title']),
                          subtitle: Text(task['description'] ?? ''),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
