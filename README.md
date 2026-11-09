# Anjo da Guarda

Aplicativo Flutter para segurança de idosos: detecta possíveis quedas pelo
acelerômetro, pergunta "Você está bem?" e, sem resposta em 30 segundos, aciona
um alerta de emergência com a localização GPS. Também cadastra remédios por
foto e agenda lembretes diários.

## Como executar

Uma única base de código Flutter roda em **Android e iPhone**. Use sempre um
aparelho real: emuladores/simuladores não têm acelerômetro, GPS ou câmera de verdade.

```bash
flutter pub get
flutter test             # testes do algoritmo de queda, modelos e telas
```

### Android
Requisitos: Flutter 3.44+, Android SDK com a plataforma **37** (exigida pelo
`flutter_local_notifications` 23) e celular com Android 7.0+ (API 24).

1. No celular: Configurações → Sobre o telefone → toque 7× em "Número da versão";
   depois ative **Depuração USB** em Opções do desenvolvedor.
2. Conecte o cabo USB e aceite o pedido de depuração no celular.
3. Rode:
   ```bash
   flutter devices        # o celular deve aparecer na lista
   flutter run            # instala e abre o app
   ```
   Ou gere o APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.

### iPhone (exige Mac com Xcode)
Requisitos: macOS com Xcode atualizado, iPhone com iOS 15+ e um Apple ID
(a conta gratuita serve para instalar no próprio aparelho).

1. No Mac: `flutter pub get` e depois `open ios/Runner.xcworkspace`.
2. No Xcode, selecione o alvo **Runner** → aba **Signing & Capabilities**:
   - marque *Automatically manage signing* e escolha seu **Team** (Apple ID);
   - se o Xcode reclamar do identificador, troque o **Bundle Identifier**
     (`com.rotaverde.rotaVerde`) por um único, ex.: `com.seunome.anjodaguarda`.
3. Conecte o iPhone, confie no computador e ative o **Modo de Desenvolvedor**
   (Ajustes → Privacidade e Segurança → Modo de Desenvolvedor).
4. Rode `flutter run` no terminal (ou ▶ no Xcode).
5. Na 1ª execução com conta gratuita: Ajustes → Geral → VPN e Gerenciamento de
   Dispositivos → confie no seu certificado de desenvolvedor.

As dependências nativas do iOS são resolvidas automaticamente pelo Flutter
(Swift Package Manager ou CocoaPods, conforme a configuração do Flutter no Mac).

## Bibliotecas

| Pacote | Uso |
|---|---|
| `image_picker` | Abre a câmera para fotografar a caixa do remédio |
| `geolocator` | Latitude/longitude reais do GPS e permissões de localização |
| `flutter_local_notifications` | "Você está bem?", alerta de emergência e lembretes |
| `timezone` + `flutter_timezone` | Agendar lembretes no fuso horário do celular |
| `sensors_plus` | Leitura do acelerômetro (X, Y, Z) a ~50 Hz |
| `shared_preferences` + `path_provider` | Guardar remédios e fotos no aparelho |

## Estrutura de pastas

```
lib/
├── main.dart                     # cria serviços e controladores e inicia o app
├── app.dart                      # MaterialApp, abas e abertura da tela de alerta
├── core/app_theme.dart           # cores e tamanhos (acessível para idosos)
├── models/                       # Medication, EmergencyAlert
├── services/                     # acesso ao hardware e armazenamento
│   ├── fall_detector.dart        # algoritmo de queda (Dart puro, testável)
│   ├── location_service.dart     # GPS + permissões
│   ├── notification_service.dart # notificações locais e agendamento
│   ├── photo_service.dart        # câmera
│   └── medication_repository.dart
├── controllers/                  # regras que ligam os serviços
│   ├── safety_controller.dart    # acelerômetro → queda → 30 s → emergência
│   └── medication_controller.dart# foto → nome/horário → lembrete
├── screens/                      # início, remédios, localização, sensor, alerta
└── widgets/                      # botões grandes, cartões, gráfico do sensor
test/                             # testes unitários e de telas
```

## Permissões

