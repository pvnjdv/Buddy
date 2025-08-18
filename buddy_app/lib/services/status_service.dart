import '../models/flow_models.dart';

class StatusService {
  static Future<List<StatusItem>> getStatuses() async {
    // Simulate a tiny network delay
    await Future.delayed(const Duration(milliseconds: 150));

    final now = DateTime.now();
    final names = [
      'Alice',
      'Bob',
      'Charlie',
      'Diana',
      'Ethan',
      'Fiona',
      'George',
      'Hana',
    ];

    final items = List<StatusItem>.generate(names.length, (i) {
      return StatusItem(
        id: 'status_$i',
        userId: 'user_$i',
        userName: names[i],
        mediaUrl: 'https://picsum.photos/seed/buddy_status_$i/240/240',
        type: StatusType.image,
        timestamp: now.subtract(Duration(hours: 3 * i)),
        seen: i % 3 == 0,
      );
    });

    return items;
  }
}
