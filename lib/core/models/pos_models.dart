// Models for Auth, POS, Invoices, Items, and Payment Notifications

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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name']?.toString() ?? json['username']?.toString() ?? 'Kasir',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? json['role_name']?.toString() ?? 'Kasir',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'email': email,
    'role': role,
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
    return PromoModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? json['promo_name']?.toString() ?? 'Promo',
      code: json['code']?.toString() ?? json['promo_code']?.toString(),
      discountType: json['discount_type']?.toString() ?? json['type']?.toString() ?? 'fixed',
      discountValue: double.tryParse(json['discount_value']?.toString() ?? json['discount']?.toString() ?? '0') ?? 0.0,
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
                json['qty']?.toString() ??
                '0',
          ) ??
          0.0,
      unit: json['unit']?.toString() ?? json['unit_name']?.toString() ?? 'Pcs',
      categoryName: json['category_name']?.toString() ?? json['category']?.toString(),
      imagePath: json['image_path']?.toString() ?? json['image']?.toString(),
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

  Map<String, dynamic> toInvoiceItemJson() => {
    'item_id': product.itemId,
    'qty': qty,
    'price': price,
    'discount': discount,
    'sub_total': subTotal,
    'qrcode': qrcode,
  };
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
    return InvoiceItemModel(
      itemId: json['item_id'] ?? json['id'],
      itemName: json['item_name']?.toString() ?? json['name']?.toString() ?? 'Item',
      qty: int.tryParse(json['qty']?.toString() ?? '1') ?? 1,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0,
      subTotal: double.tryParse(json['sub_total']?.toString() ?? '0') ?? 0.0,
      qrcode: json['qrcode']?.toString(),
      unit: json['unit']?.toString() ?? json['unit_name']?.toString() ?? 'Pcs',
      itemCode: json['item_code']?.toString() ?? json['code']?.toString(),
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
    if (json['items'] is List) {
      for (final item in json['items']) {
        if (item is Map<String, dynamic>) {
          itemList.add(InvoiceItemModel.fromJson(item));
        }
      }
    }

    return InvoiceModel(
      id: json['id'],
      invoiceNo: json['invoice_no']?.toString() ?? json['invoice_number']?.toString() ?? json['code']?.toString() ?? 'INV-${json['id']}',
      createdAt: json['created_at']?.toString() ?? json['date']?.toString() ?? '',
      status: int.tryParse(json['status']?.toString() ?? '1') ?? 1,
      branchName: json['branch_name']?.toString(),
      warehouseName: json['warehouse_name']?.toString(),
      paymentMethodName: json['payment_method_name']?.toString() ?? json['payment_method']?.toString(),
      promoName: json['promo_name']?.toString() ?? json['promo']?['name']?.toString() ?? json['promo']?.toString(),
      subTotal: double.tryParse(json['sub_total']?.toString() ?? '0') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0,
      ppn: double.tryParse(json['ppn']?.toString() ?? json['tax']?.toString() ?? '0') ?? 0.0,
      grandTotal: double.tryParse(json['grand_total']?.toString() ?? '0') ?? 0.0,
      cash: double.tryParse(json['cash']?.toString() ?? '0') ?? 0.0,
      change: double.tryParse(json['change']?.toString() ?? '0') ?? 0.0,
      voidDesc: json['void_desc']?.toString(),
      voidAt: json['void_at']?.toString(),
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
