class MenuItemModel {
  final int itemId;
  final int categoryId;
  final String name;
  final String? description;
  final double price;
  final String emoji;
  final String? imagePath;
  final bool isAvailable;
  final String categoryName;

  MenuItemModel({
    required this.itemId,
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    required this.emoji,
    this.imagePath,
    required this.isAvailable,
    required this.categoryName,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      itemId:       json['itemId']      ?? json['ItemId']      ?? 0,
      categoryId:   json['categoryId']  ?? json['CategoryId']  ?? 0,
      name:         json['name']        ?? json['Name']        ?? '',
      description:  json['description'] ?? json['Description'],
      price:        (json['price']      ?? json['Price']       ?? 0).toDouble(),
      emoji:        json['emoji']       ?? json['Emoji']       ?? '',
      imagePath:    json['imagePath']   ?? json['ImagePath'],
      isAvailable:  json['isAvailable'] ?? json['IsAvailable'] ?? true,
      categoryName: json['categoryName'] ?? json['CategoryName'] ??
                    (json['MenuCategories'] as Map?)?['Name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'categoryId': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'emoji': emoji,
      'imagePath': imagePath,
      'isAvailable': isAvailable,
      'categoryName': categoryName,
    };
  }
}
