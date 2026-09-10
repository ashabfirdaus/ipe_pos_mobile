import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_mobile_pos/core/models/pos_models.dart';
import 'package:ipe_mobile_pos/core/services/api_service.dart';
import 'package:ipe_mobile_pos/core/services/storage_service.dart';
import 'package:ipe_mobile_pos/core/utils/currency_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('POS Invoice & Cart Models Test', () {
    test('CartItemModel toInvoiceItemJson includes all required details', () {
      final product = ProductModel(
        id: 317,
        itemId: 317,
        name: 'WEMEAL - TUNA BALADO (KOTAK)',
        code: 'WML-TB-01',
        price: 50000,
        stock: 10,
        unit: 'Pcs',
        qrcode: '2608104652',
      );

      final cartItem = CartItemModel(
        product: product,
        qty: 2,
        price: 50000,
        discount: 5000,
        qrcode: '2608104652',
      );

      final json = cartItem.toInvoiceItemJson();

      expect(json['item_id'], 317);
      expect(json['item_name'], 'WEMEAL - TUNA BALADO (KOTAK)');
      expect(json['qty'], 2);
      expect(json['price'], 50000);
      expect(json['discount'], 5000);
      expect(json['sub_total'], 95000);
      expect(json['qrcode'], '2608104652');
      expect(json['unit'], 'Pcs');
      expect(json['code'], 'WML-TB-01');
    });

    test('InvoiceModel.fromJson correctly parses server response with details array', () {
      final serverResponse = {
        'id': 11,
        'pos_invoice_code': 'POS-260908-0001',
        'branch_id': 4,
        'warehouse_id': 8,
        'date': '2026-09-08',
        'sub_total': '100000.00',
        'discount': '0.00',
        'ppn': '0.00',
        'grand_total': '100000.00',
        'cash': '100000.00',
        'change': '0.00',
        'status': '1',
        'details': [
          {
            'id': 32,
            'pos_invoice_id': 11,
            'item_id': 317,
            'unit_measure_id': 3,
            'qrcode': '2608104652',
            'qty': '1.00',
            'price': '50000.00',
            'discount': '0.00',
            'sub_total': '50000.00',
            'item': {
              'id': 317,
              'item_name': 'WEMEAL - TUNA BALADO (KOTAK)',
              'item_code': '02',
              'unit': {
                'id': 3,
                'unit_measure_name': 'Pcs',
              },
            },
          },
          {
            'id': 33,
            'pos_invoice_id': 11,
            'item_id': 313,
            'unit_measure_id': 3,
            'qrcode': '04AG000884',
            'qty': '1.00',
            'price': '50000.00',
            'discount': '0.00',
            'sub_total': '50000.00',
            'item': {
              'id': 313,
              'item_name': 'WEMEAL - OPOR AYAM (KOTAK)',
              'item_code': '04',
              'unit': {
                'id': 3,
                'unit_measure_name': 'Pcs',
              },
            },
          }
        ],
        'branch': {
          'id': 4,
          'branch_name': 'Surabaya',
        },
        'warehouse': {
          'id': 8,
          'warehouse_name': 'Meiko 5',
        },
        'payment_method': {
          'id': 1,
          'method_name': 'QRIS',
        },
      };

      final invoice = InvoiceModel.fromJson(serverResponse);

      expect(invoice.id, 11);
      expect(invoice.invoiceNo, 'POS-260908-0001');
      expect(invoice.grandTotal, 100000.0);
      expect(invoice.branchName, 'Surabaya');
      expect(invoice.warehouseName, 'Meiko 5');
      expect(invoice.paymentMethodName, 'QRIS');
      expect(invoice.items.length, 2);

      expect(invoice.items[0].itemId, 317);
      expect(invoice.items[0].itemName, 'WEMEAL - TUNA BALADO (KOTAK)');
      expect(invoice.items[0].qty, 1);
      expect(invoice.items[0].price, 50000.0);
      expect(invoice.items[0].qrcode, '2608104652');
      expect(invoice.items[0].unit, 'Pcs');

      expect(invoice.items[1].itemId, 313);
      expect(invoice.items[1].itemName, 'WEMEAL - OPOR AYAM (KOTAK)');
      expect(invoice.items[1].qty, 1);
      expect(invoice.items[1].price, 50000.0);
      expect(invoice.items[1].qrcode, '04AG000884');
      expect(invoice.items[1].unit, 'Pcs');
    });

    test('CurrencyFormatter formats UTC and local date string into Indonesian time (WIB)', () {
      // 1. ISO 8601 UTC string (from Laravel backend created_at)
      final utcIso = '2026-09-10T09:04:38.000000Z';
      final formattedUtc = CurrencyFormatter.formatDate(utcIso);
      expect(formattedUtc.contains('10 Sep 2026'), isTrue);
      expect(formattedUtc.contains('16:04'), isTrue);
      expect(formattedUtc.contains('WIB'), isTrue);

      // 2. Date only format (e.g. from transaction date)
      final dateOnly = '2026-09-10';
      final formattedDateOnly = CurrencyFormatter.formatDate(dateOnly);
      expect(formattedDateOnly, '10 Sep 2026');

      // 3. Null or empty
      expect(CurrencyFormatter.formatDate(null), '-');
      expect(CurrencyFormatter.formatDate(''), '-');

      // 4. DateTime now format
      final formattedNow = CurrencyFormatter.formatDateTime(DateTime.now());
      expect(formattedNow.contains('WIB'), isTrue);
    });

    test('UserModel correctly extracts role_name instead of object role', () {
      // 1. Role as Map/Object (Laravel relation)
      final userWithRoleObj = UserModel.fromJson({
        'id': 1,
        'name': 'Budi',
        'username': 'budi',
        'role': {
          'id': 2,
          'role_name': 'Kasir Utama',
          'name': 'Kasir Utama',
        },
      });
      expect(userWithRoleObj.role, 'Kasir Utama');
      expect(userWithRoleObj.roleName, 'Kasir Utama');

      // 2. Role as direct role_name string
      final userWithRoleName = UserModel.fromJson({
        'id': 2,
        'name': 'Admin',
        'username': 'admin',
        'role_name': 'Administrator',
      });
      expect(userWithRoleName.role, 'Administrator');
      expect(userWithRoleName.roleName, 'Administrator');

      // 3. Role as cached string containing object representation
      final userWithCachedObjStr = UserModel.fromJson({
        'id': 3,
        'name': 'Staf',
        'username': 'staf',
        'role': '{id: 3, role_name: Supervisor}',
      });
      expect(userWithCachedObjStr.role, 'Supervisor');
      expect(userWithCachedObjStr.roleName, 'Supervisor');

      // 4. Role as List of role objects
      final userWithRoleList = UserModel.fromJson({
        'id': 4,
        'name': 'Manager',
        'username': 'manager',
        'roles': [
          {'id': 4, 'role_name': 'Store Manager'}
        ],
      });
      expect(userWithRoleList.role, 'Store Manager');
      expect(userWithRoleList.roleName, 'Store Manager');
    });

    test('InvoiceModel.fromJson parses cashier information from various relations/keys', () {
      // Case 1: user relation
      final inv1 = InvoiceModel.fromJson({
        'id': 1,
        'pos_invoice_code': 'INV-001',
        'user': {'id': 10, 'name': 'Kasir Andi'},
      });
      expect(inv1.cashierName, 'Kasir Andi');

      // Case 2: cashier relation
      final inv2 = InvoiceModel.fromJson({
        'id': 2,
        'pos_invoice_code': 'INV-002',
        'cashier': {'id': 12, 'name': 'Kasir Budi'},
      });
      expect(inv2.cashierName, 'Kasir Budi');

      // Case 3: cashier_name direct string
      final inv3 = InvoiceModel.fromJson({
        'id': 3,
        'pos_invoice_code': 'INV-003',
        'cashier_name': 'Siti Rahma',
      });
      expect(inv3.cashierName, 'Siti Rahma');

      // Case 4: creator relation
      final inv4 = InvoiceModel.fromJson({
        'id': 4,
        'pos_invoice_code': 'INV-004',
        'creator': {'name': 'Dewi'},
      });
      expect(inv4.cashierName, 'Dewi');

      // Case 5: created_by relation with full_name
      final inv5 = InvoiceModel.fromJson({
        'id': 5,
        'pos_invoice_code': 'INV-005',
        'created_by': {'full_name': 'Ahmad Dahlan'},
      });
      expect(inv5.cashierName, 'Ahmad Dahlan');

      // Case 6: created_by_user relation
      final inv6 = InvoiceModel.fromJson({
        'id': 6,
        'pos_invoice_code': 'INV-006',
        'created_by_user': {'username': 'kasir_cabang'},
      });
      expect(inv6.cashierName, 'kasir_cabang');
    });

    test('StorageService.getCashierName retrieves name from cached user session', () async {
      await StorageService.saveUserData('{"id": 1, "name": "Budi Santoso", "username": "budis"}');
      final cashier = await StorageService.getCashierName();
      expect(cashier, 'Budi Santoso');
    });

    test('ApiService handleUnauthenticated immediately clears session and token', () async {
      await StorageService.saveAuthToken('dummy_expired_token');
      expect(await StorageService.hasValidToken(), isTrue);

      ApiService.handleUnauthenticated();
      // Allow microtask to run
      await Future.delayed(const Duration(milliseconds: 50));

      expect(await StorageService.hasValidToken(), isFalse);
    });
  });
}
