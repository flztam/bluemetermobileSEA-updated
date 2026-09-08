import 'package:flutter/material.dart';
import '../core/services/database_service.dart';
import '../core/models/classes.dart';

class EncounterHistoryView extends StatefulWidget {
  final bool isActive;

  const EncounterHistoryView({super.key, this.isActive = true});

  @override
  State<EncounterHistoryView> createState() => _EncounterHistoryViewState();
}

class _EncounterHistoryViewState extends State<EncounterHistoryView>
    with SingleTickerProviderStateMixin {
  List<SavedEncounter> _encounters = [];
  SavedEncounter? _selectedEncounter;
  List<SavedEncounterPlayer> _selectedPlayers = [];
  bool _isLoading = true;

  String? _selectedPlayerUid;
  List<SavedEncounterSkill> _selectedPlayerSkills = [];

  late TabController _metricTabController;

  @override
  void initState() {
    super.initState();
    _metricTabController = TabController(length: 3, vsync: this);
    _loadEncounters();
  }

  @override
  void dispose() {
    _metricTabController.dispose();
    super.dispose();
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

    if (list.isNotEmpty && (_selectedEncounter == null || !list.any((e) => e.id == _selectedEncounter!.id))) {
      _selectEncounter(list.first);
    }
  }

  Future<void> _selectEncounter(SavedEncounter enc) async {
    final players = await DatabaseService().getEncounterPlayers(enc.id);
    setState(() {
      _selectedEncounter = enc;
      _selectedPlayers = players;
      _selectedPlayerUid = null;
      _selectedPlayerSkills = [];
    });
  }

  Future<void> _selectPlayer(SavedEncounterPlayer player) async {
    if (_selectedEncounter == null) return;
    final skills = await DatabaseService().getEncounterSkills(
      _selectedEncounter!.id,
      player.playerUid,
    );
    setState(() {
      _selectedPlayerUid = player.playerUid;
      _selectedPlayerSkills = skills;
    });
  }

  Future<void> _deleteEncounter(int id) async {
    await DatabaseService().deleteEncounter(id);
    if (_selectedEncounter?.id == id) {
      _selectedEncounter = null;
      _selectedPlayers = [];
      _selectedPlayerUid = null;
      _selectedPlayerSkills = [];
    }
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
      setState(() {
        _encounters = [];
        _selectedEncounter = null;
        _selectedPlayers = [];
        _selectedPlayerUid = null;
        _selectedPlayerSkills = [];
      });
    }
  }

  Color _getClassColor(Classes cls) {
    switch (cls) {
      case Classes.stormblade:
        return Colors.purpleAccent;
      case Classes.frostMage:
        return Colors.lightBlueAccent;
      case Classes.windKnight:
        return Colors.greenAccent;
      case Classes.verdantOracle:
        return Colors.lightGreenAccent;
      case Classes.heavyGuardian:
        return Colors.green.shade500;
      case Classes.marksman:
        return Colors.amberAccent;
      case Classes.shieldKnight:
        return Colors.indigoAccent;
      case Classes.soulMusician:
        return Colors.pinkAccent;
      default:
        return Colors.grey;
    }
  }

  String _formatNumber(dynamic val) {
    final double numVal = val is num ? val.toDouble() : (double.tryParse(val.toString()) ?? 0.0);
    if (numVal >= 1000000) {
      return "${(numVal / 1000000).toStringAsFixed(1)}M";
    } else if (numVal >= 1000) {
      return "${(numVal / 1000).toStringAsFixed(1)}k";
    }
    return numVal.toStringAsFixed(0);
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
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              _buildTopHeader(),
              const SizedBox(height: 6),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFB74D)))
                    : _encounters.isEmpty
                        ? _buildEmptyState()
                        : Row(
                            children: [
                              // Left Panel: Encounter Selection List
                              SizedBox(
                                width: 200,
                                child: _buildEncounterSelectorList(),
                              ),
                              const SizedBox(width: 8),
                              // Right Panel: dps_view.dart style player bars
                              Expanded(
                                child: _selectedEncounter == null
                                    ? const Center(child: Text('Select an encounter', style: TextStyle(color: Colors.white38)))
                                    : _buildDpsViewFormattedPanel(),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        const Icon(Icons.history, color: Color(0xFFFFB74D), size: 18),
        const SizedBox(width: 6),
        const Text(
          'Encounter History Records',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        IconButton(
          onPressed: _loadEncounters,
          icon: const Icon(Icons.refresh, color: Colors.white70, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: _clearAll,
          icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
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
          Icon(Icons.history_toggle_off, color: Colors.white24, size: 44),
          SizedBox(height: 8),
          Text(
            'No saved encounter history.\nCombat data will automatically record here after fights.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEncounterSelectorList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2B303C)),
      ),
      child: ListView.separated(
        itemCount: _encounters.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFF252A36), height: 1),
        itemBuilder: (context, index) {
          final enc = _encounters[index];
          final isSelected = _selectedEncounter?.id == enc.id;

          return InkWell(
            onTap: () => _selectEncounter(enc),
            child: Container(
              color: isSelected ? const Color(0xFF252A36) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enc.bossName,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFFFB74D) : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Text(_formatTime(enc.startTime), style: const TextStyle(color: Colors.white38, fontSize: 9)),
                            const Spacer(),
                            Text(_formatDuration(enc.durationSeconds), style: const TextStyle(color: Colors.white70, fontSize: 9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteEncounter(enc.id),
                    icon: const Icon(Icons.close, color: Colors.white24, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDpsViewFormattedPanel() {
    final enc = _selectedEncounter!;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2B303C)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Header Bar matching dps_view.dart tabs
          SizedBox(
            height: 24,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _metricTabController,
                    labelPadding: EdgeInsets.zero,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorColor: Colors.transparent,
                    dividerColor: Colors.transparent,
                    labelColor: const Color(0xFFFFB74D),
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(child: Icon(Icons.flash_on, size: 16)),
                      Tab(child: Icon(Icons.shield, size: 16)),
                      Tab(child: Icon(Icons.local_hospital, size: 16)),
                    ],
                  ),
                ),
                Text(
                  '${enc.bossName} • ${_formatDuration(enc.durationSeconds)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2B303C), height: 8),
          Expanded(
            child: TabBarView(
              controller: _metricTabController,
              children: [
                _buildPlayerBarList('dps'),
                _buildPlayerBarList('taken'),
                _buildPlayerBarList('heal'),
              ],
            ),
          ),
          if (_selectedPlayerUid != null) ...[
            const Divider(color: Color(0xFF2B303C), height: 8),
            _buildSkillDetailCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerBarList(String metricType) {
    if (_selectedPlayers.isEmpty) {
      return const Center(child: Text('No player data recorded', style: TextStyle(color: Colors.white24, fontSize: 11)));
    }

    final players = List<SavedEncounterPlayer>.from(_selectedPlayers);
    if (metricType == 'heal') {
      players.sort((a, b) => b.hps.compareTo(a.hps));
    } else if (metricType == 'taken') {
      players.sort((a, b) => double.parse(b.totalTaken).compareTo(double.parse(a.totalTaken)));
    } else {
      players.sort((a, b) => b.dps.compareTo(a.dps));
    }

    double maxVal = 1.0;
    if (players.isNotEmpty) {
      if (metricType == 'heal') {
        maxVal = players.first.hps > 0 ? players.first.hps : 1.0;
      } else if (metricType == 'taken') {
        maxVal = double.tryParse(players.first.totalTaken) ?? 1.0;
      } else {
        maxVal = players.first.dps > 0 ? players.first.dps : 1.0;
      }
    }

    return ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, index) {
        final p = players[index];
        final cls = Classes.fromId(p.professionId);

        double currentVal = p.dps;
        String valText = "${_formatNumber(p.dps)}/s / ${_formatNumber(p.totalDamage)}";

        if (metricType == 'heal') {
          currentVal = p.hps;
          valText = "${_formatNumber(p.hps)}/s / ${_formatNumber(p.totalHeal)}";
        } else if (metricType == 'taken') {
          currentVal = double.tryParse(p.totalTaken) ?? 0.0;
          valText = "${_formatNumber(p.totalTaken)} taken";
        }

        final double percent = (currentVal / maxVal).clamp(0.0, 1.0);
        final isSelected = _selectedPlayerUid == p.playerUid;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectPlayer(p),
          child: Container(
            height: 22,
            margin: const EdgeInsets.only(bottom: 3),
            child: Stack(
              children: [
                // Background percentage bar matching dps_view.dart
                FractionallySizedBox(
                  widthFactor: percent,
                  child: Container(
                    color: _getClassColor(cls).withValues(alpha: isSelected ? 0.5 : 0.25),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Container(width: 3, color: _getClassColor(cls)),
                      const SizedBox(width: 4),
                      Text(
                        "${index + 1}.",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (cls != Classes.unknown) ...[
                        Image.asset(
                          cls.iconPath,
                          width: 12,
                          height: 12,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          '${p.playerName} (${cls.name})',
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFFFB74D) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        valText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkillDetailCard() {
    if (_selectedPlayerSkills.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(child: Text('No skill breakdown recorded for selected player', style: TextStyle(color: Colors.white38, fontSize: 10))),
      );
    }

    return Container(
      height: 100,
      color: const Color(0xFF181B22),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Skill Breakdown', style: TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.bold)),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _selectedPlayerUid = null),
                child: const Icon(Icons.close, color: Colors.white38, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              itemCount: _selectedPlayerSkills.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final s = _selectedPlayerSkills[index];
                final critRate = s.hitCount > 0 ? (s.critHits / s.hitCount * 100) : 0.0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: const Color(0xFF222630),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(s.skillName, style: const TextStyle(color: Colors.white, fontSize: 10), overflow: TextOverflow.ellipsis),
                      ),
                      Text('Dmg: ${_formatNumber(s.totalDamage)}', style: const TextStyle(color: Color(0xFF81D4FA), fontSize: 10)),
                      const SizedBox(width: 8),
                      Text('${s.hitCount} hits (${critRate.toStringAsFixed(0)}% crit)', style: const TextStyle(color: Colors.white54, fontSize: 9)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
