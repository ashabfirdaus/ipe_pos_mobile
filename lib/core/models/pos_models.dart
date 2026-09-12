// Models for Auth, POS, Invoices, Items, and Payment Notifications
import '../config/api_config.dart';

class UserModel {
  final dynamic id;
  final String name;
  final String username;
  final String? email;
  final String? role;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    this.role,
  });

  String get roleName => _extractRoleName(role);

  static String _extractRoleName(dynamic rawRole) {
    if (rawRole == null) return 'Kasir';
    if (rawRole is Map) {
      return rawRole['role_name']?.toString() ??
          rawRole['name']?.toString() ??
          rawRole['title']?.toString() ??
          rawRole['display_name']?.toString() ??
          'Kasir';
    }
    if (rawRole is List && rawRole.isNotEmpty) {
      return _extractRoleName(rawRole.first);
    }
    final r = rawRole.toString().trim();
    if (r.isEmpty || r == 'null') return 'Kasir';
    if (r.startsWith('{')) {
      final match = RegExp(r'role_name["\s:]+([^",}\]]+)').firstMatch(r) ??
          RegExp(r'name["\s:]+([^",}\]]+)').firstMatch(r);
      if (match != null) {
        final val = match.group(1)?.trim() ?? '';
        if (val.isNotEmpty && val != 'null') return val;
      }
    }
    return r;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleValue = json['role_name'] ?? json['role'] ?? json['roles'];
    final parsedRole = _extractRoleName(roleValue);

    return UserModel(
      id: json['id'],
      name: json['name']?.toString() ?? json['username']?.toString() ?? 'Kasir',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString(),
      role: parsedRole,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'email': email,
    'role': roleName,
    'role_name': roleName,
  };
}

class BranchModel {
  final int id;
  final String name;
  final String? code;
  final String? address;

  BranchModel({
    required this.id,
    required this.name,
    this.code,
    this.address,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 1,
      name: json['name']?.toString() ?? json['branch_name']?.toString() ?? 'Cabang',
      code: json['code']?.toString(),
      address: json['address']?.toString(),
    );
  }
}

class WarehouseModel {
  final int id;
  final String name;
  final int? branchId;
  final String? code;

  WarehouseModel({
    required this.id,
    required this.name,
    this.branchId,
    this.code,
  });

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 1,
      name: json['name']?.toString() ?? json['warehouse_name']?.toString() ?? 'Gudang',
      branchId: int.tryParse(json['branch_id']?.toString() ?? ''),
      code: json['code']?.toString(),
    );
  }
}

class PaymentMethodModel {
  final int id;
  final String name;
  final String? code;
  final String? type;
  final String? status;

