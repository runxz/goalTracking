import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final goalsList = prefs.getStringList('goals') ?? [];
  final goals =
      goalsList.map((goalJson) => Goal.fromJson(jsonDecode(goalJson))).toList();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => GoalsProvider(goals: goals),
        ),
        // Add other providers here
      ],
      child: MyApp(),
    ),
  );
}

class GoalsProvider extends ChangeNotifier {
  List<Goal> _goals;

  GoalsProvider({required List<Goal> goals}) : _goals = goals;

  List<Goal> get goals => _goals;

  void addGoal(Goal goal) async {
    _goals.add(goal);
    notifyListeners();
    await _saveGoals();
  }

  void editGoal(int index, Goal updatedGoal) async {
    _goals[index] = updatedGoal;
    notifyListeners();
    await _saveGoals();
  }

  void deleteGoal(int index) async {
    _goals.removeAt(index);
    notifyListeners();
    await _saveGoals();
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final goalsList = _goals.map((goal) => jsonEncode(goal.toJson())).toList();
    await prefs.setStringList('goals', goalsList);
  }
}

class Goal {
  String title;
  String description;
  bool isCompleted;
  DateTime? completionTime;

  Goal(
      {required this.title,
      required this.description,
      this.isCompleted = false,
      this.completionTime});

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'completionTime': completionTime?.millisecondsSinceEpoch,
    };
  }

  Goal.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        description = json['description'],
        isCompleted = json['isCompleted'],
        completionTime = json['completionTime'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['completionTime'])
            : null;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Goal Tracker App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: GoalsScreen(),
    );
  }
}

class GoalsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final goalsProvider = Provider.of<GoalsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Goal Tracker'),
      ),
      body: ListView.builder(
        itemCount: goalsProvider.goals.length,
        itemBuilder: (context, index) {
          final goal = goalsProvider.goals[index];
          return ListTile(
            title: Text(goal.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.description),
                if (goal.completionTime != null)
                  Text(
                      'Completion Time: ${DateFormat('MMM dd, yyyy - HH:mm').format(goal.completionTime!)}'),
              ],
            ),
            trailing: Checkbox(
              value: goal.isCompleted,
              onChanged: (value) {
                goal.isCompleted = value ?? false;
                goalsProvider.editGoal(index, goal);
              },
            ),
            onLongPress: () {
              // Show options for editing or deleting the goal.
              _showGoalOptions(context, index, goal);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => AddGoalScreen(),
          ));
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void _showGoalOptions(BuildContext context, int index, Goal goal) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit Goal'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => EditGoalScreen(index: index),
                  ));
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete Goal'),
                onTap: () {
                  Navigator.pop(context);
                  Provider.of<GoalsProvider>(context, listen: false)
                      .deleteGoal(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class AddGoalScreen extends StatelessWidget {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  DateTime? selectedTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Goal'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text;
                final description = descriptionController.text;
                if (title.isNotEmpty && description.isNotEmpty) {
                  final newGoal = Goal(
                      title: title,
                      description: description,
                      completionTime: selectedTime);
                  Provider.of<GoalsProvider>(context, listen: false)
                      .addGoal(newGoal);
                  Navigator.pop(context);
                }
              },
              child: Text('Add Goal'),
            ),
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
              onPressed: () async {
                final selectedDateTime = await _selectDateTime(context);
                if (selectedDateTime != null) {
                  selectedTime = selectedDateTime;
                }
              },
              child: Text('Set Completion Time'),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _selectDateTime(BuildContext context) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
    );

    if (selectedDate == null) return null;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime == null) return null;

    final dateTime = DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, selectedTime.hour, selectedTime.minute);
    return dateTime;
  }
}

class EditGoalScreen extends StatelessWidget {
  final int index;
  EditGoalScreen({required this.index});

  @override
  Widget build(BuildContext context) {
    final goalsProvider = Provider.of<GoalsProvider>(context);
    final goal = goalsProvider.goals[index];

    final TextEditingController titleController =
        TextEditingController(text: goal.title);
    final TextEditingController descriptionController =
        TextEditingController(text: goal.description);

    DateTime? selectedTime = goal.completionTime;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Goal'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedTitle = titleController.text;
                final updatedDescription = descriptionController.text;
                if (updatedTitle.isNotEmpty && updatedDescription.isNotEmpty) {
                  final updatedGoal = Goal(
                      title: updatedTitle,
                      description: updatedDescription,
                      isCompleted: goal.isCompleted,
                      completionTime: selectedTime);
                  goalsProvider.editGoal(index, updatedGoal);
                  Navigator.pop(context);
                }
              },
              child: Text('Save Changes'),
            ),
            ElevatedButton(
              onPressed: () async {
                final selectedDateTime =
                    await _selectDateTime(context, selectedTime);
                if (selectedDateTime != null) {
                  selectedTime = selectedDateTime;
                }
              },
              child: Text('Set Completion Time'),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _selectDateTime(
      BuildContext context, DateTime? initialTime) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
    );

    if (selectedDate == null) return null;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTime ?? DateTime.now()),
    );

    if (selectedTime == null) return null;

    final dateTime = DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, selectedTime.hour, selectedTime.minute);
    return dateTime;
  }
}
