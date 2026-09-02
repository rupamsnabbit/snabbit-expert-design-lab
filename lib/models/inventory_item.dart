// Enums
enum ApparelSize {
  s('S'),
  m('M'),
  l('L'),
  xl('XL'),
  xxl('XXL');

  const ApparelSize(this.description);
  final String description;

  // Static fromString method for ApparelSize
  static ApparelSize? fromString(String? value) {
    if (value == null) return null; // Handle null input gracefully

    switch (value.toLowerCase()) { // Convert to lowercase for case-insensitivity
      case 's':
        return ApparelSize.s;
      case 'm':
        return ApparelSize.m;
      case 'l':
        return ApparelSize.l;
      case 'xl':
        return ApparelSize.xl;
      case 'xxl':
        return ApparelSize.xxl;
      default:
        return null; // Return null if no match is found
    }
  }
}

enum ItemType {rainySeason("RAINY_SEASON")
  ;

  const ItemType(this.description);
  final String description;

  // Static fromString method for ItemType
  static ItemType? fromString(String? value) {
    if (value == null) return null; // Handle null input gracefully

    switch (value) { // Convert to lowercase for case-insensitivity
      case 'RAINY_SEASON':
        return ItemType.rainySeason;

      default:
        return null; // Return null if no match is found
    }
  }
}

// Base Class for Inventory Items
class InventoryItem {
  int? id;
  String? name;
  int? quantity;
  int? maxQuantity;
  String? image; // URI
  List<String>? availableSizes; // Nullable for non-apparel items
  String? size;
  List<InventoryItem>? subItems;
  ItemType? type;

  InventoryItem({
    this.id,
    this.name,
    this.quantity,
    this.maxQuantity,
    this.image,
    this.availableSizes,
    this.subItems,
    this.type,
  });

  // Factory constructor for creating instances based on type
  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'],
      name: json['name'],
      availableSizes: json['size'] != null
          ? List<String>.from(json['size'])
          : null,
      quantity: json['quantity'],
      maxQuantity: json['max_quantity'],
      image: json['image'],
      subItems: json['sub_items'] != null
          ? (json['sub_items'] as List)
          .map((item) => InventoryItem.fromJson(item))
          .toList()
          : null,
      type: json['type'] != null
          ? ItemType.fromString(json['type'])
          : null, // Handle type as nullable
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'image': image,
      'size': size,
      'type': type?.description,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true; // Same instance
    if (other is! InventoryItem) return false; // Not the same type


    return id == other.id &&
        name == other.name &&
        image == other.image &&
        type == other.type;
  }

  @override
  int get hashCode =>
      Object.hash(
        id,
        name,
        image,
        type,
      );

}