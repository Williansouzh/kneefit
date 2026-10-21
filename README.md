# FitKnee

App de treino, joelho e evolução física para quem precisa equilibrar hipertrofia com reabilitação
(feito para condropatia patelar, prioridade pernas e costas). Flutter, Android, **tudo no celular**:
sem servidor e sem conta.

## O que tem

- **Treino**: ficha da semana editável; cada série com carga, repetições, RIR e ✓; descanso automático;
  histórico e gráfico por exercício.
- **Semáforo de dor** (🟢🟡🔴 por joelho ao terminar o treino), que ajusta as cargas dos exercícios
  marcados como "de joelho". Regras em `lib/logic/knee.dart`, editáveis em Ajustes → Semáforo:
  - 🟢 segue progredindo (progressão dupla: topo das reps com o RIR da meta → +incremento);
  - 🟡 atenção: 85% da última carga sem dor; um 🟢 volta ao normal, um segundo 🟡 vai ao retorno 2;
  - 🔴 retorno fase 1 (50%) → fase 2 (70%) → fase 3 (85%) → liberado, avançando a cada 2 sessões 🟢;
  - duas 🔴 seguidas: aviso para procurar o fisioterapeuta.
- **Refeições**: horários fixos com alarme diário e checklist do dia (inclui shake).
- **Peso** com média móvel de 7 dias e ritmo de ganho por semana.
- **Fotos** a cada N semanas (frente, lado, costas) com linhas-guia, foto anterior em transparência e
  timer; comparação antes/depois com divisor. **Medidas** em cm.
- **Diário em vídeo**: até 10 min, câmera frontal, perguntas-guia na tela.
- **Resumo semanal** em texto para copiar ou enviar (treinador, fisio, nutricionista).
- **Backup** em JSON (sem fotos e vídeos), exportar e restaurar.

Não substitui avaliação profissional: as regras são um guia conservador.

## Rodar

```bash
flutter test
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

O release está assinado com a chave de debug desta máquina (uso pessoal). Para distribuir, crie uma
keystore própria.