  PaymentMethodModel({
    required this.id,
    required this.name,
    this.code,
    this.type,
    this.status,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 1,
      name: json['method_name']?.toString() ??
          json['name']?.toString() ??
          json['payment_name']?.toString() ??
          'Tunai',
      code: json['code']?.toString(),
      type: json['type']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class PromoModel {
  final int id;
  final String name;
  final String? code;
  final String? discountType; // percentage, fixed
  final double discountValue;

  PromoModel({
    required this.id,
    required this.name,
    this.code,
    this.discountType,
    required this.discountValue,
  });

  factory PromoModel.fromJson(Map<String, dynamic> json) {
    // Backend Laravel uses promo_type: 1 (percentage), 2 (bundle / fixed)
    // and discount_percentage or discount_value
    final rawType = json['promo_type']?.toString() ??
        json['discount_type']?.toString() ??
        json['type']?.toString();

    final hasDiscountPercentage = json['discount_percentage'] != null &&
        (double.tryParse(json['discount_percentage'].toString()) ?? 0.0) > 0;

    final isPercentage = rawType == '1' ||
        rawType?.toLowerCase() == 'percentage' ||
        rawType?.toLowerCase() == 'percent' ||
        hasDiscountPercentage;

    final discountVal = double.tryParse(
          json['discount_percentage']?.toString() ??
              json['discount_value']?.toString() ??
              json['discount']?.toString() ??
              json['value']?.toString() ??
              '0',
        ) ??
        0.0;

    return PromoModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? json['promo_name']?.toString() ?? 'Promo',
      code: json['code']?.toString() ?? json['promo_code']?.toString(),
      discountType: isPercentage ? 'percentage' : 'fixed',
      discountValue: discountVal,
    );
  }
}

class PosInitialDataModel {
  final BranchModel? defaultBranch;
  final WarehouseModel? defaultWarehouse;
  final List<PaymentMethodModel> paymentMethods;
  final List<PromoModel> promos;
  final int defaultPpnType;
  final double ppnRate;

  PosInitialDataModel({
    this.defaultBranch,
    this.defaultWarehouse,
    required this.paymentMethods,
    required this.promos,
    this.defaultPpnType = 0,
    required this.ppnRate,
  });

  factory PosInitialDataModel.fromJson(Map<String, dynamic> json) {
    BranchModel? branch;
    if (json['default_branch'] != null && json['default_branch'] is Map) {
      branch = BranchModel.fromJson(
        Map<String, dynamic>.from(json['default_branch'] as Map),
      );
    }

    WarehouseModel? warehouse;
    if (json['default_warehouse'] != null && json['default_warehouse'] is Map) {
      warehouse = WarehouseModel.fromJson(
        Map<String, dynamic>.from(json['default_warehouse'] as Map),
      );
    }

    final pmList = <PaymentMethodModel>[];
    final rawPm = json['payment_methods'];
    if (rawPm is List) {
      for (final item in rawPm) {
        if (item is Map) {
          final pm = PaymentMethodModel.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (pm.status == null || pm.status == '1' || pm.status == 'active') {
            pmList.add(pm);
          }
        }
      }
    }

    final promoList = <PromoModel>[];
    final rawPromos = json['active_promos'] ?? json['promos'];
    if (rawPromos is List) {
      for (final item in rawPromos) {
        if (item is Map) {
          promoList.add(
            PromoModel.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final ppn = double.tryParse(
          json['percentage_ppn']?.toString() ??
              json['ppn_rate']?.toString() ??
              json['tax_rate']?.toString() ??
              json['ppn']?.toString() ??
              '0',
        ) ??
        0.0;

    final ppnType = int.tryParse(
          json['default_ppn_type']?.toString() ??
              json['ppn_type']?.toString() ??
              '0',
        ) ??
        0;

    return PosInitialDataModel(
      defaultBranch: branch,
      defaultWarehouse: warehouse,
      paymentMethods: pmList,
      promos: promoList,
      defaultPpnType: ppnType,
      ppnRate: ppn,
    );
  }
}

class ProductModel {
  final int id;
  final int itemId;
  final String name;
  final String? code;
  final String? barcode;
  final double price;
  final double stock;
  final String? unit;
  final String? categoryName;
  final String? imagePath;
  final String? qrcode;

  ProductModel({
    required this.id,
    required this.itemId,
    required this.name,
    this.code,
    this.barcode,
    required this.price,
    required this.stock,
    this.unit,
    this.categoryName,
    this.imagePath,
    this.qrcode,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final parsedId = int.tryParse(
          json['id']?.toString() ??
              json['stock_id']?.toString() ??
              json['item_id']?.toString() ??
              '',
        ) ??
        0;
    final parsedItemId = int.tryParse(
          json['item_id']?.toString() ??
              json['id']?.toString() ??
              '',
        ) ??
        parsedId;
    return ProductModel(
      id: parsedId,
      itemId: parsedItemId,
      name: json['name']?.toString() ?? json['item_name']?.toString() ?? 'Produk',
      code: json['code']?.toString() ?? json['item_code']?.toString(),
      barcode: json['barcode']?.toString() ?? json['item_barcode']?.toString() ?? json['qrcode']?.toString(),
      price: double.tryParse(
            json['selling_price']?.toString() ??
                json['price']?.toString() ??
                json['sell_price']?.toString() ??
                '0',
          ) ??
          0.0,
      stock: double.tryParse(
            json['remaining_qty']?.toString() ??
                json['stock']?.toString() ??
                json['total_stock']?.toString() ??
                json['qty']?.toString() ??
                '0',
          ) ??
          0.0,
      unit: json['unit']?.toString() ?? json['unit_name']?.toString() ?? 'Pcs',
      categoryName: json['category_name']?.toString() ?? json['category']?.toString(),
      imagePath: () {
        final raw = json['image_path']?.toString() ??
            json['image']?.toString() ??
            json['image_url']?.toString() ??
            json['photo']?.toString() ??
            json['picture']?.toString();
        if (raw == null || raw.isEmpty || raw == 'null') return null;
        if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
        final base = ApiConfig.baseUrl.replaceAll('/api', '');
        return raw.startsWith('/') ? '$base$raw' : '$base/$raw';
      }(),
      qrcode: json['qrcode']?.toString(),
    );
  }
}

class CartItemModel {
  final ProductModel product;
  int qty;
  double price;
  double discount;
  String qrcode;

  CartItemModel({
    required this.product,
    this.qty = 1,
    required this.price,
    this.discount = 0,
    this.qrcode = '',
  });

  double get subTotal => (price * qty) - discount;

  Map<String, dynamic> toInvoiceItemJson() {
    final finalQr = qrcode.isNotEmpty ? qrcode : product.qrcode;
    return {
      'item_id': product.itemId,
      'item_name': product.name,
      'qty': qty,
      'price': price,
      'discount': discount,
      'sub_total': subTotal,
      'qrcode': finalQr != null && finalQr.isNotEmpty ? finalQr : null,
      if (product.unit != null) 'unit': product.unit,
      if (product.code != null) 'code': product.code,
    };
  }
}

class InvoiceItemModel {
  final dynamic itemId;
  final String itemName;
  final int qty;
  final double price;
  final double discount;
  final double subTotal;
  final String? qrcode;
  final String? unit;
  final String? itemCode;

  InvoiceItemModel({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.price,
    required this.discount,
    required this.subTotal,
    this.qrcode,
    this.unit,
    this.itemCode,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    final itemObj = json['item'] is Map<String, dynamic> ? json['item'] as Map<String, dynamic> : null;
    final unitObj = itemObj?['unit'] is Map<String, dynamic>
        ? itemObj!['unit'] as Map<String, dynamic>
        : (json['unit'] is Map<String, dynamic> ? json['unit'] as Map<String, dynamic> : null);

    return InvoiceItemModel(
      itemId: json['item_id'] ?? itemObj?['id'] ?? json['id'],
      itemName: json['item_name']?.toString() ??
          itemObj?['item_name']?.toString() ??
          json['name']?.toString() ??
          'Item',
      qty: (double.tryParse(json['qty']?.toString() ?? '1') ?? 1.0).toInt(),
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0,
      subTotal: double.tryParse(json['sub_total']?.toString() ?? '0') ?? 0.0,
      qrcode: json['qrcode']?.toString(),
      unit: json['unit_measure_name']?.toString() ??
          unitObj?['unit_measure_name']?.toString() ??
          (json['unit'] is String ? json['unit']?.toString() : null) ??
          'Pcs',
      itemCode: json['item_code']?.toString() ??
          itemObj?['item_code']?.toString() ??
          json['code']?.toString(),
    );
  }
}

class InvoiceModel {
  final dynamic id;
  final String invoiceNo;
  final String createdAt;
  final int status; // 1 = aktif, 0 = void
  final String? branchName;
  final String? warehouseName;
  final String? paymentMethodName;
  final String? promoName;
  final double subTotal;
  final double discount;
  final double ppn;
  final double grandTotal;
  final double cash;
  final double change;
  final String? voidDesc;
  final String? voidAt;
  final String? cashierName;
  final List<InvoiceItemModel> items;

  InvoiceModel({
    required this.id,
    required this.invoiceNo,
    required this.createdAt,
    this.status = 1,
    this.branchName,
    this.warehouseName,
    this.paymentMethodName,
    this.promoName,
    this.cashierName,
    required this.subTotal,
    required this.discount,
    required this.ppn,
    required this.grandTotal,
    required this.cash,
    required this.change,
    this.voidDesc,
    this.voidAt,
    this.items = const [],
  });

  InvoiceModel copyWith({
    dynamic id,
    String? invoiceNo,
    String? createdAt,
    int? status,
    String? branchName,
    String? warehouseName,
    String? paymentMethodName,
    String? promoName,
    String? cashierName,
    double? subTotal,
    double? discount,
    double? ppn,
    double? grandTotal,
    double? cash,
    double? change,
    String? voidDesc,
    String? voidAt,
    List<InvoiceItemModel>? items,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      branchName: branchName ?? this.branchName,
      warehouseName: warehouseName ?? this.warehouseName,
      paymentMethodName: paymentMethodName ?? this.paymentMethodName,
      promoName: promoName ?? this.promoName,
      cashierName: cashierName ?? this.cashierName,
      subTotal: subTotal ?? this.subTotal,
      discount: discount ?? this.discount,
      ppn: ppn ?? this.ppn,
      grandTotal: grandTotal ?? this.grandTotal,
      cash: cash ?? this.cash,
      change: change ?? this.change,
      voidDesc: voidDesc ?? this.voidDesc,
      voidAt: voidAt ?? this.voidAt,
      items: items ?? this.items,
    );
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final itemList = <InvoiceItemModel>[];
    final rawItems = json['details'] ?? json['items'] ?? json['group_details'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          itemList.add(InvoiceItemModel.fromJson(item));
        }
      }
    }

    final branchObj = json['branch'] is Map<String, dynamic> ? json['branch'] as Map<String, dynamic> : null;
    final warehouseObj = json['warehouse'] is Map<String, dynamic> ? json['warehouse'] as Map<String, dynamic> : null;
    final pmObj = json['payment_method'] is Map<String, dynamic> ? json['payment_method'] as Map<String, dynamic> : null;
    final promoObj = json['promo'] is Map<String, dynamic> ? json['promo'] as Map<String, dynamic> : null;
    final userObj = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : (json['cashier'] is Map<String, dynamic>
            ? json['cashier'] as Map<String, dynamic>
            : (json['creator'] is Map<String, dynamic>
                ? json['creator'] as Map<String, dynamic>
                : (json['created_by'] is Map<String, dynamic>
                    ? json['created_by'] as Map<String, dynamic>
                    : (json['created_by_user'] is Map<String, dynamic>
                        ? json['created_by_user'] as Map<String, dynamic>
                        : null))));

    final parsedCashierName = json['cashier_name']?.toString() ??
        json['user_name']?.toString() ??
        userObj?['name']?.toString() ??
        userObj?['username']?.toString() ??
        userObj?['full_name']?.toString() ??
        (json['cashier'] is String ? json['cashier']?.toString() : null) ??
        (json['user'] is String ? json['user']?.toString() : null) ??
        (json['created_by'] is String ? json['created_by']?.toString() : null) ??
        json['created_by_name']?.toString();

    return InvoiceModel(
      id: json['id'],
      invoiceNo: json['pos_invoice_code']?.toString() ??
          json['invoice_no']?.toString() ??
          json['invoice_number']?.toString() ??
          json['code']?.toString() ??
          'INV-${json['id']}',
      createdAt: json['created_at']?.toString() ?? json['date']?.toString() ?? '',
      status: int.tryParse(json['status']?.toString() ?? '1') ?? 1,
      branchName: json['branch_name']?.toString() ?? branchObj?['branch_name']?.toString(),
      warehouseName: json['warehouse_name']?.toString() ?? warehouseObj?['warehouse_name']?.toString(),
      paymentMethodName: json['payment_method_name']?.toString() ??
          pmObj?['method_name']?.toString() ??
          (json['payment_method'] is String ? json['payment_method']?.toString() : null),
      promoName: json['promo_name']?.toString() ??
          promoObj?['promo_name']?.toString() ??
          promoObj?['name']?.toString() ??
          (json['promo'] is String ? json['promo']?.toString() : null),
      cashierName: parsedCashierName,
      subTotal: double.tryParse(json['sub_total']?.toString() ?? '0') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0,
      ppn: double.tryParse(json['ppn']?.toString() ?? json['tax']?.toString() ?? '0') ?? 0.0,
      grandTotal: double.tryParse(json['grand_total']?.toString() ?? '0') ?? 0.0,
      cash: double.tryParse(json['cash']?.toString() ?? '0') ?? 0.0,
      change: double.tryParse(json['change']?.toString() ?? '0') ?? 0.0,
      voidDesc: json['void_desc']?.toString(),
      voidAt: json['void_date']?.toString() ?? json['void_at']?.toString(),
      items: itemList,
    );
  }
}

class ItemTransactionSummaryModel {
  final dynamic itemId;
  final String itemName;
  final double totalQtyIn;
  final double totalQtyOut;
  final double currentStock;
  final double totalValue;
  final int totalTransactions;
  final int totalRows;

  ItemTransactionSummaryModel({
    required this.itemId,
    required this.itemName,
    required this.totalQtyIn,
    required this.totalQtyOut,
    required this.currentStock,
    required this.totalValue,
    required this.totalTransactions,
    required this.totalRows,
  });

  factory ItemTransactionSummaryModel.fromJson(Map<String, dynamic> json) {
    return ItemTransactionSummaryModel(
      itemId: json['item_id'] ?? json['id'],
      itemName: json['item_name']?.toString() ?? json['name']?.toString() ?? 'Barang',
      totalQtyIn: double.tryParse(json['total_in']?.toString() ?? json['qty_in']?.toString() ?? '0') ?? 0.0,
      totalQtyOut: double.tryParse(json['total_out']?.toString() ?? json['qty_out']?.toString() ?? '0') ?? 0.0,
      currentStock: double.tryParse(json['current_stock']?.toString() ?? json['stock']?.toString() ?? '0') ?? 0.0,
      totalValue: double.tryParse(json['total_value']?.toString() ?? '0') ?? 0.0,
      totalTransactions: int.tryParse(json['total_transactions']?.toString() ?? json['total']?.toString() ?? '0') ?? 0,
      totalRows: int.tryParse(json['total_rows']?.toString() ?? json['rows']?.toString() ?? '0') ?? 0,
    );
  }
}

class ItemTransactionDetailModel {
  final dynamic id;
  final String date;
  final String type; // Pembelian, Penjualan, Transfer, Penyesuaian
  final String refNo;
  final double qtyIn;
  final double qtyOut;
  final double balance;
  final String? notes;

  ItemTransactionDetailModel({
    required this.id,
    required this.date,
    required this.type,
    required this.refNo,
    required this.qtyIn,
    required this.qtyOut,
    required this.balance,
    this.notes,
  });

  factory ItemTransactionDetailModel.fromJson(Map<String, dynamic> json) {
    return ItemTransactionDetailModel(
      id: json['id'],
      date: json['date']?.toString() ?? json['created_at']?.toString() ?? '',
      type: json['type']?.toString() ?? json['transaction_type']?.toString() ?? 'Transaksi',
      refNo: json['ref_no']?.toString() ?? json['reference']?.toString() ?? '-',
      qtyIn: double.tryParse(json['qty_in']?.toString() ?? '0') ?? 0.0,
      qtyOut: double.tryParse(json['qty_out']?.toString() ?? '0') ?? 0.0,
      balance: double.tryParse(json['balance']?.toString() ?? json['stock_after']?.toString() ?? '0') ?? 0.0,
      notes: json['notes']?.toString() ?? json['description']?.toString(),
    );
  }
}
