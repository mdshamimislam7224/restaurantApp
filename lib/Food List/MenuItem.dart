class MenuItem {
  final int id;
  final String name;
  final double price;
  final int categoryId;
  final String categoryName;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.categoryName,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: int.parse(json['id'].toString()),
      name: json['name'],
      price: double.parse(json['price'].toString()),
      categoryId: int.parse(json['categoryId'].toString()),
      categoryName: json['categoryName'],
    );
  }
}
