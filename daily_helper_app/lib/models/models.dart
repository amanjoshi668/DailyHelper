enum UserRole { customer, professional }

UserRole parseUserRole(String? raw) {
  if (raw == 'professional' || raw == 'worker') {
    return UserRole.professional;
  }
  return UserRole.customer;
}

String userRoleToString(UserRole role) =>
    role == UserRole.professional ? 'professional' : 'customer';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final bool isGuest;
  final String trade;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = UserRole.customer,
    this.isGuest = false,
    this.trade = 'electrician',
  });

  factory AppUser.visitor() => const AppUser(
        id: 'local_guest_vault',
        name: 'Visitor',
        email: '',
        role: UserRole.customer,
        isGuest: true,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': userRoleToString(role),
        'isGuest': isGuest,
        'trade': trade,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: (map['id'] ?? 'local_guest_vault').toString(),
        name: (map['name'] ?? 'User').toString(),
        email: (map['email'] ?? '').toString(),
        phone: (map['phone'] ?? '').toString(),
        role: parseUserRole(map['role']?.toString()),
        isGuest: map['isGuest'] == true,
        trade: (map['trade'] ?? 'electrician').toString(),
      );
}

class ServiceRateItem {
  final String service;
  final int priceInr;

  const ServiceRateItem({
    required this.service,
    required this.priceInr,
  });

  Map<String, dynamic> toMap() => {
        'service': service,
        'priceInr': priceInr,
      };

  factory ServiceRateItem.fromMap(Map<String, dynamic> map) => ServiceRateItem(
        service: (map['service'] ?? '').toString(),
        priceInr: (map['priceInr'] ?? map['price_inr'] as num?)?.toInt() ?? 0,
      );
}

class WorkerProfile {
  final String id;
  final String nameEn;
  final String nameHi;
  final String trade;
  final List<String> skillsEn;
  final List<String> skillsHi;
  final List<String> servicePins;
  final int experienceYears;
  final int visitFeeInr;
  final int hourlyRateInr;
  final int dailyRateInr;
  final List<ServiceRateItem> customRates;
  final String upiId;
  final String phone;
  final String languages;
  final bool verified;
  final bool isOnline;
  final List<String> blockedSlots;
  final double ratingAvg;
  final int jobsCompleted;
  final int khataTodayInr;
  final int khataMonthInr;

  const WorkerProfile({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.trade,
    required this.skillsEn,
    required this.skillsHi,
    required this.servicePins,
    required this.experienceYears,
    required this.visitFeeInr,
    required this.hourlyRateInr,
    this.dailyRateInr = 900,
    this.customRates = const [],
    required this.upiId,
    required this.phone,
    required this.languages,
    this.verified = true,
    this.isOnline = true,
    this.blockedSlots = const [],
    this.ratingAvg = 4.8,
    this.jobsCompleted = 0,
    this.khataTodayInr = 0,
    this.khataMonthInr = 0,
  });

