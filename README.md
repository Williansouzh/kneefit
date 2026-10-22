# FitKnee

App de treino, joelho e evolução física para quem precisa equilibrar hipertrofia com reabilitação
(feito para condropatia patelar, prioridade pernas e costas). Flutter, Android, **tudo no celular**,
sem servidor e sem conta, com cópia opcional no seu Cloudflare R2.

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
- **Nuvem (opcional)**: fotos, vídeos e dados com cópia automática no Cloudflare R2; restaura num
  celular novo. Veja abaixo.
- **Backup** em JSON (sem fotos e vídeos), exportar e restaurar.

Não substitui avaliação profissional: as regras são um guia conservador.

## Rodar

```bash
flutter test
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

O release está assinado com a chave de debug desta máquina (uso pessoal). Para distribuir, crie uma
keystore própria.

## Nuvem (Cloudflare R2)

Os arquivos vão do celular **direto para o R2**, por links assinados. Nada fica em servidor seu:
o Worker em `cloud/` só confere o token e assina os links. Tudo continua também no celular.

```
App ── token ──▶ Worker (assina o link) ──▶ link de 1 hora
App ──────────── PUT/GET direto ─────────▶ bucket R2 privado
```

O app sincroniza ao abrir e uns segundos depois de cada mudança. Primeiro sobem as fotos e os vídeos,
depois o `fitknee.json` com os dados, e por fim saem do bucket os arquivos excluídos no app.

**Configurar (uma vez):**

1. No painel da Cloudflare, em **R2**, crie o bucket `fitknee` (privado, como vem por padrão).
2. Em **R2 → Manage API tokens**, crie um token com permissão **Object Read & Write** só no bucket
   `fitknee`. Anote o *Access Key ID*, o *Secret Access Key* e o *Account ID*.
3. Publique o Worker:
   ```bash
   cd cloud
   npm install
   npx wrangler@4 login
   npx wrangler@4 secret put TOKEN                  # cole um valor de: openssl rand -hex 32
   npx wrangler@4 secret put R2_ACCOUNT_ID
   npx wrangler@4 secret put R2_ACCESS_KEY_ID
   npx wrangler@4 secret put R2_SECRET_ACCESS_KEY
   npm run deploy                                    # mostra o endereço https://fitknee-cloud....workers.dev
   ```
4. No app: **Ajustes → Nuvem → Backup no Cloudflare R2**, com o endereço do Worker e o TOKEN.

Celular novo: instale o app, conecte com o mesmo endereço e token e toque em **Restaurar da nuvem**.

**Testes** (precisam de um S3 local; o `docker compose up -d` do GymApp sobe um na porta 8333):

```bash
cd cloud && npm test                                    # o Worker
cd cloud && TOKEN=um-token-de-teste-comprido PORT=8788 npm run local
CLOUD_URL=http://localhost:8788 CLOUD_TOKEN=um-token-de-teste-comprido flutter test test/cloud_test.dart
```

