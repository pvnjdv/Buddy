import 'package:flutter/material.dart';
import '../services/task_service.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<dynamic> _tasks = [];
  bool _loading = true;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    _tasks = await TaskService.getTasks();
    setState(() => _loading = false);
  }

  Future<void> _createTask() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    if (title.isEmpty) return;
    await TaskService.createTask(title, desc);
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
      appBar: AppBar(title: const Text('Tasks')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task Title'),
            ),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _createTask,
              child: const Text('Create Task'),
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
                          trailing: Text(task['status']),
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
