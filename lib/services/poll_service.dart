import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityPoll {
  final String id;
  final String title;
  final String optionOne;
  final String optionTwo;
  final DateTime pollDate;
  final int optionOneVotes;
  final int optionTwoVotes;
  final DateTime createdAt;

  const CommunityPoll({
    required this.id,
    required this.title,
    required this.optionOne,
    required this.optionTwo,
    required this.pollDate,
    required this.optionOneVotes,
    required this.optionTwoVotes,
    required this.createdAt,
  });

  factory CommunityPoll.fromMap(Map<String, dynamic> row) {
    final dateParts = (row['poll_date'] as String).split('-');
    return CommunityPoll(
      id: row['id'] as String,
      title: row['title'] as String,
      optionOne: row['option_one'] as String,
      optionTwo: row['option_two'] as String,
      pollDate: DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      ),
      optionOneVotes: row['option_one_votes'] as int,
      optionTwoVotes: row['option_two_votes'] as int,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  int get totalVotes => optionOneVotes + optionTwoVotes;

  DateTime get expiresAt => createdAt.add(const Duration(days: 7));

  bool get isExpired => !DateTime.now().isBefore(expiresAt);
}

class CommunityPollDraft {
  final String title;
  final String optionOne;
  final String optionTwo;
  final DateTime pollDate;

  const CommunityPollDraft({
    required this.title,
    required this.optionOne,
    required this.optionTwo,
    required this.pollDate,
  });
}

class PollVote {
  final String pollId;
  final int optionIndex;

  const PollVote({required this.pollId, required this.optionIndex});

  factory PollVote.fromMap(Map<String, dynamic> row) => PollVote(
        pollId: row['poll_id'] as String,
        optionIndex: row['option_index'] as int,
      );
}

class PollService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Stream<List<CommunityPoll>> watchPolls() => _client
      .from('polls')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(CommunityPoll.fromMap).toList());

  static Stream<List<PollVote>> watchMyVotes(String userId) => _client
      .from('poll_votes')
      .stream(primaryKey: ['poll_id', 'user_id'])
      .eq('user_id', userId)
      .map((rows) => rows.map(PollVote.fromMap).toList());

  static Future<void> create(CommunityPollDraft draft) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Silakan masuk kembali.');

    final date = draft.pollDate;
    final dateString =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _client.from('polls').insert({
      'title': draft.title.trim(),
      'option_one': draft.optionOne.trim(),
      'option_two': draft.optionTwo.trim(),
      'poll_date': dateString,
      'created_by': user.id,
    });
  }

  static Future<void> delete(String pollId) async {
    await _client.from('polls').delete().eq('id', pollId);
  }

  static Future<void> castVote({
    required String pollId,
    required int optionIndex,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Silakan masuk kembali.');
    await _client.from('poll_votes').insert({
      'poll_id': pollId,
      'user_id': user.id,
      'option_index': optionIndex,
    });
  }
}
