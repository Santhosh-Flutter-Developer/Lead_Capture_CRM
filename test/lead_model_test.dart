import 'package:flutter_test/flutter_test.dart';
import 'package:leadcapture/models/models.dart';
import 'package:leadcapture/constants/constants.dart';

void main() {
  group('LeadModel Serialization Tests', () {
    test('fromMap and toMap create valid model and map respectively', () {
      final mockMap = {
        'uid': 'lead_123',
        'leadName': 'John Doe',
        'leadEmail': 'john@example.com',
        'leadSource': {
          'uid': 'source_1',
          'name': 'Website',
        },
        'leadCategory': 'New',
        'leadPriority': 'High',
        'leadValue': 1000.0,
        'leadStatus': 'Contacted',
        'createdBy': {
          'uid': 'user_1',
          'name': 'Admin',
          'userType': 'admin',
        },
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      // Test fromMap
      final lead = LeadModel.fromMap('lead_123', mockMap);

      expect(lead.uid, 'lead_123');
      expect(lead.leadName, 'John Doe');
      expect(lead.leadEmail, 'john@example.com');
      expect(lead.leadPriority, 'High');
      expect(lead.leadValue, 1000.0);
      expect(lead.createdBy.name, 'Admin');
      expect(lead.createdBy.userType, UserType.admin);

      // Test toMap
      final leadMap = lead.toMap();
      expect(leadMap['uid'], 'lead_123');
      expect(leadMap['leadName'], 'John Doe');
      expect(leadMap['leadEmail'], 'john@example.com');
      expect(leadMap['leadCategory'], 'New');
      expect(leadMap['leadPriority'], 'High');
      expect(leadMap['createdBy']['name'], 'Admin');
    });
  });
}
