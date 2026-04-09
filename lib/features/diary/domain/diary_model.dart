class DiaryModel {
  final String id;
  final String seamstressId;
  final String? seamstressName;
  final String description;
  final int quantity;
  final List<String> photos;
  final double? salaryAmount;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime entryDate;
  final DateTime createdAt;

  const DiaryModel({
    required this.id,
    required this.seamstressId,
    this.seamstressName,
    required this.description,
    required this.quantity,
    required this.photos,
    this.salaryAmount,
    this.approvedBy,
    this.approvedAt,
    required this.entryDate,
    required this.createdAt,
  });

  factory DiaryModel.fromJson(Map<String, dynamic> json) {
    final seamstress = json['seamstress'] as Map<String, dynamic>?;
    final rawPhotos = json['photos'];
    List<String> photos = [];
    if (rawPhotos is List) {
      photos = rawPhotos.whereType<String>().toList();
    }
    return DiaryModel(
      id: json['id'] as String,
      seamstressId: json['seamstress_id'] as String,
      seamstressName: seamstress?['name'] as String?,
      description: json['description'] as String,
      quantity: json['quantity'] as int? ?? 1,
      photos: photos,
      salaryAmount: (json['salary_amount'] as num?)?.toDouble(),
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      entryDate: DateTime.parse(json['entry_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isApproved => approvedBy != null;
}
