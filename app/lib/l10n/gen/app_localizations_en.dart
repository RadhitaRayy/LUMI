// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Light up your day.';

  @override
  String appVersionLine(String version) {
    return 'Lumi $version · Light up your day.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get back => 'Back';

  @override
  String get retry => 'Try again';

  @override
  String get later => 'Later';

  @override
  String get splashSkip => 'Skip to Lumi';

  @override
  String get errorNetwork =>
      'Can\'t reach Lumi. Check your connection and try again.';

  @override
  String get errorUnknown => 'Something went wrong. Try again.';

  @override
  String get errorInvalidCredentials => 'Wrong email or password.';

  @override
  String get errorAccountBlocked =>
      'Your account is blocked. Contact the Lumi admin.';

  @override
  String get errorRegistrationClosed =>
      'Sign-ups are closed right now. Try again later.';

  @override
  String get errorCodeExpired => 'This code has expired. Ask for a new one.';

  @override
  String get errorCodeAttempts => 'Too many attempts. Ask for a new code.';

  @override
  String get errorCodeInvalid => 'Invalid code. Ask for a new one.';

  @override
  String get errorTooManyRequests =>
      'Too many requests. Try again in a moment.';

  @override
  String get errorNoModel => 'Lumi\'s AI isn\'t set up yet. Try again later.';

  @override
  String get loginGreeting => 'Welcome back!';

  @override
  String get loginSubtitle => 'Sign in to keep chatting with Lumi.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'you@email.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'At least 8 characters';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get signIn => 'Sign in';

  @override
  String get noAccount => 'No account yet?';

  @override
  String get signUpFree => 'Sign up free';

  @override
  String get fieldRequired => 'Fill this in first.';

  @override
  String get emailInvalid => 'That doesn\'t look like an email address.';

  @override
  String get catWaving => 'Lumi the cat, waving';

  @override
  String get registerTitle => 'Create your Lumi account';

  @override
  String get registerSubtitle =>
      'It\'s free. We\'ll email you a code to make sure the address is yours.';

  @override
  String get nameLabel => 'Nickname';

  @override
  String get nameHint => 'So Lumi knows what to call you';

  @override
  String get pwStrengthEmpty => 'At least 8 characters';

  @override
  String pwStrengthShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more characters to go',
      one: '1 more character to go',
    );
    return '$_temp0';
  }

  @override
  String get pwStrengthWeak => 'Okay. Add numbers to make it stronger.';

  @override
  String get pwStrengthGood => 'Good, almost there.';

  @override
  String get pwStrengthStrong => 'Strong. Nice!';

  @override
  String get passwordTooShort => 'Use at least 8 characters.';

  @override
  String get registerButton => 'Sign up and send code';

  @override
  String get haveAccount => 'Already have an account?';

  @override
  String get verifyTitle => 'Check your email';

  @override
  String verifyBody(String email) {
    return 'We sent a 6-digit code to $email. It works for 15 minutes.';
  }

  @override
  String get verifyCodeLabel => '6-digit verification code';

  @override
  String get verifyButton => 'Verify';

  @override
  String resendIn(String time) {
    return 'Resend code in $time';
  }

  @override
  String get resendCode => 'Resend code';

  @override
  String get codeResent => 'New code sent';

  @override
  String get checkSpam => 'Not in your inbox? Check spam or promotions.';

  @override
  String wrongCodeLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wrong code. $count attempts left.',
      one: 'Wrong code. 1 attempt left.',
    );
    return '$_temp0';
  }

  @override
  String get verifiedTitle => 'Email verified';

  @override
  String get verifiedBody => 'Your account is ready. Lumi is waiting.';

  @override
  String get startChatting => 'Start chatting';

  @override
  String get useAnotherAccount => 'Use another account';

  @override
  String get forgotTitle => 'Forgot your password?';

  @override
  String get forgotBody =>
      'No worries. Enter your account email and we\'ll send a code to set a new password.';

  @override
  String get sendCode => 'Send code';

  @override
  String get sending => 'Sending…';

  @override
  String get resetTitle => 'Set a new password';

  @override
  String get resetBody =>
      'Enter the code from your email, then your new password. Every device will be signed out after this.';

  @override
  String get codeLabel => '6-digit code';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get repeatPasswordLabel => 'Repeat new password';

  @override
  String get repeatPasswordHint => 'Type it once more';

  @override
  String get passwordsDontMatch => 'The passwords don\'t match.';

  @override
  String get savePassword => 'Save password';

  @override
  String get passwordChangedTitle => 'Password changed';

  @override
  String get passwordChangedBody =>
      'For your safety, every device has been signed out. Sign in again with your new password.';

  @override
  String get goToSignIn => 'Go to sign in';

  @override
  String stepOf(int step, int total) {
    return '$step/$total';
  }

  @override
  String get newChatTitle => 'New chat';

  @override
  String quotaLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages left today',
      one: '1 message left today',
      zero: 'No messages left today',
    );
    return '$_temp0';
  }

  @override
  String get usingOwnKey => 'Using your own AI key';

  @override
  String get messageHint => 'Ask Lumi anything…';

  @override
  String get messageFieldLabel => 'Message to Lumi';

  @override
  String get send => 'Send';

  @override
  String get stopAnswer => 'Stop answer';

  @override
  String get stopped => 'Stopped';

  @override
  String get answerFailed => 'Lumi couldn\'t answer.';

  @override
  String get typing => 'Lumi is typing';

  @override
  String get openHistory => 'Chat history';

  @override
  String get openSettings => 'Settings';

  @override
  String emptyChatTitle(String name) {
    return 'Hi $name! What can I help with?';
  }

  @override
  String get emptyChatBody =>
      'Ask anything: plans, recipes, emails, or learning something new.';

  @override
  String get suggestionTrip => 'Plan a 3-day trip';

  @override
  String get suggestionEmail => 'Write a polite email';

  @override
  String get suggestionExplain => 'Explain something simply';

  @override
  String get suggestionTripPrompt => 'Help me plan a relaxed 3-day trip.';

  @override
  String get suggestionEmailPrompt =>
      'Help me write a polite email asking for a day off.';

  @override
  String get suggestionExplainPrompt =>
      'Explain how the internet works, simply.';

  @override
  String get chatGone => 'This chat was deleted on another device.';

  @override
  String get copyCode => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get historyTitle => 'History';

  @override
  String get newChatShort => 'New';

  @override
  String get searchChats => 'Search chats';

  @override
  String get groupToday => 'Today';

  @override
  String get groupYesterday => 'Yesterday';

  @override
  String get groupLast7 => 'Last 7 days';

  @override
  String get groupOlder => 'Older';

  @override
  String get noResultsTitle => 'Nothing found';

  @override
  String get noResultsBody => 'Try other words from the title or the chat.';

  @override
  String get noChatsTitle => 'No chats yet';

  @override
  String get noChatsBody =>
      'Start one and it will show up here, on every device.';

  @override
  String get deleteChatTitle => 'Delete this chat?';

  @override
  String deleteChatBody(String title) {
    return '“$title” will disappear from all your devices and can\'t be brought back.';
  }

  @override
  String deleteChatA11y(String title) {
    return 'Delete $title';
  }

  @override
  String get delete => 'Delete';

  @override
  String get chatDeleted => 'Chat deleted';

  @override
  String get newFromOtherDevice => 'New from another device';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get verified => 'Verified';

  @override
  String quotaUsed(int used, int limit) {
    return '$used of $limit messages used';
  }

  @override
  String get quotaNote =>
      'Daily quota on Lumi\'s key. Resets at 00:00 WIB. Use your own key for no limit.';

  @override
  String get ownKeyNote => 'Your own AI key is on, so there is no daily limit.';

  @override
  String get myAiKey => 'My AI key';

  @override
  String get notSet => 'Not set';

  @override
  String get statusOn => 'On';

  @override
  String get statusOff => 'Off';

  @override
  String get activeDevices => 'Active devices';

  @override
  String get changePassword => 'Change password';

  @override
  String get language => 'Language';

  @override
  String get languageFollowPhone => 'Follow phone';

  @override
  String get languageNote =>
      'Lumi\'s emails and messages follow this language too.';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutTitle => 'Sign out of Lumi?';

  @override
  String get signOutBody =>
      'Your chats stay safe in your account. Sign in again anytime.';

  @override
  String get changePasswordNote =>
      'Other devices will be signed out. This phone stays signed in.';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get passwordChangedToast => 'Password changed';

  @override
  String get aiKeyIntro =>
      'Use your own API key so chats aren\'t limited by the daily quota. The key is stored encrypted on the server and never shown again.';

  @override
  String get providerLabel => 'Provider';

  @override
  String get providerOther => 'Other';

  @override
  String get providerOpenRouterHint =>
      'Lots of free models labelled :free. Get a key at openrouter.ai.';

  @override
  String get providerNimHint =>
      'Free models from build.nvidia.com. Lumi fills in the address.';

  @override
  String get providerOtherHint =>
      'Any other service compatible with the OpenAI API.';

  @override
  String get baseUrlLabel => 'Base URL';

  @override
  String get apiKeyLabel => 'API key';

  @override
  String get apiKeyPaste => 'Paste API key';

  @override
  String get modelLabel => 'Model';

  @override
  String get modelHelp =>
      'Write the model ID exactly as shown in the provider\'s dashboard.';

  @override
  String get modelExampleFree => 'e.g. model-name:free';

  @override
  String get modelExampleNim => 'e.g. vendor/model-name';

  @override
  String get modelExampleOther => 'Model ID from the provider';

  @override
  String get testAndSave => 'Test and save';

  @override
  String get replaceKey => 'Replace key';

  @override
  String get replaceKeyNote => 'Fill in the form to replace the saved key.';

  @override
  String get testingKey => 'Testing key…';

  @override
  String get keyWorks => 'Key works. Lumi now uses your key.';

  @override
  String get keyStillWorks => 'Key still works.';

  @override
  String get testAgain => 'Test again';

  @override
  String get removeKey => 'Remove key';

  @override
  String get removeKeyTitle => 'Remove this key?';

  @override
  String removeKeyBody(int limit) {
    return 'Lumi goes back to Lumi\'s key with a quota of $limit messages a day.';
  }

  @override
  String get keyRemoved => 'Key removed';

  @override
  String keyStatusOn(String when) {
    return 'On · tested $when';
  }

  @override
  String get keyStatusOff => 'Off · using Lumi\'s key';

  @override
  String keyLastError(String error) {
    return 'Last test failed: $error';
  }

  @override
  String get useThisKey => 'Use this key';

  @override
  String get devicesIntro =>
      'Your Lumi account is signed in on these devices. Sign out any you don\'t recognise and it goes straight back to the sign-in screen.';

  @override
  String get thisDevice => 'This device';

  @override
  String get activeNow => 'Active now';

  @override
  String get signOutDevice => 'Sign out';

  @override
  String signOutDeviceTitle(String name) {
    return 'Sign out $name?';
  }

  @override
  String signOutOthersTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sign out $count other devices?',
      one: 'Sign out 1 other device?',
    );
    return '$_temp0';
  }

  @override
  String get signOutDeviceBody =>
      'That device is signed out right away and needs the password to get back in.';

  @override
  String get signOutAllOthers => 'Sign out all other devices';

  @override
  String get onlyThisDevice => 'Only this device is signed in. All good.';

  @override
  String devicesSignedOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices signed out',
      one: 'Device signed out',
    );
    return '$_temp0';
  }

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get sessionEndedTitle => 'Session ended';

  @override
  String get sessionEndedBody =>
      'Your account was signed out of this device, from another device or because the password changed. Sign in again to continue.';

  @override
  String get signInAgain => 'Sign in again';

  @override
  String get quotaTitle => 'Today\'s quota is used up';

  @override
  String get quotaBody =>
      'Lumi is taking a break; the quota resets at 00:00 WIB. Use your own AI key to keep going without limits.';

  @override
  String get setUpAiKey => 'Set up AI key';

  @override
  String get catSleeping => 'Lumi the cat, asleep';

  @override
  String get agentMenu => 'Agent';

  @override
  String get agentSubtitle =>
      'Shape Lumi\'s personality, memory, notes, and tools.';

  @override
  String get agentPersona => 'Persona';

  @override
  String get agentMemory => 'Memory';

  @override
  String get agentNotes => 'Notes';

  @override
  String get agentTools => 'Tools';

  @override
  String get comingSoon => 'Soon';

  @override
  String get personaTitle => 'Persona';

  @override
  String get personaSubtitle =>
      'Choose how Lumi speaks and addresses you. Core safety rules always stay protected.';

  @override
  String get personaActiveLabel => 'Use persona';

  @override
  String get personaActiveHint =>
      'Turn off to use Lumi\'s neutral default style.';

  @override
  String get personaPresetLabel => 'Style preset';

  @override
  String get personaCallMeLabel => 'Call me';

  @override
  String get personaCallMeHint =>
      'Optional nickname (defaults to your account name)';

  @override
  String get personaInstructionsLabel => 'Custom instructions';

  @override
  String get personaInstructionsHint =>
      'e.g. Explain step by step, use simple examples, avoid slang…';

  @override
  String get personaGuardrailNote =>
      'Persona only shapes tone, nickname, and style — it never overrides Lumi\'s safety or tool permission rules.';

  @override
  String get personaSaved => 'Persona saved';

  @override
  String memorySubtitle(int limit) {
    return 'Facts Lumi remembers across chats. Up to $limit items; the latest 20 are active in context.';
  }

  @override
  String get memorySearchHint => 'Search memories';

  @override
  String get memoryAdd => 'Add memory';

  @override
  String get memoryEdit => 'Edit memory';

  @override
  String get memoryContentLabel => 'What should Lumi remember?';

  @override
  String get memoryContentHint => 'e.g. Prefers concise Laravel code examples';

  @override
  String get memoryCategoryLabel => 'Category';

  @override
  String get memoryCategoryFact => 'Fact';

  @override
  String get memoryCategoryPreference => 'Preference';

  @override
  String get memoryCategoryContext => 'Context';

  @override
  String get memorySourceLumi => 'Lumi';

  @override
  String get memorySourceYou => 'You';

  @override
  String get memoryEmptyTitle => 'No memories yet';

  @override
  String get memoryEmptyBody =>
      'Add a lasting preference or fact here, and Lumi will remember it in every chat.';

  @override
  String get memoryDeleteTitle => 'Delete this memory?';

  @override
  String get memoryDeleteBody =>
      'Lumi will forget this item across all your devices.';

  @override
  String get memorySaved => 'Memory saved';

  @override
  String get memoryDeleted => 'Memory deleted';

  @override
  String get notesSearchHint => 'Search notes';

  @override
  String get noteAdd => 'New note';

  @override
  String get noteEdit => 'Edit note';

  @override
  String get noteTitleLabel => 'Title';

  @override
  String get noteTitleHint => 'Short title for your note';

  @override
  String get noteContentLabel => 'Content';

  @override
  String get noteContentHint => 'Write anything you want to keep handy…';

  @override
  String get noteTagsLabel => 'Tags (optional)';

  @override
  String get noteTagsHint => 'Separate with commas, e.g. work, ideas';

  @override
  String get notesEmptyTitle => 'No notes yet';

  @override
  String get notesEmptyBody =>
      'Save checklists, snippets, or ideas here so both you and Lumi can find them anytime.';

  @override
  String get noteDeleteTitle => 'Delete this note?';

  @override
  String noteDeleteBody(String title) {
    return '“$title” will be permanently removed.';
  }

  @override
  String get noteSaved => 'Note saved';

  @override
  String get noteDeleted => 'Note deleted';

  @override
  String get serverButton => 'Server';

  @override
  String get serverTitle => 'Server address';

  @override
  String get serverSubtitle =>
      'Change this for network testing (e.g. Cloudflare Tunnel) or your own Lumi Core VPS.';

  @override
  String get serverUrlLabel => 'Lumi Core URL';

  @override
  String get serverBadgeDefault => 'Default';

  @override
  String get serverBadgeCustom => 'Custom';

  @override
  String get serverTestAndSave => 'Test and save';

  @override
  String get serverTesting => 'Checking server…';

  @override
  String get serverResetDefault => 'Reset to default';

  @override
  String get serverChangeLink => 'Change server address';

  @override
  String get serverUrlInvalid => 'Enter a valid http:// or https:// address.';

  @override
  String get serverCheckFailed =>
      'That address is not a healthy Lumi Core server.';

  @override
  String get serverSaved => 'Server updated';

  @override
  String get serverResetToast => 'Using default server';

  @override
  String get toolsSubtitle =>
      'Abilities Lumi can use for your account. Policies are enforced by Lumi Core.';

  @override
  String get toolsEmpty => 'No tools are currently enabled for your account.';

  @override
  String get toolModeAuto => 'Auto';

  @override
  String get toolModeAsk => 'Ask approval';

  @override
  String get aiKeySupportsTools => 'Model supports tools';

  @override
  String get actionApprovalBadge => 'Approval required';

  @override
  String get actionApprove => 'Approve';

  @override
  String get actionReject => 'Reject';

  @override
  String get actionExpiryHint =>
      'This request expires automatically in 10 minutes if not answered.';

  @override
  String actionToolMeta(String tool) {
    return 'Tool: $tool';
  }

  @override
  String get networkInspectorTitle => 'Network inspector';

  @override
  String get networkInspectorSubtitle =>
      'Inspect recent REST & SSE traffic. Tokens, passwords, and API keys are masked.';

  @override
  String get networkInspectorFloating => 'Floating button';

  @override
  String get networkInspectorFloatingHint =>
      'Show a quick HTTP badge over every screen while testing.';

  @override
  String get networkInspectorClear => 'Clear';

  @override
  String get networkInspectorCleared => 'Network logs cleared';

  @override
  String get networkInspectorEmpty => 'No requests captured yet';

  @override
  String get networkInspectorEmptyBody =>
      'API calls and chat streams will appear here automatically.';

  @override
  String get networkInspectorFilterAll => 'All';

  @override
  String get networkInspectorFilterRest => 'REST';

  @override
  String get networkInspectorFilterSse => 'SSE';

  @override
  String get networkInspectorFilterErrors => 'Errors';

  @override
  String get networkInspectorOverview => 'Overview';

  @override
  String get networkInspectorRequest => 'Request';

  @override
  String get networkInspectorResponse => 'Response';

  @override
  String get networkInspectorCopyCurl => 'Copy cURL';

  @override
  String get networkInspectorCopyBody => 'Copy body';

  @override
  String get networkInspectorHeaders => 'Headers';

  @override
  String get networkInspectorBody => 'Body';

  @override
  String get networkInspectorSseEvents => 'SSE events';

  @override
  String get networkInspectorNoBody => 'Empty body';
}
