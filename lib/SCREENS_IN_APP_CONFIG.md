# Screens in current app configuration

Gamitin ito para **i-fix / i-theme** lang ang screens na talagang nasa app flow. Huwag gumawa ng unnecessary fixes sa screens na hindi naaabot.

## Source of truth
- **Entry:** `main.dart` → `home: EnhancedSplashScreen()`
- **Routes:** `main.dart` → `routes: { ... }`
- **Main tabs:** `main_navigation.dart` → `_screens`: [ModernHomeScreen, LocalChatScreen, EmergencyDetectionScreen, ModernProfileScreen]

---

## IN APP (naaabot sa current config)

### Routes (main.dart)
| Route | Screen |
|-------|--------|
| (home) | EnhancedSplashScreen |
| /splash | SplashScreen |
| /signin | ModernSignInScreen |
| /signin-simple | SignInScreen |
| /signup | SignUpScreen |
| /forgot-password | ForgotPasswordScreen |
| /reset-password | ResetPasswordScreen |
| /two-factor-verification | TwoFactorVerificationScreen |
| /tutorial | InteractiveTutorialScreen |
| /tutorial-old | TutorialWalkthroughScreen |
| /address-setup | AddressSetupScreen |
| /update-profile | UpdateProfileScreen |
| /esp32-auth | ESP32AuthScreen |
| /esp32-scanner | ESP32DeviceScanner |
| /disaster-demo | DisasterDemoScreen |
| /main | MainNavigation |

### Main tabs (MainNavigation)
- ModernHomeScreen
- LocalChatScreen
- EmergencyDetectionScreen
- ModernProfileScreen

### Reachable via push from above
- NotificationSettingsScreen (from ModernProfileScreen)
- (UpdateProfileScreen, ESP32DeviceScanner, DisasterDemoScreen via pushNamed)

---

## NOT IN APP (hindi naaabot sa current config)

- **HomeScreen** (old) – hindi na ginagamit; replaced by ModernHomeScreen
- **CallsScreen** – tanging reference: HomeScreen (old)
- **CallDetailScreen** – tanging reference: CallsScreen
- **MessagesScreen** – tanging reference: HomeScreen (old)
- **MessageDetailScreen** – tanging reference: MessagesScreen
- **PeopleScreen** – tanging reference: HomeScreen (old)
- **ModernPeopleScreen** – hindi nasa routes/tabs; kung may link man, sa old flow lang
- **ModernPersonalChatScreen** – from PeopleScreen
- **PrivateChatScreen** – from ModernPeopleScreen
- **GlobalChatScreen, ModernGlobalChatScreen, EnhancedGlobalChatScreen** – walang Navigator.push/pushNamed sa codebase
- **AnimationDemoScreen** – tanging reference: HomeScreen (old)
- **ProfileScreen** (old) – hindi nasa MainNavigation; ginagamit na ModernProfileScreen

---

## Rekomendasyon

- **Dark mode / theme / const fixes:** Gawin lang sa screens na nasa **IN APP** list.
- Kung may linter/const errors sa **NOT IN APP** screens, puwede i-fix para clean ang analyze, o i-ignore kung hindi naman na gagamitin (optional).
- Huwag mag-add ng bagong features o refactor sa NOT IN APP screens maliban kung balak na silang isama ulit sa app.
