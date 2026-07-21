import 'package:flutter_test/flutter_test.dart';
import 'package:leadcapture/models/models.dart';
import 'package:leadcapture/constants/constants.dart';

void main() {
  group('DealModel Serialization Tests', () {
    test('fromMap and toMap correctly serialize and deserialize basic fields', () {
      final mockMap = {
        'uid': 'deal_123',
        'dealName': 'Big Deal',
        'dealEmail': 'contact@bigdeal.com',
        'dealValue': 50000.0,
        'allowFollowUp': true,
        'dealStatus': 'Negotiation',
        'notes': 'Some notes',
        'attachments': [],
        'createdBy': {
          'uid': 'user_1',
          'name': 'Sales Rep',
          'userType': 'employee',
        },
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      final deal = DealModel.fromMap('deal_123', mockMap);

      expect(deal.uid, 'deal_123');
      expect(deal.dealName, 'Big Deal');
      expect(deal.dealValue, 50000.0);
      expect(deal.createdBy.name, 'Sales Rep');
      expect(deal.allowFollowUp, isTrue);
      expect(deal.dealEmail, 'contact@bigdeal.com');

      final dealMap = deal.toMap();
      expect(dealMap['uid'], 'deal_123');
      expect(dealMap['dealName'], 'Big Deal');
      expect(dealMap['dealValue'], 50000.0);
    });
  });
}
