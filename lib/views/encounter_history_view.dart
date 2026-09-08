import 'package:flutter/material.dart';
import '../core/services/database_service.dart';
import '../core/models/classes.dart';

class EncounterHistoryView extends StatefulWidget {
  final bool isActive;

  const EncounterHistoryView({super.key, this.isActive = true});

  @override
  State<EncounterHistoryView> createState() => _EncounterHistoryViewState();
}

class _EncounterHistoryViewState extends State<EncounterHistoryView> {
  List<SavedEncounter> _encounters = [];
  bool _isLoading = true;
  int? _expandedEncounterId;
  Map<int, List<SavedEncounterPlayer>> _cachedPlayers = {};

  @override
  void initState() {
    super.initState();
    _loadEncounters();
  }

  @override
  void didUpdateWidget(covariant EncounterHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadEncounters();
    }
  }

  Future<void> _loadEncounters() async {
    setState(() => _isLoading = true);
    final list = await DatabaseService().getEncounters();
    setState(() {
      _encounters = list;
      _isLoading = false;
    });
  }

  Future<void> _toggleExpand(int encounterId) async {
    if (_expandedEncounterId == encounterId) {
      setState(() => _expandedEncounterId = null);
      return;
    }

    if (!_cachedPlayers.containsKey(encounterId)) {
      final players = await DatabaseService().getEncounterPlayers(encounterId);
      _cachedPlayers[encounterId] = players;
    }

    setState(() {
      _expandedEncounterId = encounterId;
    });
  }

  Future<void> _deleteEncounter(int id) async {
    await DatabaseService().deleteEncounter(id);
    _cachedPlayers.remove(id);
    _loadEncounters();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        title: const Text('Clear History', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete all saved encounters?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService().clearAllEncounters();
      _cachedPlayers.clear();
      _loadEncounters();
    }
  }

  String _formatTime(int milliseconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return "${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFB74D)))
                    : _encounters.isEmpty
                        ? _buildEmptyState()
                        : _buildEncounterList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const Icon(Icons.history, color: Color(0xFFFFB74D), size: 20),
        const SizedBox(width: 8),
        const Text(
          'Encounter History Records',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: _loadEncounters,
          icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
          tooltip: 'Refresh',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: _clearAll,
          icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 20),
          tooltip: 'Clear All History',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.history_toggle_off, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text(
            'No saved encounters found.\nCombat data will automatically record here after fights.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEncounterList() {
    return ListView.separated(
      itemCount: _encounters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final enc = _encounters[index];
        final isExpanded = _expandedEncounterId == enc.id;
        final players = _cachedPlayers[enc.id] ?? [];

        return Card(
          color: const Color(0xFF181B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: isExpanded ? const Color(0xFFFFB74D) : const Color(0xFF2B303C),
            ),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => _toggleExpand(enc.id),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                        color: const Color(0xFFFFB74D),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  enc.bossName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF252A36),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _formatDuration(enc.durationSeconds),
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(enc.startTime),
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Damage: ${enc.totalDamage}',
                            style: const TextStyle(
                              color: Color(0xFF81D4FA),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (enc.totalHeal != '0')
                            Text(
                              'Heal: ${enc.totalHeal}',
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 10),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _deleteEncounter(enc.id),
                        icon: const Icon(Icons.close, color: Colors.white24, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) _buildExpandedPlayers(players),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandedPlayers(List<SavedEncounterPlayer> players) {
    if (players.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFB74D)),
        ),
      );
    }

    return Container(
      color: const Color(0xFF13161C),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6.0),
            child: Text(
              'Combat Participants & Metrics',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          ...players.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            final cls = Classes.fromId(p.professionId);
            final critRate = p.hitCount > 0 ? (p.critHits / p.hitCount * 100) : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222D),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text(
                    '#${idx + 1}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${p.playerName} (${cls.name})',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'DPS: ${p.dps.toStringAsFixed(1)} | Dmg: ${p.totalDamage}',
                    style: const TextStyle(color: Color(0xFF81D4FA), fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Crit: ${critRate.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 10),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
