// Model classes for the AMA-POS database

class Category {
  final int id;
  final String name;
  final int sortOrder;
  final bool isActive;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.updatedAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int,
        name: map['name'] as String,
        sortOrder: map['sortOrder'] as int,
        isActive: (map['isActive'] as int) == 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sortOrder': sortOrder,
        'isActive': isActive ? 1 : 0,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  Category copyWith({
    int? id,
    String? name,
    int? sortOrder,
    bool? isActive,
    DateTime? updatedAt,
  }) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        isActive: isActive ?? this.isActive,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Product {
  final int id;
  final int? categoryId;
  final String name;
  final int price;
  final bool isActive;
  final int sortOrder;
  final DateTime updatedAt;

  const Product({
    required this.id,
    this.categoryId,
    required this.name,
    required this.price,
    required this.isActive,
    required this.sortOrder,
    required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int,
        categoryId: map['categoryId'] as int?,
        name: map['name'] as String,
        price: map['price'] as int,
        isActive: (map['isActive'] as int) == 1,
        sortOrder: map['sortOrder'] as int,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'categoryId': categoryId,
        'name': name,
        'price': price,
        'isActive': isActive ? 1 : 0,
        'sortOrder': sortOrder,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  Product copyWith({
    int? id,
    Object? categoryId = _sentinel,
    String? name,
    int? price,
    bool? isActive,
    int? sortOrder,
    DateTime? updatedAt,
  }) =>
      Product(
        id: id ?? this.id,
        categoryId:
            categoryId == _sentinel ? this.categoryId : categoryId as int?,
        name: name ?? this.name,
        price: price ?? this.price,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Order {
  final int id;
  final String orderNo;
  final String type; // dineIn / takeOut
  final String? tableNo;
  final String status; // open / pendingPayment / paid / voided
  final int subtotal;
  final int total;
  final int? shiftId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.orderNo,
    required this.type,
    this.tableNo,
    required this.status,
    required this.subtotal,
    required this.total,
    this.shiftId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromMap(Map<String, dynamic> map) => Order(
        id: map['id'] as int,
        orderNo: map['orderNo'] as String,
        type: map['type'] as String,
        tableNo: map['tableNo'] as String?,
        status: map['status'] as String,
        subtotal: map['subtotal'] as int,
        total: map['total'] as int,
        shiftId: map['shiftId'] as int?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderNo': orderNo,
        'type': type,
        'tableNo': tableNo,
        'status': status,
        'subtotal': subtotal,
        'total': total,
        'shiftId': shiftId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  Order copyWith({
    int? id,
    String? orderNo,
    String? type,
    Object? tableNo = _sentinel,
    String? status,
    int? subtotal,
    int? total,
    Object? shiftId = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Order(
        id: id ?? this.id,
        orderNo: orderNo ?? this.orderNo,
        type: type ?? this.type,
        tableNo: tableNo == _sentinel ? this.tableNo : tableNo as String?,
        status: status ?? this.status,
        subtotal: subtotal ?? this.subtotal,
        total: total ?? this.total,
        shiftId: shiftId == _sentinel ? this.shiftId : shiftId as int?,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class OrderItem {
  final int id;
  final int orderId;
  final int? productId;
  final String nameSnapshot;
  final int priceSnapshot;
  final int qty;
  final int lineTotal;

  const OrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    required this.qty,
    required this.lineTotal,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        id: map['id'] as int,
        orderId: map['orderId'] as int,
        productId: map['productId'] as int?,
        nameSnapshot: map['nameSnapshot'] as String,
        priceSnapshot: map['priceSnapshot'] as int,
        qty: map['qty'] as int,
        lineTotal: map['lineTotal'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'productId': productId,
        'nameSnapshot': nameSnapshot,
        'priceSnapshot': priceSnapshot,
        'qty': qty,
        'lineTotal': lineTotal,
      };

  OrderItem copyWith({
    int? id,
    int? orderId,
    Object? productId = _sentinel,
    String? nameSnapshot,
    int? priceSnapshot,
    int? qty,
    int? lineTotal,
  }) =>
      OrderItem(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        productId:
            productId == _sentinel ? this.productId : productId as int?,
        nameSnapshot: nameSnapshot ?? this.nameSnapshot,
        priceSnapshot: priceSnapshot ?? this.priceSnapshot,
        qty: qty ?? this.qty,
        lineTotal: lineTotal ?? this.lineTotal,
      );
}

class Payment {
  final int id;
  final int orderId;
  final String method;
  final int amountDue;
  final int amountReceived;
  final int change;
  final DateTime paidAt;

  const Payment({
    required this.id,
    required this.orderId,
    required this.method,
    required this.amountDue,
    required this.amountReceived,
    required this.change,
    required this.paidAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as int,
        orderId: map['orderId'] as int,
        method: map['method'] as String,
        amountDue: map['amountDue'] as int,
        amountReceived: map['amountReceived'] as int,
        change: map['change'] as int,
        paidAt: DateTime.fromMillisecondsSinceEpoch(map['paidAt'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'method': method,
        'amountDue': amountDue,
        'amountReceived': amountReceived,
        'change': change,
        'paidAt': paidAt.millisecondsSinceEpoch,
      };
}

class Shift {
  final int id;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int? openingCash;
  final int? closingCash;
  final String? note;

  const Shift({
    required this.id,
    required this.openedAt,
    this.closedAt,
    this.openingCash,
    this.closingCash,
    this.note,
  });

  factory Shift.fromMap(Map<String, dynamic> map) => Shift(
        id: map['id'] as int,
        openedAt:
            DateTime.fromMillisecondsSinceEpoch(map['openedAt'] as int),
        closedAt: map['closedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['closedAt'] as int)
            : null,
        openingCash: map['openingCash'] as int?,
        closingCash: map['closingCash'] as int?,
        note: map['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'openedAt': openedAt.millisecondsSinceEpoch,
        'closedAt': closedAt?.millisecondsSinceEpoch,
        'openingCash': openingCash,
        'closingCash': closingCash,
        'note': note,
      };

  Shift copyWith({
    int? id,
    DateTime? openedAt,
    Object? closedAt = _sentinel,
    Object? openingCash = _sentinel,
    Object? closingCash = _sentinel,
    Object? note = _sentinel,
  }) =>
      Shift(
        id: id ?? this.id,
        openedAt: openedAt ?? this.openedAt,
        closedAt: closedAt == _sentinel ? this.closedAt : closedAt as DateTime?,
        openingCash:
            openingCash == _sentinel ? this.openingCash : openingCash as int?,
        closingCash:
            closingCash == _sentinel ? this.closingCash : closingCash as int?,
        note: note == _sentinel ? this.note : note as String?,
      );
}

class MerchantConfig {
  final int id;
  final String merchantName;
  final String currency;
  final int schemaVersion;
  final int tableCount;
  final String terminalCode;
  final DateTime updatedAt;

  const MerchantConfig({
    required this.id,
    required this.merchantName,
    required this.currency,
    required this.schemaVersion,
    required this.tableCount,
    required this.terminalCode,
    required this.updatedAt,
  });

  factory MerchantConfig.fromMap(Map<String, dynamic> map) => MerchantConfig(
        id: map['id'] as int,
        merchantName: map['merchantName'] as String,
        currency: map['currency'] as String,
        schemaVersion: map['schemaVersion'] as int,
        tableCount: map['tableCount'] as int? ?? 0,
        terminalCode: map['terminalCode'] as String? ?? 'A1',
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'merchantName': merchantName,
        'currency': currency,
        'schemaVersion': schemaVersion,
        'tableCount': tableCount,
        'terminalCode': terminalCode,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}

// Sentinel value for copyWith optional nullable fields
const Object _sentinel = Object();
