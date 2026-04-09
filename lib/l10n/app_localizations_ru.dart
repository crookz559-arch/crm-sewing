// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'CRM Швейный цех';

  @override
  String get loading => 'Загрузка...';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Редактировать';

  @override
  String get add => 'Добавить';

  @override
  String get search => 'Поиск';

  @override
  String get filter => 'Фильтр';

  @override
  String get close => 'Закрыть';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get back => 'Назад';

  @override
  String get next => 'Далее';

  @override
  String get submit => 'Отправить';

  @override
  String get export => 'Экспорт';

  @override
  String get noData => 'Данных нет';

  @override
  String get error => 'Ошибка';

  @override
  String get success => 'Успешно';

  @override
  String get required => 'Обязательное поле';

  @override
  String get offline => 'Нет подключения к сети';

  @override
  String get login => 'Войти';

  @override
  String get logout => 'Выйти';

  @override
  String get email => 'Email';

  @override
  String get password => 'Пароль';

  @override
  String get loginError => 'Неверный email или пароль';

  @override
  String get roleDirector => 'Директор';

  @override
  String get roleHeadManager => 'Главный менеджер';

  @override
  String get roleManager => 'Менеджер';

  @override
  String get roleSeamstress => 'Швея';

  @override
  String get navOrders => 'Заказы';

  @override
  String get navTasks => 'Задачи';

  @override
  String get navClients => 'Клиенты';

  @override
  String get navCouriers => 'Курьеры';

  @override
  String get navDiary => 'Дневник';

  @override
  String get navAnalytics => 'Аналитика';

  @override
  String get navChat => 'Чат';

  @override
  String get navPlan => 'План';

  @override
  String get ordersTitle => 'Заказы';

  @override
  String get orderNew => 'Новый заказ';

  @override
  String get orderStatus => 'Статус';

  @override
  String get orderDeadline => 'Срок';

  @override
  String get orderClient => 'Клиент';

  @override
  String get orderSource => 'Источник';

  @override
  String get orderAssignee => 'Исполнитель';

  @override
  String get orderPrice => 'Стоимость';

  @override
  String get orderDescription => 'Описание';

  @override
  String get statusNew => 'Новый';

  @override
  String get statusAccepted => 'Принят в работу';

  @override
  String get statusSewing => 'В пошиве';

  @override
  String get statusQuality => 'На проверке';

  @override
  String get statusReady => 'Готов';

  @override
  String get statusDelivery => 'Передан курьеру';

  @override
  String get statusClosed => 'Закрыт';

  @override
  String get statusRework => 'Возврат/Переделка';

  @override
  String get sourceWhatsApp => 'WhatsApp';

  @override
  String get sourceInstagram => 'Instagram';

  @override
  String get sourceWebsite => 'Сайт';

  @override
  String get sourcePersonal => 'Лично';

  @override
  String get sourceWholesale => 'Оптовый';

  @override
  String get tasksTitle => 'Задачи';

  @override
  String get taskNew => 'Новая задача';

  @override
  String get taskAssignee => 'Исполнитель';

  @override
  String get taskDeadline => 'Срок';

  @override
  String get taskStatus => 'Статус';

  @override
  String get taskStatusPending => 'Ожидает';

  @override
  String get taskStatusInProgress => 'В работе';

  @override
  String get taskStatusDone => 'Выполнена';

  @override
  String get clientsTitle => 'Клиенты';

  @override
  String get clientNew => 'Новый клиент';

  @override
  String get clientName => 'Имя';

  @override
  String get clientPhone => 'Телефон';

  @override
  String get clientEmail => 'Email';

  @override
  String get clientEdit => 'Редактировать клиента';

  @override
  String get clientHistory => 'История заказов';

  @override
  String get createdAt => 'Создан';

  @override
  String get notes => 'Примечания';

  @override
  String get notSpecified => 'Не указан';

  @override
  String get couriersTitle => 'Курьеры';

  @override
  String get courierLog => 'Запись доставки';

  @override
  String get courierDirectionIn => 'Приём';

  @override
  String get courierDirectionOut => 'Отправка';

  @override
  String get courierFrom => 'От кого';

  @override
  String get courierTo => 'Кому';

  @override
  String get courierWhat => 'Что';

  @override
  String get courierDate => 'Дата';

  @override
  String get diaryTitle => 'Мой дневник';

  @override
  String get diaryNewEntry => 'Новая запись';

  @override
  String get diaryDescription => 'Что сшила';

  @override
  String get diaryQuantity => 'Количество';

  @override
  String get diaryPhoto => 'Фото';

  @override
  String get diarySalary => 'ЗП (руб.)';

  @override
  String get analyticsTitle => 'Аналитика';

  @override
  String get planTitle => 'План / Факт';

  @override
  String get planMonth => 'Месяц';

  @override
  String get planTarget => 'Цель (руб.)';

  @override
  String get planFact => 'Факт (руб.)';

  @override
  String get planAhead => 'Опережаем';

  @override
  String get planBehind => 'Отстаём';

  @override
  String get planOnTrack => 'По плану';

  @override
  String get chatTitle => 'Чат';

  @override
  String get chatInputHint => 'Сообщение...';

  @override
  String get chatSend => 'Отправить';

  @override
  String get notifOrderReady => 'Заказ готов';

  @override
  String notifOrderReadyBody(Object id) {
    return 'Заказ #$id готов. Не забудьте оформить документы.';
  }

  @override
  String get notifDeadlineSoon => 'Срок заказа истекает';

  @override
  String notifDeadlineSoonBody(Object id) {
    return 'Заказ #$id нужно сдать завтра.';
  }

  @override
  String get notifAssigned => 'Вам назначен заказ';

  @override
  String get currency => '₽';

  @override
  String get dateFormat => 'dd.MM.yyyy';

  @override
  String get language => 'Язык';

  @override
  String get langRu => 'Русский';

  @override
  String get langUz => 'O\'zbek';

  @override
  String get langKy => 'Кыргызча';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsThemeSystem => 'Системная';

  @override
  String get all => 'Все';

  @override
  String get onlyMine => 'Мои';

  @override
  String get taskTitle => 'Название';

  @override
  String get diaryApproved => 'Утверждено';

  @override
  String get diaryPending => 'Ожидает';

  @override
  String get diaryApproveSalary => 'Утвердить ЗП';
}