### Android (`android/app/src/main/AndroidManifest.xml`)
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` — GPS
- `POST_NOTIFICATIONS` — notificações (Android 13+)
- `SCHEDULE_EXACT_ALARM` — lembrete no minuto exato (Android 12+)
- `RECEIVE_BOOT_COMPLETED` — reagendar lembretes após reiniciar o celular
- `VIBRATE`, `WAKE_LOCK` — notificações de alerta
- Receivers do `flutter_local_notifications` (agendamento, reinício e botão "ESTOU BEM")

A câmera é aberta pelo app de câmera do sistema (`image_picker`), por isso a
permissão `CAMERA` não é declarada. No `build.gradle.kts` foram ativados o
`compileSdk 37` e o *core library desugaring*, exigidos pelas notificações.
Os canais de notificação (queda, emergência, remédios) são criados ao abrir o app.

### iOS (`ios/Runner/Info.plist`)
- `NSCameraUsageDescription` — câmera para fotografar o remédio
- `NSPhotoLibraryUsageDescription` — exigido pela política da App Store para o `image_picker`
- `NSLocationWhenInUseUsageDescription` — GPS no alerta de emergência
- `NSMotionUsageDescription` — sensores de movimento (sem ela o app fecha ao ler o acelerômetro)
- Notificações: autorização pedida em tempo de execução; o `AppDelegate.swift`
  registra o delegate de notificações e o botão "ESTOU BEM" é uma categoria iOS.

## Como funciona a detecção de queda

`FallDetector` recebe cada leitura e calcula a aceleração total
`√(x² + y² + z²)` (≈ 9,8 m/s² em repouso):

1. **Impacto** — a aceleração passa de 25 m/s² (≈ 2,5 g).
2. **Imobilidade** — depois de 0,5 s, fica perto de 9,8 m/s² (±1,5) por 2 s.
   Se continuar se mexendo por mais de 4 s, o impacto é descartado.

Confirmada a queda, o `SafetyController` mostra a notificação e a tela
"Você está bem?" com contagem de 30 s. Sem resposta, gera o alerta de
emergência, busca o GPS e mostra a mensagem para a família.

## Roteiro de teste no celular

1. Abra o app e aceite as permissões de notificação e localização.
2. **Localização**: toque em "Atualizar localização" — aparecem latitude e longitude.
3. **Sensor**: veja X, Y e Z mudando ao mexer o celular.
4. **Queda**: segure o celular e solte-o sobre uma cama/almofada, deixando-o parado.
   Em ~3 s aparece "Você está bem?" com a contagem.
   - Toque em **ESTOU BEM** → tudo volta ao normal.
   - Repita e não responda → em 30 s abre o **Alerta de emergência** com o GPS.
     Abra "Alerta para a família" para ver os dados e copiar a mensagem.
5. **Remédios**: "Fotografar remédio" → tire a foto (dá para tirar outra) →
   digite o nome → escolha um horário 1–2 minutos à frente → salvar.
   O lembrete chega com a foto da caixa.
6. **Pedir ajuda** (tela inicial): aciona o alerta de emergência manualmente.

## Diferenças entre Android e iOS (tratadas no código)

| Tema | Android | iOS |
|---|---|---|
| Botão "ESTOU BEM" na notificação | `AndroidNotificationAction` | `DarwinNotificationCategory` |
| Foto no lembrete | `BigPictureStyle` | anexo (`DarwinNotificationAttachment`) com cópia da foto, pois o iOS move o arquivo anexado |
| Alarmes exatos | pede permissão "Alarmes e lembretes" | não existe; aviso escondido |
| App em segundo plano | continua por um tempo | é pausado; a contagem usa horário-limite e há um alerta agendado de reserva |
| Foto perdida se o app for fechado durante a câmera | recuperada (`retrieveLostData`) | não se aplica |

## Limitações

- O alerta familiar é demonstrado no app (mensagem com dados e link do mapa,
  que pode ser copiada). Não há envio automático por SMS/WhatsApp porque isso
  exige um serviço externo que não está configurado.
- A detecção de queda funciona com o app aberto. Em segundo plano o iOS pausa
  o app (e o Android pode limitar os sensores); monitorar com o app fechado
  exigiria um serviço em primeiro plano no Android e não é permitido no iOS
  para este tipo de app.
- Se o app for pausado durante a contagem de 30 s, a notificação de reserva
  avisa no fim da contagem; o GPS é obtido quando o app é aberto novamente.
- No Android 14+, "Alarmes e lembretes" vem desligado: a tela de remédios
  mostra um botão para ativar. Sem isso o lembrete pode atrasar alguns minutos.