  String get initials {
    final parts = nameEn.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String localizedName(String lang) =>
      ((lang == 'hi' || lang == 'mr') && nameHi.isNotEmpty) ? nameHi : nameEn;

  List<String> localizedSkills(String lang) =>
      ((lang == 'hi' || lang == 'mr') && skillsHi.isNotEmpty) ? skillsHi : skillsEn;

  WorkerProfile copyWith({
    int? visitFeeInr,
    int? hourlyRateInr,
    int? dailyRateInr,
    List<ServiceRateItem>? customRates,
    String? upiId,
    List<String>? servicePins,
    bool? isOnline,
    List<String>? blockedSlots,
    int? jobsCompleted,
    int? khataTodayInr,
    int? khataMonthInr,
  }) {
    return WorkerProfile(
      id: id,
      nameEn: nameEn,
      nameHi: nameHi,
      trade: trade,
      skillsEn: skillsEn,
      skillsHi: skillsHi,
      servicePins: servicePins ?? this.servicePins,
      experienceYears: experienceYears,
      visitFeeInr: visitFeeInr ?? this.visitFeeInr,
      hourlyRateInr: hourlyRateInr ?? this.hourlyRateInr,
      dailyRateInr: dailyRateInr ?? this.dailyRateInr,
      customRates: customRates ?? this.customRates,
      upiId: upiId ?? this.upiId,
      phone: phone,
      languages: languages,
      verified: verified,
      isOnline: isOnline ?? this.isOnline,
      blockedSlots: blockedSlots ?? this.blockedSlots,
      ratingAvg: ratingAvg,
      jobsCompleted: jobsCompleted ?? this.jobsCompleted,
      khataTodayInr: khataTodayInr ?? this.khataTodayInr,
      khataMonthInr: khataMonthInr ?? this.khataMonthInr,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nameEn': nameEn,
        'nameHi': nameHi,
        'trade': trade,
        'skillsEn': skillsEn,
        'skillsHi': skillsHi,
        'servicePins': servicePins,
        'experienceYears': experienceYears,
        'visitFeeInr': visitFeeInr,
        'hourlyRateInr': hourlyRateInr,
        'dailyRateInr': dailyRateInr,
        'customRates': customRates.map((r) => r.toMap()).toList(),
        'upiId': upiId,
        'phone': phone,
        'languages': languages,
        'verified': verified,
        'isOnline': isOnline,
        'blockedSlots': blockedSlots,
        'ratingAvg': ratingAvg,
        'jobsCompleted': jobsCompleted,
        'khataTodayInr': khataTodayInr,
        'khataMonthInr': khataMonthInr,
      };

  factory WorkerProfile.fromMap(Map<String, dynamic> map) {
    final skillsRaw = (map['skillsEn'] ?? map['skills'] ?? const <dynamic>[]) as List<dynamic>;
    final skillsHiRaw = (map['skillsHi'] ?? skillsRaw) as List<dynamic>;
    final pinsRaw = (map['servicePins'] ?? const <dynamic>['560034']) as List<dynamic>;
    final blockedRaw = (map['blockedSlots'] ?? const <dynamic>[]) as List<dynamic>;
    final customRatesRaw =
        (map['customRates'] ?? map['custom_rates'] ?? const <dynamic>[]) as List<dynamic>;
    return WorkerProfile(
      id: (map['id'] ?? 'w1').toString(),
      nameEn: (map['nameEn'] ?? 'Helper').toString(),
      nameHi: (map['nameHi'] ?? map['nameEn'] ?? 'कारीगर').toString(),
      trade: (map['trade'] ?? 'electrician').toString(),
      skillsEn: skillsRaw.map((e) => e.toString()).toList(),
      skillsHi: skillsHiRaw.map((e) => e.toString()).toList(),
      servicePins: pinsRaw.map((e) => e.toString()).toList(),
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 5,
      visitFeeInr: (map['visitFeeInr'] as num?)?.toInt() ?? 149,
      hourlyRateInr: (map['hourlyRateInr'] as num?)?.toInt() ?? 250,
      dailyRateInr: (map['dailyRateInr'] ?? map['daily_rate_inr'] as num?)?.toInt() ?? 900,
      customRates: customRatesRaw
          .whereType<Map>()
          .map((e) => ServiceRateItem.fromMap(Map<String, dynamic>.from(e)))
          .where((r) => r.service.trim().isNotEmpty && r.priceInr > 0)
          .toList(),
      upiId: (map['upiId'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      languages: (map['languages'] ?? 'Hindi, English').toString(),
      verified: map['verified'] != false,
      isOnline: map['isOnline'] != false,
      blockedSlots: blockedRaw.map((e) => e.toString()).toList(),
      ratingAvg: (map['ratingAvg'] as num?)?.toDouble() ?? 4.8,
      jobsCompleted: (map['jobsCompleted'] as num?)?.toInt() ?? 0,
      khataTodayInr: (map['khataTodayInr'] as num?)?.toInt() ?? 0,
      khataMonthInr: (map['khataMonthInr'] as num?)?.toInt() ?? 0,
    );
  }
}

class BookingRecord {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String workerId;
  final String workerNameEn;
  final String workerNameHi;
  final String workerPhone;
  final String trade;
  final String pinCode;
  final String locality;
  final String fullAddress;
  final String bookingDate; // ISO yyyy-MM-dd or display label
  final String slotWindow;
  final String issueNote;
  final int visitFeeInr;
  final int? finalAmountInr;
  final String? paymentMethod;
  final String status; // requested | confirmed | in_progress | completed | declined | expired
  final int? customerRating;
  final String createdAt;

  const BookingRecord({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.workerId,
    required this.workerNameEn,
    required this.workerNameHi,
    required this.workerPhone,
    required this.trade,
    required this.pinCode,
    required this.locality,
    required this.fullAddress,
    required this.bookingDate,
    required this.slotWindow,
    required this.issueNote,
    required this.visitFeeInr,
    this.finalAmountInr,
    this.paymentMethod,
    this.status = 'requested',
    this.customerRating,
    required this.createdAt,
  });

  String localizedWorkerName(String lang) =>
      (lang == 'hi' && workerNameHi.isNotEmpty) ? workerNameHi : workerNameEn;

  BookingRecord copyWith({
    String? status,
    int? finalAmountInr,
    String? paymentMethod,
    int? customerRating,
  }) {
    return BookingRecord(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      workerId: workerId,
      workerNameEn: workerNameEn,
      workerNameHi: workerNameHi,
      workerPhone: workerPhone,
      trade: trade,
      pinCode: pinCode,
      locality: locality,
      fullAddress: fullAddress,
      bookingDate: bookingDate,
      slotWindow: slotWindow,
      issueNote: issueNote,
      visitFeeInr: visitFeeInr,
      finalAmountInr: finalAmountInr ?? this.finalAmountInr,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      customerRating: customerRating ?? this.customerRating,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'workerId': workerId,
        'workerNameEn': workerNameEn,
        'workerNameHi': workerNameHi,
        'workerPhone': workerPhone,
        'trade': trade,
        'pinCode': pinCode,
        'locality': locality,
        'fullAddress': fullAddress,
        'bookingDate': bookingDate,
        'slotWindow': slotWindow,
        'issueNote': issueNote,
        'visitFeeInr': visitFeeInr,
        'finalAmountInr': finalAmountInr,
        'paymentMethod': paymentMethod,
        'status': status,
        'customerRating': customerRating,
        'createdAt': createdAt,
      };

  factory BookingRecord.fromMap(Map<String, dynamic> map) => BookingRecord(
        id: (map['id'] ?? '').toString(),
        customerId: (map['customerId'] ?? map['customer_id'] ?? '').toString(),
        customerName: (map['customerName'] ?? map['customer_name'] ?? 'Customer').toString(),
        customerPhone: (map['customerPhone'] ?? map['customer_phone'] ?? '').toString(),
        workerId: (map['workerId'] ?? map['worker_id'] ?? 'w1').toString(),
        workerNameEn: (map['workerNameEn'] ?? map['workerName'] ?? map['worker_name'] ?? 'Helper').toString(),
        workerNameHi: (map['workerNameHi'] ?? map['workerNameEn'] ?? 'कारीगर').toString(),
        workerPhone: (map['workerPhone'] ?? '+91 99001 44556').toString(),
        trade: (map['trade'] ?? 'electrician').toString(),
        pinCode: (map['pinCode'] ?? map['pin_code'] ?? '560034').toString(),
        locality: (map['locality'] ?? '').toString(),
        fullAddress: (map['fullAddress'] ?? map['full_address'] ?? '').toString(),
        bookingDate: (map['bookingDate'] ?? map['booking_date'] ?? 'Today').toString(),
        slotWindow: (map['slotWindow'] ?? map['slot_window'] ?? '02:00 - 04:00 PM').toString(),
        issueNote: (map['issueNote'] ?? map['issue_note'] ?? '').toString(),
        visitFeeInr: (map['visitFeeInr'] ?? map['visit_fee_inr'] as num?)?.toInt() ?? 149,
        finalAmountInr: (map['finalAmountInr'] ?? map['final_amount_inr'] as num?)?.toInt(),
        paymentMethod: (map['paymentMethod'] ?? map['payment_method'])?.toString(),
        status: (map['status'] ?? 'requested').toString(),
        customerRating: (map['customerRating'] ?? map['customer_rating'] as num?)?.toInt(),
        createdAt: (map['createdAt'] ?? map['created_at'] ?? DateTime.now().toIso8601String()).toString(),
      );
}

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final bool isDismissed;
  final String createdAt;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.isDismissed = false,
    required this.createdAt,
  });

  AppNotificationItem copyWith({bool? isDismissed}) => AppNotificationItem(
        id: id,
        title: title,
        body: body,
        isDismissed: isDismissed ?? this.isDismissed,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'isDismissed': isDismissed,
        'createdAt': createdAt,
      };

  factory AppNotificationItem.fromMap(Map<String, dynamic> map) => AppNotificationItem(
        id: (map['id'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        body: (map['body'] ?? '').toString(),
        isDismissed: map['isDismissed'] == true || map['is_dismissed'] == true,
        createdAt: (map['createdAt'] ?? map['created_at'] ?? '').toString(),
      );
}

class BugReportRecord {
  final String id;
  final String description;
  final String pageContext;
  final String appVersion;
  final String userEmail;
  final String createdAt;
  final bool syncedToCloud;
  final String status;

  const BugReportRecord({
    required this.id,
    required this.description,
    required this.pageContext,
    required this.appVersion,
    required this.userEmail,
    required this.createdAt,
    this.syncedToCloud = false,
    this.status = 'open',
  });

  String get signature => '${userEmail.toLowerCase().trim()}|${description.trim()}';

  BugReportRecord copyWith({
    String? id,
    bool? syncedToCloud,
    String? status,
  }) =>
      BugReportRecord(
        id: id ?? this.id,
        description: description,
        pageContext: pageContext,
        appVersion: appVersion,
        userEmail: userEmail,
        createdAt: createdAt,
        syncedToCloud: syncedToCloud ?? this.syncedToCloud,
        status: status ?? this.status,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'pageContext': pageContext,
        'appVersion': appVersion,
        'userEmail': userEmail,
        'createdAt': createdAt,
        'syncedToCloud': syncedToCloud,
        'status': status,
      };

  factory BugReportRecord.fromMap(Map<String, dynamic> map) => BugReportRecord(
        id: (map['id'] ?? '').toString(),
        description: (map['description'] ?? '').toString(),
        pageContext: (map['pageContext'] ?? map['page_context'] ?? '').toString(),
        appVersion: (map['appVersion'] ?? map['app_version'] ?? '1.0.0').toString(),
        userEmail: (map['userEmail'] ?? map['user_email'] ?? 'anonymous@tester.local').toString(),
        createdAt: (map['createdAt'] ?? map['created_at'] ?? DateTime.now().toIso8601String()).toString(),
        syncedToCloud: map['syncedToCloud'] == true,
        status: (map['status'] ?? 'open').toString(),
      );
}

class AiParseSuggestion {
  final String trade;
  final String? preferredSlot;
  final String summaryNote;
  final String tierLabel;

  const AiParseSuggestion({
    required this.trade,
    this.preferredSlot,
    required this.summaryNote,
    required this.tierLabel,
  });
}
