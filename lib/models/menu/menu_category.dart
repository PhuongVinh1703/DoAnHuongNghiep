class MenuCategoryModel {
  final int categoryId;
  final String name;
  final String icon;
  final int displayOrder;
  final bool isActive;

  MenuCategoryModel({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.displayOrder,
    required this.isActive,
  });

  factory MenuCategoryModel.fromJson(Map<String, dynamic> json) {
    return MenuCategoryModel(
      categoryId:   json['categoryId']   ?? json['CategoryId']   ?? 0,
      name:         json['name']         ?? json['Name']         ?? '',
      icon:         json['icon']         ?? json['Icon']         ?? '',
      displayOrder: json['displayOrder'] ?? json['DisplayOrder'] ?? 0,
      isActive:     json['isActive']     ?? json['IsActive']     ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'name': name,
      'icon': icon,
      'displayOrder': displayOrder,
      'isActive': isActive,
    };
  }
}
