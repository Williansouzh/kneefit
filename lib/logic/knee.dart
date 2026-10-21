import '../models.dart';

/// Fase do joelho, decidida pelo semáforo das sessões anteriores.
/// normal → caution (🟡) → retorno 1/2/3 (🔴), voltando uma fase a cada N sessões 🟢 seguidas.
enum KneePhase { normal, caution, return1, return2, return3 }

class KneeStatus {
  final KneePhase phase;
  final int greens; // sessões 🟢 seguidas na fase atual
  final int redStreak; // sessões 🔴 seguidas
  final Map<String, KneePhase> phaseAt; // fase em vigor em cada sessão (id → fase)
  final KneeRules rules;

  const KneeStatus(this.phase, this.greens, this.redStreak, this.phaseAt, this.rules);

  /// Multiplicador sobre a última carga boa nos exercícios de joelho.
  double get factor => switch (phase) {
        KneePhase.normal => 1,
        KneePhase.caution => rules.cautionFactor,
        KneePhase.return1 => rules.return1Factor,
        KneePhase.return2 => rules.return2Factor,
        KneePhase.return3 => rules.return3Factor,
      };

  bool get progressing => phase == KneePhase.normal;
  bool get inReturn => phase.index >= KneePhase.return1.index;

  /// Fisioterapeuta: dor forte em duas sessões seguidas.
  bool get seePhysio => redStreak >= 2;

  String get title => switch (phase) {
        KneePhase.normal => 'Joelho liberado',
        KneePhase.caution => 'Atenção: carga reduzida',
        KneePhase.return1 => 'Retorno — fase 1 de 3',
        KneePhase.return2 => 'Retorno — fase 2 de 3',
        KneePhase.return3 => 'Retorno — fase 3 de 3',
      };

  Pain get light => switch (phase) {
        KneePhase.normal => Pain.green,
        KneePhase.caution => Pain.yellow,
        _ => Pain.red,
      };

  String get advice => switch (phase) {
        KneePhase.normal => 'Pode progredir: bateu o topo das repetições com o RIR da meta, sobe a carga.',
        KneePhase.caution =>
          'Exercícios de joelho com ${pct(factor)} da carga e só na amplitude sem dor. Uma sessão 🟢 e volta ao normal.',
        _ => 'Exercícios de joelho com ${pct(factor)} da carga, amplitude sem dor e isometria. '
            'Faltam ${rules.greensToAdvance - greens} sessão(ões) 🟢 para a próxima fase.',
      };

  static String pct(double f) => '${(f * 100).round()}%';
}

/// Lê as sessões terminadas em ordem e devolve a fase atual do joelho.
KneeStatus kneeStatus(List<Session> sessions, KneeRules rules) {
  final ordered = sessions.where((s) => s.finished).toList()..sort((a, b) => a.date.compareTo(b.date));
  var phase = KneePhase.normal;
  var greens = 0, reds = 0;
  final phaseAt = <String, KneePhase>{};
  for (final s in ordered) {
    phaseAt[s.id] = phase;
    final pain = s.worstPain;
    if (pain == null) continue;
    switch (pain) {
      case Pain.red:
        phase = KneePhase.return1;
        greens = 0;
        reds++;
      case Pain.yellow:
        reds = 0;
        greens = 0;
        if (phase == KneePhase.normal) {
          phase = KneePhase.caution;
        } else if (phase == KneePhase.caution) {
          phase = KneePhase.return2;
        }
      case Pain.green:
        reds = 0;
        if (phase == KneePhase.caution) {
          phase = KneePhase.normal;
          greens = 0;
        } else if (phase != KneePhase.normal && ++greens >= rules.greensToAdvance) {
          phase = KneePhase.values[phase == KneePhase.return3 ? 0 : phase.index + 1];
          greens = 0;
        }
    }
  }
  return KneeStatus(phase, greens, reds, phaseAt, rules);
}
