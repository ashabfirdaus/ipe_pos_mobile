// Models for Auth, POS, Invoices, Items, and Payment Notifications
import '../config/api_config.dart';

class UserModel {
  final dynamic id;
  final String name;
  final String username;
  final String? email;
  final String? role;
  final bool canVoid;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    this.role,
    this.canVoid = false,
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
    final bool canVoid = json['can_void'] == true ||
        json['can_void'] == 1 ||
        json['can_void']?.toString() == '1' ||
        json['can_void']?.toString().toLowerCase() == 'true';

    return UserModel(
      id: json['id'],
      name: json['name']?.toString() ?? json['username']?.toString() ?? 'Kasir',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString(),
      role: parsedRole,
      canVoid: canVoid,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'email': email,
        'role': roleName,
        'role_name': roleName,
        'can_void': canVoid,
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
      name: json['name']?.toString() ??
          json['branch_name']?.toString() ??
          'Cabang',
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
      name: json['name']?.toString() ??
          json['warehouse_name']?.toString() ??
          'Gudang',
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
      name:
          json['name']?.toString() ?? json['promo_name']?.toString() ?? 'Promo',
      code: json['code']?.toString() ?? json['promo_code']?.toString(),
      discountType: isPercentage ? 'percentage' : 'fixed',
      discountValue: discountVal,
    );
  }
}

class SpecialPriceConfigModel {
  final bool enabled;
  final bool isCurrentlyActive;
  final bool isTimeActive;
  final bool isDayActive;
  final String startTime;
  final String endTime;
  final int dailyQuota;
  final String scope;
  final int usedQuotaToday;
  final int remainingQuotaToday;
  final bool isQuotaAvailable;

  SpecialPriceConfigModel({
    required this.enabled,
    required this.isCurrentlyActive,
    this.isTimeActive = false,
    this.isDayActive = true,
    this.startTime = '18:00:00',
    this.endTime = '23:59:59',
    this.dailyQuota = 140,
    this.scope = 'global',
    this.usedQuotaToday = 0,
    this.remainingQuotaToday = 140,
    this.isQuotaAvailable = true,
  });

  factory SpecialPriceConfigModel.fromJson(Map<String, dynamic> json) {
    return SpecialPriceConfigModel(
      enabled: json['enabled'] == true || json['enabled']?.toString() == '1',
      isCurrentlyActive: json['is_currently_active'] == true ||
          json['is_currently_active']?.toString() == '1',
      isTimeActive: json['is_time_active'] == true,
      isDayActive: json['is_day_active'] != false,
      startTime: json['start_time']?.toString() ?? '18:00:00',
      endTime: json['end_time']?.toString() ?? '23:59:59',
      dailyQuota:
          int.tryParse(json['daily_quota']?.toString() ?? '140') ?? 140,
      scope: json['scope']?.toString() ?? 'global',
      usedQuotaToday:
          int.tryParse(json['used_quota_today']?.toString() ?? '0') ?? 0,
      remainingQuotaToday:
          int.tryParse(json['remaining_quota_today']?.toString() ?? '140') ??
              140,
      isQuotaAvailable: json['is_quota_available'] == true ||
          (int.tryParse(json['remaining_quota_today']?.toString() ?? '0') ??
                  0) >
              0,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'is_currently_active': isCurrentlyActive,
        'is_time_active': isTimeActive,
        'is_day_active': isDayActive,
        'start_time': startTime,
        'end_time': endTime,
        'daily_quota': dailyQuota,
        'scope': scope,
        'used_quota_today': usedQuotaToday,
        'remaining_quota_today': remainingQuotaToday,
        'is_quota_available': isQuotaAvailable,
      };
}

class PosInitialDataModel {
  final BranchModel? defaultBranch;
  final WarehouseModel? defaultWarehouse;
  final List<PaymentMethodModel> paymentMethods;
  final List<PromoModel> promos;
  final int defaultPpnType;
  final double ppnRate;
  final SpecialPriceConfigModel? specialPriceConfig;

