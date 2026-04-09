// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appName => 'CRM Tikuvchilik';

  @override
  String get loading => 'Yuklanmoqda...';

  @override
  String get save => 'Saqlash';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get delete => 'O\'chirish';

  @override
  String get edit => 'Tahrirlash';

  @override
  String get add => 'Qo\'shish';

  @override
  String get search => 'Qidirish';

  @override
  String get filter => 'Filtr';

  @override
  String get close => 'Yopish';

  @override
  String get confirm => 'Tasdiqlash';

  @override
  String get yes => 'Ha';

  @override
  String get no => 'Yo\'q';

  @override
  String get back => 'Orqaga';

  @override
  String get next => 'Keyingi';

  @override
  String get submit => 'Yuborish';

  @override
  String get export => 'Eksport';

  @override
  String get noData => 'Ma\'lumot yo\'q';

  @override
  String get error => 'Xato';

  @override
  String get success => 'Muvaffaqiyatli';

  @override
  String get required => 'Majburiy maydon';

  @override
  String get offline => 'Internet aloqasi yo\'q';

  @override
  String get login => 'Kirish';

  @override
  String get logout => 'Chiqish';

  @override
  String get email => 'Email';

  @override
  String get password => 'Parol';

  @override
  String get loginError => 'Noto\'g\'ri email yoki parol';

  @override
  String get roleDirector => 'Direktor';

  @override
  String get roleHeadManager => 'Bosh menejer';

  @override
  String get roleManager => 'Menejer';

  @override
  String get roleSeamstress => 'Tikuvchi';

  @override
  String get navOrders => 'Buyurtmalar';

  @override
  String get navTasks => 'Vazifalar';

  @override
  String get navClients => 'Mijozlar';

  @override
  String get navCouriers => 'Kurierlar';

  @override
  String get navDiary => 'Kundalik';

  @override
  String get navAnalytics => 'Tahlil';

  @override
  String get navChat => 'Chat';

  @override
  String get navPlan => 'Reja';

  @override
  String get ordersTitle => 'Buyurtmalar';

  @override
  String get orderNew => 'Yangi buyurtma';

  @override
  String get orderStatus => 'Holat';

  @override
  String get orderDeadline => 'Muddat';

  @override
  String get orderClient => 'Mijoz';

  @override
  String get orderSource => 'Manba';

  @override
  String get orderAssignee => 'Ijrochi';

  @override
  String get orderPrice => 'Narxi';

  @override
  String get orderDescription => 'Tavsif';

  @override
  String get statusNew => 'Yangi';

  @override
  String get statusAccepted => 'Ishga qabul qilindi';

  @override
  String get statusSewing => 'Tikuvda';

  @override
  String get statusQuality => 'Tekshiruvda';

  @override
  String get statusReady => 'Tayyor';

  @override
  String get statusDelivery => 'Kurierga topshirildi';

  @override
  String get statusClosed => 'Yopildi';

  @override
  String get statusRework => 'Qaytarildi/Qayta ishlash';

  @override
  String get sourceWhatsApp => 'WhatsApp';

  @override
  String get sourceInstagram => 'Instagram';

  @override
  String get sourceWebsite => 'Sayt';

  @override
  String get sourcePersonal => 'Shaxsan';

  @override
  String get sourceWholesale => 'Ulgurji';

  @override
  String get tasksTitle => 'Vazifalar';

  @override
  String get taskNew => 'Yangi vazifa';

  @override
  String get taskAssignee => 'Ijrochi';

  @override
  String get taskDeadline => 'Muddat';

  @override
  String get taskStatus => 'Holat';

  @override
  String get taskStatusPending => 'Kutilmoqda';

  @override
  String get taskStatusInProgress => 'Jarayonda';

  @override
  String get taskStatusDone => 'Bajarildi';

  @override
  String get clientsTitle => 'Mijozlar';

  @override
  String get clientNew => 'Yangi mijoz';

  @override
  String get clientName => 'Ism';

  @override
  String get clientPhone => 'Telefon';

  @override
  String get clientEmail => 'Email';

  @override
  String get clientEdit => 'Mijozni tahrirlash';

  @override
  String get clientHistory => 'Buyurtmalar tarixi';

  @override
  String get createdAt => 'Yaratilgan';

  @override
  String get notes => 'Izohlar';

  @override
  String get notSpecified => "Ko'rsatilmagan";

  @override
  String get couriersTitle => 'Kurierlar';

  @override
  String get courierLog => 'Yetkazib berish yozuvi';

  @override
  String get courierDirectionIn => 'Qabul qilish';

  @override
  String get courierDirectionOut => 'Yuborish';

  @override
  String get courierFrom => 'Kimdan';

  @override
  String get courierTo => 'Kimga';

  @override
  String get courierWhat => 'Nima';

  @override
  String get courierDate => 'Sana';

  @override
  String get diaryTitle => 'Mening kundaligim';

  @override
  String get diaryNewEntry => 'Yangi yozuv';

  @override
  String get diaryDescription => 'Nima tikdi';

  @override
  String get diaryQuantity => 'Miqdori';

  @override
  String get diaryPhoto => 'Rasm';

  @override
  String get diarySalary => 'Maosh (rubl)';

  @override
  String get analyticsTitle => 'Tahlil';

  @override
  String get planTitle => 'Reja / Fakt';

  @override
  String get planMonth => 'Oy';

  @override
  String get planTarget => 'Maqsad (rubl)';

  @override
  String get planFact => 'Fakt (rubl)';

  @override
  String get planAhead => 'Oldinda';

  @override
  String get planBehind => 'Orqada';

  @override
  String get planOnTrack => 'Rejaga muvofiq';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatInputHint => 'Xabar...';

  @override
  String get chatSend => 'Yuborish';

  @override
  String get notifOrderReady => 'Buyurtma tayyor';

  @override
  String notifOrderReadyBody(Object id) {
    return '#$id buyurtma tayyor. Hujjatlarni rasmiylashtiring.';
  }

  @override
  String get notifDeadlineSoon => 'Buyurtma muddati tugaydi';

  @override
  String notifDeadlineSoonBody(Object id) {
    return '#$id buyurtma ertaga topshirilishi kerak.';
  }

  @override
  String get notifAssigned => 'Sizga buyurtma biriktirildi';

  @override
  String get currency => '₽';

  @override
  String get dateFormat => 'dd.MM.yyyy';

  @override
  String get language => 'Til';

  @override
  String get langRu => 'Русский';

  @override
  String get langUz => 'O\'zbek';

  @override
  String get langKy => 'Кыргызча';

  @override
  String get settingsTitle => 'Sozlamalar';

  @override
  String get settingsTheme => 'Mavzu';

  @override
  String get settingsThemeLight => 'Yorug\'';

  @override
  String get settingsThemeDark => 'Qorong\'u';

  @override
  String get settingsThemeSystem => 'Tizim';

  @override
  String get all => 'Barchasi';

  @override
  String get onlyMine => 'Mening';

  @override
  String get taskTitle => 'Sarlavha';

  @override
  String get diaryApproved => 'Tasdiqlangan';

  @override
  String get diaryPending => 'Kutilmoqda';

  @override
  String get diaryApproveSalary => 'Maoshni tasdiqlash';

  @override
  String get notifTitle => 'Bildirishnomalar';

  @override
  String get notifMarkAllRead => "Hammasini o'qilgan deb belgilash";
}
