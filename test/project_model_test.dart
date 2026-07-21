import 'package:flutter_test/flutter_test.dart';
import 'package:leadcapture/models/models.dart';
import 'package:leadcapture/constants/constants.dart';

void main() {
  group('ProjectModel Serialization Tests', () {
    test('fromMap and toMap correctly serialize and deserialize ProjectModel fields', () {
      final mockMap = {
        'uid': 'proj_123',
        'projectName': 'New App Development',
        'projectDescription': 'Building a CRM app',
        'projectOwner': 'owner_id',
        'teamLead': 'lead_id',
        'members': ['user1', 'user2'],
        'client': 'client_id',
        'projectCode': 'PRJ-123',
        'category': 'Software',
        'createdBy': {
          'uid': 'user_1',
          'name': 'Admin',
          'userType': 'admin',
        },
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      final project = ProjectModel.fromMap('proj_123', mockMap);

      expect(project.uid, 'proj_123');
      expect(project.projectName, 'New App Development');
      expect(project.projectDescription, 'Building a CRM app');
      expect(project.members, ['user1', 'user2']);
      expect(project.createdBy.name, 'Admin');

      final projectMap = project.toMap();
      expect(projectMap['projectName'], 'New App Development');
      expect(projectMap['projectCode'], 'PRJ-123');
    });
  });
}