  PosInitialDataModel({
    this.defaultBranch,
    this.defaultWarehouse,
    required this.paymentMethods,
    required this.promos,
    this.defaultPpnType = 0,
    required this.ppnRate,
    this.specialPriceConfig,
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

    SpecialPriceConfigModel? spConfig;
    if (json['special_price_config'] != null &&
        json['special_price_config'] is Map) {
      spConfig = SpecialPriceConfigModel.fromJson(
        Map<String, dynamic>.from(json['special_price_config'] as Map),
      );
    }

    return PosInitialDataModel(
      defaultBranch: branch,
      defaultWarehouse: warehouse,
      paymentMethods: pmList,
      promos: promoList,
      defaultPpnType: ppnType,
      ppnRate: ppn,
      specialPriceConfig: spConfig,
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
  final double? specialPrice;
  double stock;
  final double qrStock;
  final String? unit;
  final String? categoryName;
  final String? imagePath;
  final String? qrcode;
  final bool isKardus;
  final String? qrType;
  final String? wrapperQrcode;
  final List<String> containedQrcodes;

  ProductModel({
    required this.id,
    required this.itemId,
    required this.name,
    this.code,
    this.barcode,
    required this.price,
    this.specialPrice,
    required this.stock,
    this.qrStock = 1.0,
    this.unit,
    this.categoryName,
    this.imagePath,
    this.qrcode,
    this.isKardus = false,
    this.qrType,
    this.wrapperQrcode,
    this.containedQrcodes = const [],
  });

  bool get hasSpecialPrice => specialPrice != null && specialPrice! > 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final parsedId = int.tryParse(
          json['id']?.toString() ??
              json['stock_id']?.toString() ??
              json['item_id']?.toString() ??
              '',
        ) ??
        0;
    final parsedItemId = int.tryParse(
          json['item_id']?.toString() ?? json['id']?.toString() ?? '',
        ) ??
        parsedId;
    return ProductModel(
      id: parsedId,
      itemId: parsedItemId,
      name:
          json['name']?.toString() ?? json['item_name']?.toString() ?? 'Produk',
      code: json['code']?.toString() ?? json['item_code']?.toString(),
      barcode: json['barcode']?.toString() ??
          json['item_barcode']?.toString() ??
          json['qrcode']?.toString(),
      price: double.tryParse(
            json['selling_price']?.toString() ??
                json['price']?.toString() ??
                json['sell_price']?.toString() ??
                '0',
          ) ??
          0.0,
      specialPrice: () {
        final raw = json['special_price'];
        if (raw == null) return null;
        final val = double.tryParse(raw.toString());
        return (val != null && val > 0) ? val : null;
      }(),
      qrStock: double.tryParse(json['remaining_qty']?.toString() ?? '1') ?? 1.0,
      stock: double.tryParse(
            json['total_stock']?.toString() ??
                json['stock']?.toString() ??
                json['remaining_qty']?.toString() ??
                json['qty']?.toString() ??
                '0',
          ) ??
          0.0,
      unit: json['unit']?.toString() ?? json['unit_name']?.toString() ?? 'Pcs',
      categoryName:
          json['category_name']?.toString() ?? json['category']?.toString(),
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
      isKardus: json['is_kardus'] == true ||
          json['qr_type']?.toString().toLowerCase() == 'kardus',
      qrType: json['qr_type']?.toString() ??
          (json['is_kardus'] == true ? 'kardus' : 'satuan'),
      wrapperQrcode: json['wrapper_qrcode']?.toString(),
      containedQrcodes: () {
        final rawList = json['contained_qrcodes'];
        if (rawList is List) {
          return rawList.map((e) => e.toString()).toList();
        }
        return <String>[];
      }(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'name': name,
        'code': code,
        'barcode': barcode,
        'price': price,
        'special_price': specialPrice,
        'stock': stock,
        'remaining_qty': qrStock,
        'unit': unit,
        'category_name': categoryName,
        'image_path': imagePath,
        'qrcode': qrcode,
        'is_kardus': isKardus,
        'qr_type': qrType,
        'wrapper_qrcode': wrapperQrcode,
        'contained_qrcodes': containedQrcodes,
      };
}

class CartItemModel {
  final ProductModel product;
  int qty;
  double price;
  double discount;
  final bool isSpecialPrice;
  final List<String> qrcodes;
  final List<String> wrapperQrcodes;

  CartItemModel({
    required this.product,
    this.qty = 1,
    required this.price,
    this.discount = 0,
    this.isSpecialPrice = false,
    String qrcode = '',
    List<String>? qrcodes,
    List<String>? wrapperQrcodes,
  })  : qrcodes = qrcodes != null
            ? List<String>.from(qrcodes)
            : (!product.isKardus && qrcode.isNotEmpty ? [qrcode] : <String>[]),
        wrapperQrcodes = wrapperQrcodes != null
            ? List<String>.from(wrapperQrcodes)
            : (product.isKardus
                ? (qrcode.isNotEmpty
                    ? [qrcode]
                    : (product.wrapperQrcode != null &&
                            product.wrapperQrcode!.isNotEmpty
                        ? [product.wrapperQrcode!]
                        : (product.qrcode != null && product.qrcode!.isNotEmpty
                            ? [product.qrcode!]
                            : <String>[])))
                : <String>[]);

  bool get isKardus => product.isKardus;

  List<String> get activeCodes => isKardus ? wrapperQrcodes : qrcodes;

  String get qrcode => activeCodes.isNotEmpty ? activeCodes.first : '';
  set qrcode(String val) {
    if (val.isEmpty) {
      activeCodes.clear();
    } else {
      if (!activeCodes.contains(val)) {
        activeCodes.add(val);
      }
    }
  }

  double get subTotal => (price * qty) - discount;

  Map<String, dynamic> toInvoiceItemJson() {
    if (isKardus) {
      final List<String> finalWrapperQrs = wrapperQrcodes.isNotEmpty
          ? wrapperQrcodes
          : (product.wrapperQrcode != null && product.wrapperQrcode!.isNotEmpty
              ? [product.wrapperQrcode!]
              : (product.qrcode != null && product.qrcode!.isNotEmpty
                  ? [product.qrcode!]
                  : <String>[]));
      final joinedWrapperQr =
          finalWrapperQrs.isNotEmpty ? finalWrapperQrs.join(', ') : null;

      return {
        'item_id': product.itemId,
        'item_name': product.name,
        'qty': qty,
        'price': price,
        'discount': discount,
        'sub_total': subTotal,
        'is_kardus': true,
        'qrcode': null, // Tidak termasuk di qrcode ketika yang discan kardus
        'wrapper_qrcode': joinedWrapperQr,
        'wrapper_qrcodes': finalWrapperQrs,
        'contained_qrcodes': product.containedQrcodes,
        if (product.unit != null) 'unit': product.unit,
        if (product.code != null) 'code': product.code,
      };
    } else {
      final List<String> finalQrs = qrcodes.isNotEmpty
          ? qrcodes
          : (product.qrcode != null && product.qrcode!.isNotEmpty
              ? [product.qrcode!]
              : <String>[]);
      final joinedQr = finalQrs.isNotEmpty ? finalQrs.join(', ') : null;

      return {
        'item_id': product.itemId,
        'item_name': product.name,
        'qty': qty,
        'price': price,
        'discount': discount,
        'sub_total': subTotal,
        'is_kardus': false,
        'qrcode': joinedQr,
        'qrcodes': finalQrs,
        'wrapper_qrcode': null,
        if (product.unit != null) 'unit': product.unit,
        if (product.code != null) 'code': product.code,
      };
    }
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
  final String? wrapperQrcode;
  final String? unit;
  final String? itemCode;
  final bool isKardus;

  InvoiceItemModel({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.price,
    required this.discount,
    required this.subTotal,
    this.qrcode,
    this.wrapperQrcode,
    this.unit,
    this.itemCode,
    this.isKardus = false,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    final itemObj = json['item'] is Map<String, dynamic>
        ? json['item'] as Map<String, dynamic>
        : null;
    final unitObj = itemObj?['unit'] is Map<String, dynamic>
        ? itemObj!['unit'] as Map<String, dynamic>
        : (json['unit'] is Map<String, dynamic>
            ? json['unit'] as Map<String, dynamic>
            : null);

    // Deteksi kardus dari field is_kardus atau dari ada tidaknya wrapper_qrcode
    final rawIsKardus = json['is_kardus'];
    final hasWrapperQrcode =
        (json['wrapper_qrcode']?.toString() ?? '').trim().isNotEmpty ||
            (json['wrapper_qrcodes']?.toString() ?? '').trim().isNotEmpty;
    final bool isKardus = rawIsKardus == true ||
        rawIsKardus == 1 ||
        rawIsKardus?.toString() == '1' ||
        rawIsKardus?.toString().toLowerCase() == 'true' ||
        (rawIsKardus == null && hasWrapperQrcode);

    // qrcode: ambil dari singular, atau dari plural (qrcodes = GROUP_CONCAT result)
    final String? qrcodeVal = isKardus
        ? null
        : (json['qrcode']?.toString().trim().isNotEmpty == true
            ? json['qrcode']?.toString()
            : (json['qrcodes']?.toString().trim().isNotEmpty == true
                ? json['qrcodes']?.toString()
                : null));

    // wrapper_qrcode: ambil dari singular, atau dari plural
    final String? wrapperQrcodeVal = !isKardus
        ? null
        : (json['wrapper_qrcode']?.toString().trim().isNotEmpty == true
            ? json['wrapper_qrcode']?.toString()
            : (json['wrapper_qrcodes']?.toString().trim().isNotEmpty == true
                ? json['wrapper_qrcodes']?.toString()
                : null));

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
      qrcode: qrcodeVal,
      wrapperQrcode: wrapperQrcodeVal,
      unit: json['unit_measure_name']?.toString() ??
          json['unit_name']?.toString() ??
          unitObj?['unit_measure_name']?.toString() ??
          (json['unit'] is String ? json['unit']?.toString() : null) ??
          'Pcs',
      itemCode: json['item_code']?.toString() ??
          itemObj?['item_code']?.toString() ??
          json['code']?.toString(),
      isKardus: isKardus,
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
  final String? voidByName;
  final String? cashierName;
  final List<InvoiceItemModel> items;
  final SpecialPriceConfigModel? specialPriceConfig;

  bool get isVoid => status == 0;

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
    this.voidByName,
    this.items = const [],
    this.specialPriceConfig,
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
    String? voidByName,
    List<InvoiceItemModel>? items,
    SpecialPriceConfigModel? specialPriceConfig,
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
      voidByName: voidByName ?? this.voidByName,
      items: items ?? this.items,
      specialPriceConfig: specialPriceConfig ?? this.specialPriceConfig,
    );
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final itemList = <InvoiceItemModel>[];
    final rawItems = json['group_details'] ?? json['items'] ?? json['details'];
    if (rawItems is List) {
      final parsedItems = <InvoiceItemModel>[];
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          parsedItems.add(InvoiceItemModel.fromJson(item));
        }
      }

      // Grouping gabungan (itemId + price + isKardus) agar barang yang sama
      // selalu terkonsolidasi menjadi 1 baris, dengan qty terakumulasi & qrcode tergabung
      final groupedMap = <String, InvoiceItemModel>{};
      for (final item in parsedItems) {
        final key = '${item.itemId}_${item.price}_${item.isKardus}';
        if (!groupedMap.containsKey(key)) {
          groupedMap[key] = item;
        } else {
          final existing = groupedMap[key]!;

          // Gabungkan QR Code satuan (distinct)
          final existingQrs = (existing.qrcode ?? '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toSet();
          if (item.qrcode != null && item.qrcode!.trim().isNotEmpty) {
            existingQrs.addAll(
              item.qrcode!
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty),
            );
          }
          final mergedQr = existingQrs.isEmpty ? null : existingQrs.join(', ');

          // Gabungkan QR Kemasan kardus (distinct)
          final existingWrappers = (existing.wrapperQrcode ?? '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toSet();
          if (item.wrapperQrcode != null &&
              item.wrapperQrcode!.trim().isNotEmpty) {
            existingWrappers.addAll(
              item.wrapperQrcode!
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty),
            );
          }
          final mergedWrapper =
              existingWrappers.isEmpty ? null : existingWrappers.join(', ');

          groupedMap[key] = InvoiceItemModel(
            itemId: existing.itemId,
            itemName: existing.itemName,
            qty: existing.qty + item.qty,
            price: existing.price,
            discount: existing.discount + item.discount,
            subTotal: existing.subTotal + item.subTotal,
            qrcode: mergedQr,
            wrapperQrcode: mergedWrapper,
            unit: existing.unit,
            itemCode: existing.itemCode,
            isKardus: existing.isKardus,
          );
        }
      }
      itemList.addAll(groupedMap.values);
    }

    final branchObj = json['branch'] is Map<String, dynamic>
        ? json['branch'] as Map<String, dynamic>
        : null;
    final warehouseObj = json['warehouse'] is Map<String, dynamic>
        ? json['warehouse'] as Map<String, dynamic>
        : null;
    final pmObj = json['payment_method'] is Map<String, dynamic>
        ? json['payment_method'] as Map<String, dynamic>
        : null;
    final promoObj = json['promo'] is Map<String, dynamic>
        ? json['promo'] as Map<String, dynamic>
        : null;
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
        (json['created_by'] is String
            ? json['created_by']?.toString()
            : null) ??
        json['created_by_name']?.toString();

    final voidByObj = json['void_by'] is Map<String, dynamic>
        ? json['void_by'] as Map<String, dynamic>
        : (json['voidBy'] is Map<String, dynamic>
            ? json['voidBy'] as Map<String, dynamic>
            : (json['void_by_user'] is Map<String, dynamic>
                ? json['void_by_user'] as Map<String, dynamic>
                : null));

    final parsedVoidByName = json['void_by_name']?.toString() ??
        voidByObj?['name']?.toString() ??
        voidByObj?['username']?.toString() ??
        (json['void_by'] is String ? json['void_by']?.toString() : null);

    return InvoiceModel(
      id: json['id'],
      invoiceNo: json['pos_invoice_code']?.toString() ??
          json['invoice_no']?.toString() ??
          json['invoice_number']?.toString() ??
          json['code']?.toString() ??
          'INV-${json['id']}',
      createdAt:
          json['created_at']?.toString() ?? json['date']?.toString() ?? '',
      status: int.tryParse(json['status']?.toString() ?? '1') ?? 1,
      branchName: json['branch_name']?.toString() ??
          branchObj?['branch_name']?.toString(),
      warehouseName: json['warehouse_name']?.toString() ??
          warehouseObj?['warehouse_name']?.toString(),
      paymentMethodName: json['payment_method_name']?.toString() ??
          pmObj?['method_name']?.toString() ??
          (json['payment_method'] is String
              ? json['payment_method']?.toString()
              : null),
      promoName: json['promo_name']?.toString() ??
          promoObj?['promo_name']?.toString() ??
          promoObj?['name']?.toString() ??
          (json['promo'] is String ? json['promo']?.toString() : null),
      cashierName: parsedCashierName,
      subTotal: double.tryParse(json['sub_total']?.toString() ?? '0') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0,
      ppn: double.tryParse(
              json['ppn']?.toString() ?? json['tax']?.toString() ?? '0') ??
          0.0,
      grandTotal:
          double.tryParse(json['grand_total']?.toString() ?? '0') ?? 0.0,
      cash: double.tryParse(json['cash']?.toString() ?? '0') ?? 0.0,
      change: double.tryParse(json['change']?.toString() ?? '0') ?? 0.0,
      voidDesc: json['void_desc']?.toString(),
      voidAt: json['void_date']?.toString() ?? json['void_at']?.toString(),
      voidByName: parsedVoidByName,
      items: itemList,
      specialPriceConfig: json['special_price_config'] != null &&
              json['special_price_config'] is Map
          ? SpecialPriceConfigModel.fromJson(
              Map<String, dynamic>.from(json['special_price_config'] as Map),
            )
          : null,
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
      itemName:
          json['item_name']?.toString() ?? json['name']?.toString() ?? 'Barang',
      totalQtyIn: double.tryParse(json['total_in']?.toString() ??
              json['qty_in']?.toString() ??
              '0') ??
          0.0,
      totalQtyOut: double.tryParse(json['total_out']?.toString() ??
              json['qty_out']?.toString() ??
              '0') ??
          0.0,
      currentStock: double.tryParse(json['current_stock']?.toString() ??
              json['stock']?.toString() ??
              '0') ??
          0.0,
      totalValue:
          double.tryParse(json['total_value']?.toString() ?? '0') ?? 0.0,
      totalTransactions: int.tryParse(json['total_transactions']?.toString() ??
              json['total']?.toString() ??
              '0') ??
          0,
      totalRows: int.tryParse(json['total_rows']?.toString() ??
              json['rows']?.toString() ??
              '0') ??
          0,
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
      type: json['type']?.toString() ??
          json['transaction_type']?.toString() ??
          'Transaksi',
      refNo: json['ref_no']?.toString() ?? json['reference']?.toString() ?? '-',
      qtyIn: double.tryParse(json['qty_in']?.toString() ?? '0') ?? 0.0,
      qtyOut: double.tryParse(json['qty_out']?.toString() ?? '0') ?? 0.0,
      balance: double.tryParse(json['balance']?.toString() ??
              json['stock_after']?.toString() ??
              '0') ??
          0.0,
      notes: json['notes']?.toString() ?? json['description']?.toString(),
    );
  }
}
