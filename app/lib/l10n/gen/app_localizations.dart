import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Light up your day.'**
  String get appTagline;

  /// No description provided for @appVersionLine.
  ///
  /// In en, this message translates to:
  /// **'Lumi {version} · Light up your day.'**
  String appVersionLine(String version);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @splashSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip to Lumi'**
  String get splashSkip;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach Lumi. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorUnknown;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorAccountBlocked.
  ///
  /// In en, this message translates to:
  /// **'Your account is blocked. Contact the Lumi admin.'**
  String get errorAccountBlocked;

  /// No description provided for @errorRegistrationClosed.
  ///
  /// In en, this message translates to:
  /// **'Sign-ups are closed right now. Try again later.'**
  String get errorRegistrationClosed;

  /// No description provided for @errorCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Ask for a new one.'**
  String get errorCodeExpired;

  /// No description provided for @errorCodeAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Ask for a new code.'**
  String get errorCodeAttempts;

  /// No description provided for @errorCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Ask for a new one.'**
  String get errorCodeInvalid;

  /// No description provided for @errorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Try again in a moment.'**
  String get errorTooManyRequests;

  /// No description provided for @errorNoModel.
  ///
  /// In en, this message translates to:
  /// **'Lumi\'s AI isn\'t set up yet. Try again later.'**
  String get errorNoModel;

  /// No description provided for @loginGreeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get loginGreeting;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep chatting with Lumi.'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@email.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHint;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'No account yet?'**
  String get noAccount;

  /// No description provided for @signUpFree.
  ///
  /// In en, this message translates to:
  /// **'Sign up free'**
  String get signUpFree;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Fill this in first.'**
  String get fieldRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like an email address.'**
  String get emailInvalid;

  /// No description provided for @catWaving.
  ///
  /// In en, this message translates to:
  /// **'Lumi the cat, waving'**
  String get catWaving;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your Lumi account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'It\'s free. We\'ll email you a code to make sure the address is yours.'**
  String get registerSubtitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nameLabel;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'So Lumi knows what to call you'**
  String get nameHint;

  /// No description provided for @pwStrengthEmpty.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get pwStrengthEmpty;

  /// No description provided for @pwStrengthShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more character to go} other{{count} more characters to go}}'**
  String pwStrengthShort(int count);

  /// No description provided for @pwStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Okay. Add numbers to make it stronger.'**
  String get pwStrengthWeak;

  /// No description provided for @pwStrengthGood.
  ///
  /// In en, this message translates to:
  /// **'Good, almost there.'**
  String get pwStrengthGood;

  /// No description provided for @pwStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong. Nice!'**
  String get pwStrengthStrong;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get passwordTooShort;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Sign up and send code'**
  String get registerButton;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccount;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get verifyTitle;

  /// No description provided for @verifyBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}. It works for 15 minutes.'**
  String verifyBody(String email);

  /// No description provided for @verifyCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit verification code'**
  String get verifyCodeLabel;

  /// No description provided for @verifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {time}'**
  String resendIn(String time);

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @codeResent.
  ///
  /// In en, this message translates to:
  /// **'New code sent'**
  String get codeResent;

  /// No description provided for @checkSpam.
  ///
  /// In en, this message translates to:
  /// **'Not in your inbox? Check spam or promotions.'**
  String get checkSpam;

  /// No description provided for @wrongCodeLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Wrong code. 1 attempt left.} other{Wrong code. {count} attempts left.}}'**
  String wrongCodeLeft(int count);

  /// No description provided for @verifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get verifiedTitle;

  /// No description provided for @verifiedBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready. Lumi is waiting.'**
  String get verifiedBody;

  /// No description provided for @startChatting.
  ///
  /// In en, this message translates to:
  /// **'Start chatting'**
  String get startChatting;

  /// No description provided for @useAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'Use another account'**
  String get useAnotherAccount;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotTitle;

  /// No description provided for @forgotBody.
  ///
  /// In en, this message translates to:
  /// **'No worries. Enter your account email and we\'ll send a code to set a new password.'**
  String get forgotBody;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get resetTitle;

  /// No description provided for @resetBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your email, then your new password. Every device will be signed out after this.'**
  String get resetBody;

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get codeLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @repeatPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat new password'**
  String get repeatPasswordLabel;

  /// No description provided for @repeatPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Type it once more'**
  String get repeatPasswordHint;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords don\'t match.'**
  String get passwordsDontMatch;

  /// No description provided for @savePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get savePassword;

  /// No description provided for @passwordChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChangedTitle;

  /// No description provided for @passwordChangedBody.
  ///
  /// In en, this message translates to:
  /// **'For your safety, every device has been signed out. Sign in again with your new password.'**
  String get passwordChangedBody;

  /// No description provided for @goToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Go to sign in'**
  String get goToSignIn;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'{step}/{total}'**
  String stepOf(int step, int total);

  /// No description provided for @newChatTitle.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChatTitle;

  /// No description provided for @quotaLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No messages left today} =1{1 message left today} other{{count} messages left today}}'**
  String quotaLeft(int count);

  /// No description provided for @usingOwnKey.
  ///
  /// In en, this message translates to:
  /// **'Using your own AI key'**
  String get usingOwnKey;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Ask Lumi anything…'**
  String get messageHint;

  /// No description provided for @messageFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Message to Lumi'**
  String get messageFieldLabel;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @stopAnswer.
  ///
  /// In en, this message translates to:
  /// **'Stop answer'**
  String get stopAnswer;

  /// No description provided for @stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// No description provided for @answerFailed.
  ///
  /// In en, this message translates to:
  /// **'Lumi couldn\'t answer.'**
  String get answerFailed;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'Lumi is typing'**
  String get typing;

  /// No description provided for @openHistory.
  ///
  /// In en, this message translates to:
  /// **'Chat history'**
  String get openHistory;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get openSettings;

  /// No description provided for @emptyChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}! What can I help with?'**
  String emptyChatTitle(String name);

  /// No description provided for @emptyChatBody.
  ///
  /// In en, this message translates to:
  /// **'Ask anything: plans, recipes, emails, or learning something new.'**
  String get emptyChatBody;

  /// No description provided for @suggestionTrip.
  ///
  /// In en, this message translates to:
  /// **'Plan a 3-day trip'**
  String get suggestionTrip;

  /// No description provided for @suggestionEmail.
  ///
  /// In en, this message translates to:
  /// **'Write a polite email'**
  String get suggestionEmail;

  /// No description provided for @suggestionExplain.
  ///
  /// In en, this message translates to:
  /// **'Explain something simply'**
  String get suggestionExplain;

  /// No description provided for @suggestionTripPrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me plan a relaxed 3-day trip.'**
  String get suggestionTripPrompt;

  /// No description provided for @suggestionEmailPrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me write a polite email asking for a day off.'**
  String get suggestionEmailPrompt;

  /// No description provided for @suggestionExplainPrompt.
  ///
  /// In en, this message translates to:
  /// **'Explain how the internet works, simply.'**
  String get suggestionExplainPrompt;

  /// No description provided for @chatGone.
  ///
  /// In en, this message translates to:
  /// **'This chat was deleted on another device.'**
  String get chatGone;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyCode;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @newChatShort.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newChatShort;

  /// No description provided for @searchChats.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get searchChats;

  /// No description provided for @groupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get groupToday;

  /// No description provided for @groupYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get groupYesterday;

  /// No description provided for @groupLast7.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get groupLast7;

  /// No description provided for @groupOlder.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get groupOlder;

  /// No description provided for @noResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get noResultsTitle;

  /// No description provided for @noResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try other words from the title or the chat.'**
  String get noResultsBody;

  /// No description provided for @noChatsTitle.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsTitle;

  /// No description provided for @noChatsBody.
  ///
  /// In en, this message translates to:
  /// **'Start one and it will show up here, on every device.'**
  String get noChatsBody;

  /// No description provided for @deleteChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this chat?'**
  String get deleteChatTitle;

  /// No description provided for @deleteChatBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will disappear from all your devices and can\'t be brought back.'**
  String deleteChatBody(String title);

  /// No description provided for @deleteChatA11y.
  ///
  /// In en, this message translates to:
  /// **'Delete {title}'**
  String deleteChatA11y(String title);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @chatDeleted.
  ///
  /// In en, this message translates to:
  /// **'Chat deleted'**
  String get chatDeleted;

  /// No description provided for @newFromOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'New from another device'**
  String get newFromOtherDevice;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @quotaUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} messages used'**
  String quotaUsed(int used, int limit);

  /// No description provided for @quotaNote.
  ///
  /// In en, this message translates to:
  /// **'Daily quota on Lumi\'s key. Resets at 00:00 WIB. Use your own key for no limit.'**
  String get quotaNote;

  /// No description provided for @ownKeyNote.
  ///
  /// In en, this message translates to:
  /// **'Your own AI key is on, so there is no daily limit.'**
  String get ownKeyNote;

  /// No description provided for @myAiKey.
  ///
  /// In en, this message translates to:
  /// **'My AI key'**
  String get myAiKey;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @statusOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get statusOn;

  /// No description provided for @statusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get statusOff;

  /// No description provided for @activeDevices.
  ///
  /// In en, this message translates to:
  /// **'Active devices'**
  String get activeDevices;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageFollowPhone.
  ///
  /// In en, this message translates to:
  /// **'Follow phone'**
  String get languageFollowPhone;

  /// No description provided for @languageNote.
  ///
  /// In en, this message translates to:
  /// **'Lumi\'s emails and messages follow this language too.'**
  String get languageNote;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of Lumi?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your chats stay safe in your account. Sign in again anytime.'**
  String get signOutBody;

  /// No description provided for @changePasswordNote.
  ///
  /// In en, this message translates to:
  /// **'Other devices will be signed out. This phone stays signed in.'**
  String get changePasswordNote;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @passwordChangedToast.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChangedToast;

  /// No description provided for @aiKeyIntro.
  ///
  /// In en, this message translates to:
  /// **'Use your own API key so chats aren\'t limited by the daily quota. The key is stored encrypted on the server and never shown again.'**
  String get aiKeyIntro;

  /// No description provided for @providerLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get providerLabel;

  /// No description provided for @providerOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get providerOther;

  /// No description provided for @providerOpenRouterHint.
  ///
  /// In en, this message translates to:
  /// **'Lots of free models labelled :free. Get a key at openrouter.ai.'**
  String get providerOpenRouterHint;

  /// No description provided for @providerNimHint.
  ///
  /// In en, this message translates to:
  /// **'Free models from build.nvidia.com. Lumi fills in the address.'**
  String get providerNimHint;

  /// No description provided for @providerOtherHint.
  ///
  /// In en, this message translates to:
  /// **'Any other service compatible with the OpenAI API.'**
  String get providerOtherHint;

  /// No description provided for @baseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrlLabel;

  /// No description provided for @apiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKeyLabel;

  /// No description provided for @apiKeyPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste API key'**
  String get apiKeyPaste;

  /// No description provided for @modelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelLabel;

  /// No description provided for @modelHelp.
  ///
  /// In en, this message translates to:
  /// **'Write the model ID exactly as shown in the provider\'s dashboard.'**
  String get modelHelp;

  /// No description provided for @modelExampleFree.
  ///
  /// In en, this message translates to:
  /// **'e.g. model-name:free'**
  String get modelExampleFree;

  /// No description provided for @modelExampleNim.
  ///
  /// In en, this message translates to:
  /// **'e.g. vendor/model-name'**
  String get modelExampleNim;

  /// No description provided for @modelExampleOther.
  ///
  /// In en, this message translates to:
  /// **'Model ID from the provider'**
  String get modelExampleOther;

  /// No description provided for @testAndSave.
  ///
  /// In en, this message translates to:
  /// **'Test and save'**
  String get testAndSave;

  /// No description provided for @replaceKey.
  ///
  /// In en, this message translates to:
  /// **'Replace key'**
  String get replaceKey;

  /// No description provided for @replaceKeyNote.
  ///
  /// In en, this message translates to:
  /// **'Fill in the form to replace the saved key.'**
  String get replaceKeyNote;

  /// No description provided for @testingKey.
  ///
  /// In en, this message translates to:
  /// **'Testing key…'**
  String get testingKey;

  /// No description provided for @keyWorks.
  ///
  /// In en, this message translates to:
  /// **'Key works. Lumi now uses your key.'**
  String get keyWorks;

  /// No description provided for @keyStillWorks.
  ///
  /// In en, this message translates to:
  /// **'Key still works.'**
  String get keyStillWorks;

  /// No description provided for @testAgain.
  ///
  /// In en, this message translates to:
  /// **'Test again'**
  String get testAgain;

  /// No description provided for @removeKey.
  ///
  /// In en, this message translates to:
  /// **'Remove key'**
  String get removeKey;

  /// No description provided for @removeKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this key?'**
  String get removeKeyTitle;

  /// No description provided for @removeKeyBody.
  ///
  /// In en, this message translates to:
  /// **'Lumi goes back to Lumi\'s key with a quota of {limit} messages a day.'**
  String removeKeyBody(int limit);

  /// No description provided for @keyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Key removed'**
  String get keyRemoved;

  /// No description provided for @keyStatusOn.
  ///
  /// In en, this message translates to:
  /// **'On · tested {when}'**
  String keyStatusOn(String when);

  /// No description provided for @keyStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Off · using Lumi\'s key'**
  String get keyStatusOff;

  /// No description provided for @keyLastError.
  ///
  /// In en, this message translates to:
  /// **'Last test failed: {error}'**
  String keyLastError(String error);

  /// No description provided for @useThisKey.
  ///
  /// In en, this message translates to:
  /// **'Use this key'**
  String get useThisKey;

  /// No description provided for @devicesIntro.
  ///
  /// In en, this message translates to:
  /// **'Your Lumi account is signed in on these devices. Sign out any you don\'t recognise and it goes straight back to the sign-in screen.'**
  String get devicesIntro;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @activeNow.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get activeNow;

  /// No description provided for @signOutDevice.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutDevice;

  /// No description provided for @signOutDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out {name}?'**
  String signOutDeviceTitle(String name);

  /// No description provided for @signOutOthersTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Sign out 1 other device?} other{Sign out {count} other devices?}}'**
  String signOutOthersTitle(int count);

  /// No description provided for @signOutDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'That device is signed out right away and needs the password to get back in.'**
  String get signOutDeviceBody;

  /// No description provided for @signOutAllOthers.
  ///
  /// In en, this message translates to:
  /// **'Sign out all other devices'**
  String get signOutAllOthers;

  /// No description provided for @onlyThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Only this device is signed in. All good.'**
  String get onlyThisDevice;

  /// No description provided for @devicesSignedOut.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Device signed out} other{{count} devices signed out}}'**
  String devicesSignedOut(int count);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String timeDaysAgo(int count);

  /// No description provided for @sessionEndedTitle.
  ///
  /// In en, this message translates to:
  /// **'Session ended'**
  String get sessionEndedTitle;

  /// No description provided for @sessionEndedBody.
  ///
  /// In en, this message translates to:
  /// **'Your account was signed out of this device, from another device or because the password changed. Sign in again to continue.'**
  String get sessionEndedBody;

  /// No description provided for @signInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get signInAgain;

  /// No description provided for @quotaTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s quota is used up'**
  String get quotaTitle;

  /// No description provided for @quotaBody.
  ///
  /// In en, this message translates to:
  /// **'Lumi is taking a break; the quota resets at 00:00 WIB. Use your own AI key to keep going without limits.'**
  String get quotaBody;

  /// No description provided for @setUpAiKey.
  ///
  /// In en, this message translates to:
  /// **'Set up AI key'**
  String get setUpAiKey;

  /// No description provided for @catSleeping.
  ///
  /// In en, this message translates to:
  /// **'Lumi the cat, asleep'**
  String get catSleeping;

  /// No description provided for @agentMenu.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agentMenu;

  /// No description provided for @agentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shape Lumi\'s personality, memory, notes, and tools.'**
  String get agentSubtitle;

  /// No description provided for @agentPersona.
  ///
  /// In en, this message translates to:
  /// **'Persona'**
  String get agentPersona;

  /// No description provided for @agentMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get agentMemory;

  /// No description provided for @agentNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get agentNotes;

  /// No description provided for @agentTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get agentTools;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get comingSoon;

  /// No description provided for @personaTitle.
  ///
  /// In en, this message translates to:
  /// **'Persona'**
  String get personaTitle;

  /// No description provided for @personaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how Lumi speaks and addresses you. Core safety rules always stay protected.'**
  String get personaSubtitle;

  /// No description provided for @personaActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Use persona'**
  String get personaActiveLabel;

  /// No description provided for @personaActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off to use Lumi\'s neutral default style.'**
  String get personaActiveHint;

  /// No description provided for @personaPresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Style preset'**
  String get personaPresetLabel;

  /// No description provided for @personaCallMeLabel.
  ///
  /// In en, this message translates to:
  /// **'Call me'**
  String get personaCallMeLabel;

  /// No description provided for @personaCallMeHint.
  ///
  /// In en, this message translates to:
  /// **'Optional nickname (defaults to your account name)'**
  String get personaCallMeHint;

  /// No description provided for @personaInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom instructions'**
  String get personaInstructionsLabel;

  /// No description provided for @personaInstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Explain step by step, use simple examples, avoid slang…'**
  String get personaInstructionsHint;

  /// No description provided for @personaGuardrailNote.
  ///
  /// In en, this message translates to:
  /// **'Persona only shapes tone, nickname, and style — it never overrides Lumi\'s safety or tool permission rules.'**
  String get personaGuardrailNote;

  /// No description provided for @personaSaved.
  ///
  /// In en, this message translates to:
  /// **'Persona saved'**
  String get personaSaved;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
