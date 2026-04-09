import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ky.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ky'),
    Locale('ru'),
    Locale('uz'),
  ];

  /// No description provided for @appName.
  ///
  /// In ru, this message translates to:
  /// **'CRM Швейный цех'**
  String get appName;

  /// No description provided for @loading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка...'**
  String get loading;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get add;

  /// No description provided for @search.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In ru, this message translates to:
  /// **'Фильтр'**
  String get filter;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In ru, this message translates to:
  /// **'Да'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get no;

  /// No description provided for @back.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// No description provided for @next.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get next;

  /// No description provided for @submit.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get submit;

  /// No description provided for @export.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт'**
  String get export;

  /// No description provided for @noData.
  ///
  /// In ru, this message translates to:
  /// **'Данных нет'**
  String get noData;

  /// No description provided for @error.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get error;

  /// No description provided for @success.
  ///
  /// In ru, this message translates to:
  /// **'Успешно'**
  String get success;

  /// No description provided for @required.
  ///
  /// In ru, this message translates to:
  /// **'Обязательное поле'**
  String get required;

  /// No description provided for @offline.
  ///
  /// In ru, this message translates to:
  /// **'Нет подключения к сети'**
  String get offline;

  /// No description provided for @login.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get password;

  /// No description provided for @loginError.
  ///
  /// In ru, this message translates to:
  /// **'Неверный email или пароль'**
  String get loginError;

  /// No description provided for @roleDirector.
  ///
  /// In ru, this message translates to:
  /// **'Директор'**
  String get roleDirector;

  /// No description provided for @roleHeadManager.
  ///
  /// In ru, this message translates to:
  /// **'Главный менеджер'**
  String get roleHeadManager;

  /// No description provided for @roleManager.
  ///
  /// In ru, this message translates to:
  /// **'Менеджер'**
  String get roleManager;

  /// No description provided for @roleSeamstress.
  ///
  /// In ru, this message translates to:
  /// **'Швея'**
  String get roleSeamstress;

  /// No description provided for @navOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get navOrders;

  /// No description provided for @navTasks.
  ///
  /// In ru, this message translates to:
  /// **'Задачи'**
  String get navTasks;

  /// No description provided for @navClients.
  ///
  /// In ru, this message translates to:
  /// **'Клиенты'**
  String get navClients;

  /// No description provided for @navCouriers.
  ///
  /// In ru, this message translates to:
  /// **'Курьеры'**
  String get navCouriers;

  /// No description provided for @navDiary.
  ///
  /// In ru, this message translates to:
  /// **'Дневник'**
  String get navDiary;

  /// No description provided for @navAnalytics.
  ///
  /// In ru, this message translates to:
  /// **'Аналитика'**
  String get navAnalytics;

  /// No description provided for @navChat.
  ///
  /// In ru, this message translates to:
  /// **'Чат'**
  String get navChat;

  /// No description provided for @navPlan.
  ///
  /// In ru, this message translates to:
  /// **'План'**
  String get navPlan;

  /// No description provided for @ordersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get ordersTitle;

  /// No description provided for @orderNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый заказ'**
  String get orderNew;

  /// No description provided for @orderStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get orderStatus;

  /// No description provided for @orderDeadline.
  ///
  /// In ru, this message translates to:
  /// **'Срок'**
  String get orderDeadline;

  /// No description provided for @orderClient.
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get orderClient;

  /// No description provided for @orderSource.
  ///
  /// In ru, this message translates to:
  /// **'Источник'**
  String get orderSource;

  /// No description provided for @orderAssignee.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель'**
  String get orderAssignee;

  /// No description provided for @orderPrice.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость'**
  String get orderPrice;

  /// No description provided for @orderDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get orderDescription;

  /// No description provided for @statusNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый'**
  String get statusNew;

  /// No description provided for @statusAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принят в работу'**
  String get statusAccepted;

  /// No description provided for @statusSewing.
  ///
  /// In ru, this message translates to:
  /// **'В пошиве'**
  String get statusSewing;

  /// No description provided for @statusQuality.
  ///
  /// In ru, this message translates to:
  /// **'На проверке'**
  String get statusQuality;

  /// No description provided for @statusReady.
  ///
  /// In ru, this message translates to:
  /// **'Готов'**
  String get statusReady;

  /// No description provided for @statusDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Передан курьеру'**
  String get statusDelivery;

  /// No description provided for @statusClosed.
  ///
  /// In ru, this message translates to:
  /// **'Закрыт'**
  String get statusClosed;

  /// No description provided for @statusRework.
  ///
  /// In ru, this message translates to:
  /// **'Возврат/Переделка'**
  String get statusRework;

  /// No description provided for @sourceWhatsApp.
  ///
  /// In ru, this message translates to:
  /// **'WhatsApp'**
  String get sourceWhatsApp;

  /// No description provided for @sourceInstagram.
  ///
  /// In ru, this message translates to:
  /// **'Instagram'**
  String get sourceInstagram;

  /// No description provided for @sourceWebsite.
  ///
  /// In ru, this message translates to:
  /// **'Сайт'**
  String get sourceWebsite;

  /// No description provided for @sourcePersonal.
  ///
  /// In ru, this message translates to:
  /// **'Лично'**
  String get sourcePersonal;

  /// No description provided for @sourceWholesale.
  ///
  /// In ru, this message translates to:
  /// **'Оптовый'**
  String get sourceWholesale;

  /// No description provided for @tasksTitle.
  ///
  /// In ru, this message translates to:
  /// **'Задачи'**
  String get tasksTitle;

  /// No description provided for @taskNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая задача'**
  String get taskNew;

  /// No description provided for @taskAssignee.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель'**
  String get taskAssignee;

  /// No description provided for @taskDeadline.
  ///
  /// In ru, this message translates to:
  /// **'Срок'**
  String get taskDeadline;

  /// No description provided for @taskStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get taskStatus;

  /// No description provided for @taskStatusPending.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает'**
  String get taskStatusPending;

  /// No description provided for @taskStatusInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get taskStatusInProgress;

  /// No description provided for @taskStatusDone.
  ///
  /// In ru, this message translates to:
  /// **'Выполнена'**
  String get taskStatusDone;

  /// No description provided for @clientsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Клиенты'**
  String get clientsTitle;

  /// No description provided for @clientNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый клиент'**
  String get clientNew;

  /// No description provided for @clientName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get clientName;

  /// No description provided for @clientPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get clientPhone;

  /// No description provided for @clientEmail.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get clientEmail;

  /// No description provided for @clientEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать клиента'**
  String get clientEdit;

  /// No description provided for @clientHistory.
  ///
  /// In ru, this message translates to:
  /// **'История заказов'**
  String get clientHistory;

  /// No description provided for @createdAt.
  ///
  /// In ru, this message translates to:
  /// **'Создан'**
  String get createdAt;

  /// No description provided for @notes.
  ///
  /// In ru, this message translates to:
  /// **'Примечания'**
  String get notes;

  /// No description provided for @notSpecified.
  ///
  /// In ru, this message translates to:
  /// **'Не указан'**
  String get notSpecified;

  /// No description provided for @couriersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Курьеры'**
  String get couriersTitle;

  /// No description provided for @courierLog.
  ///
  /// In ru, this message translates to:
  /// **'Запись доставки'**
  String get courierLog;

  /// No description provided for @courierDirectionIn.
  ///
  /// In ru, this message translates to:
  /// **'Приём'**
  String get courierDirectionIn;

  /// No description provided for @courierDirectionOut.
  ///
  /// In ru, this message translates to:
  /// **'Отправка'**
  String get courierDirectionOut;

  /// No description provided for @courierFrom.
  ///
  /// In ru, this message translates to:
  /// **'От кого'**
  String get courierFrom;

  /// No description provided for @courierTo.
  ///
  /// In ru, this message translates to:
  /// **'Кому'**
  String get courierTo;

  /// No description provided for @courierWhat.
  ///
  /// In ru, this message translates to:
  /// **'Что'**
  String get courierWhat;

  /// No description provided for @courierDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get courierDate;

  /// No description provided for @diaryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мой дневник'**
  String get diaryTitle;

  /// No description provided for @diaryNewEntry.
  ///
  /// In ru, this message translates to:
  /// **'Новая запись'**
  String get diaryNewEntry;

  /// No description provided for @diaryDescription.
  ///
  /// In ru, this message translates to:
  /// **'Что сшила'**
  String get diaryDescription;

  /// No description provided for @diaryQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get diaryQuantity;

  /// No description provided for @diaryPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Фото'**
  String get diaryPhoto;

  /// No description provided for @diarySalary.
  ///
  /// In ru, this message translates to:
  /// **'ЗП (руб.)'**
  String get diarySalary;

  /// No description provided for @analyticsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Аналитика'**
  String get analyticsTitle;

  /// No description provided for @planTitle.
  ///
  /// In ru, this message translates to:
  /// **'План / Факт'**
  String get planTitle;

  /// No description provided for @planMonth.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get planMonth;

  /// No description provided for @planTarget.
  ///
  /// In ru, this message translates to:
  /// **'Цель (руб.)'**
  String get planTarget;

  /// No description provided for @planFact.
  ///
  /// In ru, this message translates to:
  /// **'Факт (руб.)'**
  String get planFact;

  /// No description provided for @planAhead.
  ///
  /// In ru, this message translates to:
  /// **'Опережаем'**
  String get planAhead;

  /// No description provided for @planBehind.
  ///
  /// In ru, this message translates to:
  /// **'Отстаём'**
  String get planBehind;

  /// No description provided for @planOnTrack.
  ///
  /// In ru, this message translates to:
  /// **'По плану'**
  String get planOnTrack;

  /// No description provided for @chatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Чат'**
  String get chatTitle;

  /// No description provided for @chatInputHint.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение...'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get chatSend;

  /// No description provided for @notifOrderReady.
  ///
  /// In ru, this message translates to:
  /// **'Заказ готов'**
  String get notifOrderReady;

  /// No description provided for @notifOrderReadyBody.
  ///
  /// In ru, this message translates to:
  /// **'Заказ #{id} готов. Не забудьте оформить документы.'**
  String notifOrderReadyBody(Object id);

  /// No description provided for @notifDeadlineSoon.
  ///
  /// In ru, this message translates to:
  /// **'Срок заказа истекает'**
  String get notifDeadlineSoon;

  /// No description provided for @notifDeadlineSoonBody.
  ///
  /// In ru, this message translates to:
  /// **'Заказ #{id} нужно сдать завтра.'**
  String notifDeadlineSoonBody(Object id);

  /// No description provided for @notifAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Вам назначен заказ'**
  String get notifAssigned;

  /// No description provided for @currency.
  ///
  /// In ru, this message translates to:
  /// **'₽'**
  String get currency;

  /// No description provided for @dateFormat.
  ///
  /// In ru, this message translates to:
  /// **'dd.MM.yyyy'**
  String get dateFormat;

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @langRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get langRu;

  /// No description provided for @langUz.
  ///
  /// In ru, this message translates to:
  /// **'O\'zbek'**
  String get langUz;

  /// No description provided for @langKy.
  ///
  /// In ru, this message translates to:
  /// **'Кыргызча'**
  String get langKy;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @settingsTheme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системная'**
  String get settingsThemeSystem;

  String get all;
  String get onlyMine;
  String get taskTitle;
  String get diaryApproved;
  String get diaryPending;
  String get diaryApproveSalary;
  String get notifTitle;
  String get notifMarkAllRead;
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
      <String>['ky', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ky':
      return AppLocalizationsKy();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
