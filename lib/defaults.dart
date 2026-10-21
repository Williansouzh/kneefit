import 'models.dart';

/// Ficha inicial: 4 dias, pernas e costas com prioridade, exercícios de joelho em amplitude
/// segura para condropatia patelar (flexão até ~90° com carga, extensora no arco final).
/// É só um ponto de partida: tudo é editável em Treino → Ficha.
List<WorkoutDay> defaultPlan() => [
      WorkoutDay(name: 'A — Pernas (quadríceps)', weekdays: [1], exercises: [
        Exercise(name: 'Leg press 45° (até 90°)', group: 'Pernas', sets: 4, repMin: 10, repMax: 12, knee: true,
            increment: 5, restSeconds: 120, notes: 'Pés altos na plataforma; não passe de 90° no joelho.'),
        Exercise(name: 'Cadeira extensora (90°→45°)', group: 'Pernas', sets: 3, repMin: 12, repMax: 15, knee: true,
            notes: 'Arco que não dói; desça devagar (3 s).'),
        Exercise(name: 'Elevação pélvica', group: 'Glúteos', sets: 4, repMin: 8, repMax: 12, increment: 5, restSeconds: 120),
        Exercise(name: 'Mesa flexora', group: 'Pernas', sets: 3, repMin: 10, repMax: 12),
        Exercise(name: 'Panturrilha em pé', group: 'Panturrilha', sets: 4, repMin: 12, repMax: 15, restSeconds: 60),
        Exercise(name: 'Isometria na parede (45°)', group: 'Reabilitação', sets: 3, repMin: 30, repMax: 45, rir: 0,
            seconds: true, knee: true, increment: 0, restSeconds: 60, notes: 'Analgesia e força sem atrito: deve ser 🟢.'),
      ]),
      WorkoutDay(name: 'B — Costas e bíceps', weekdays: [2], exercises: [
        Exercise(name: 'Puxada frontal', group: 'Costas', sets: 4, repMin: 8, repMax: 12),
        Exercise(name: 'Remada baixa', group: 'Costas', sets: 4, repMin: 8, repMax: 12),
        Exercise(name: 'Remada unilateral com halter', group: 'Costas', sets: 3, repMin: 10, repMax: 12, increment: 2),
        Exercise(name: 'Pulldown na polia (braço reto)', group: 'Costas', sets: 3, repMin: 12, repMax: 15),
        Exercise(name: 'Rosca direta', group: 'Bíceps', sets: 3, repMin: 8, repMax: 12, increment: 2),
        Exercise(name: 'Face pull', group: 'Ombros', sets: 3, repMin: 15, repMax: 20, restSeconds: 60),
      ]),
      WorkoutDay(name: 'C — Pernas (posterior)', weekdays: [4], exercises: [
        Exercise(name: 'Levantamento terra romeno', group: 'Pernas', sets: 4, repMin: 8, repMax: 10, increment: 5,
            restSeconds: 150),
        Exercise(name: 'Agachamento no banco (até 90°)', group: 'Pernas', sets: 3, repMin: 8, repMax: 10, knee: true,
            restSeconds: 120, notes: 'Senta no banco e sobe; joelho acompanha a ponta do pé.'),
        Exercise(name: 'Step-up baixo', group: 'Pernas', sets: 3, repMin: 10, repMax: 12, knee: true, increment: 2,
            notes: 'Caixa baixa (20–30 cm), sobe controlando.'),
        Exercise(name: 'Flexora sentada', group: 'Pernas', sets: 3, repMin: 10, repMax: 12),
        Exercise(name: 'Cadeira abdutora', group: 'Glúteos', sets: 3, repMin: 15, repMax: 20, restSeconds: 60),
        Exercise(name: 'Panturrilha sentada', group: 'Panturrilha', sets: 4, repMin: 12, repMax: 15, restSeconds: 60),
      ]),
      WorkoutDay(name: 'D — Superiores', weekdays: [5], exercises: [
        Exercise(name: 'Barra fixa (ou graviton)', group: 'Costas', sets: 4, repMin: 6, repMax: 10),
        Exercise(name: 'Supino inclinado com halter', group: 'Peito', sets: 4, repMin: 8, repMax: 12, increment: 2),
        Exercise(name: 'Remada na máquina', group: 'Costas', sets: 3, repMin: 10, repMax: 12),
        Exercise(name: 'Desenvolvimento com halter', group: 'Ombros', sets: 3, repMin: 8, repMax: 12, increment: 2),
        Exercise(name: 'Elevação lateral', group: 'Ombros', sets: 3, repMin: 12, repMax: 15, increment: 1, restSeconds: 60),
        Exercise(name: 'Tríceps na polia', group: 'Tríceps', sets: 3, repMin: 10, repMax: 12),
      ]),
    ];

/// Refeições para quem esquece de comer (ectomorfo): horários fixos, sem contar calorias.
List<Meal> defaultMeals() => [
      Meal(name: 'Café da manhã', hour: 7, minute: 30, hint: 'Ovos, pão, fruta'),
      Meal(name: 'Lanche', hour: 10, minute: 0, hint: 'Iogurte, castanhas, banana'),
      Meal(name: 'Almoço', hour: 12, minute: 30, hint: 'Prato cheio: arroz, feijão, carne, salada'),
      Meal(name: 'Shake', hour: 16, minute: 0, hint: 'Leite, aveia, banana, pasta de amendoim, whey'),
      Meal(name: 'Jantar', hour: 19, minute: 30, hint: 'Igual ao almoço'),
      Meal(name: 'Ceia', hour: 22, minute: 0, hint: 'Leite, sanduíche ou pasta de amendoim'),
    ];

const defaultMeasures = ['Braço D', 'Braço E', 'Peito', 'Cintura', 'Coxa D', 'Coxa E', 'Panturrilha'];

/// Perguntas-guia do diário em vídeo.
const videoPrompts = [
  'Como foi a semana de treino?',
  'Como está o joelho hoje? Dor de 0 a 10?',
  'O que mudou no corpo ou na disposição?',
  'Comeu bem? O que atrapalhou?',
  'Qual o foco da próxima semana?',
];
