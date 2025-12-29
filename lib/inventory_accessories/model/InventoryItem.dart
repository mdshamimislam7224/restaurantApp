class InventoryItem {
  String id;
  String name;
  String category;
  int quantity;
  String location;
  String status;
  String lastChecked;
  String notes;
  String imageUrl; // Add this
  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.location,
    required this.status,
    required this.lastChecked,
    required this.notes,
    this.imageUrl = '',
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id']?.toString() ?? '',
      name: json['item_name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      quantity: int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      location: json['location']?.toString() ?? 'Storage',
      status: json['status']?.toString() ?? 'Good',
      lastChecked: json['last_checked']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'location': location,
      'status': status,
      'last_checked': lastChecked,
      'notes': notes,
      'image_url': imageUrl,
    };
  }

}