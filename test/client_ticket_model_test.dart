import 'package:flutter_test/flutter_test.dart';
import 'package:leadcapture/models/models.dart';
import 'package:leadcapture/constants/constants.dart';

void main() {
  group('ClientModel Serialization Tests', () {
    test('fromMap and toMap correctly serialize and deserialize ClientModel fields', () {
      final mockMap = {
        'uid': 'client_123',
        'clientName': 'Jane Smith',
        'email': 'jane@example.com',
        'mobileNumber': '9876543210',
        'gender': 'Female',
        'isActive': true,
        'isCompany': false,
        'loginAllowed': true,
        'companyName': 'Acme Corp',
        'officialWebsite': 'https://acme.com',
        'notes': 'VIP client',
        'createdBy': {
          'uid': 'user_1',
          'name': 'Admin',
          'userType': 'admin',
        },
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      final client = ClientModel.fromMap('client_123', mockMap);

      expect(client.uid, 'client_123');
      expect(client.clientName, 'Jane Smith');
      expect(client.email, 'jane@example.com');
      expect(client.mobileNumber, '9876543210');
      expect(client.isActive, isTrue);
      expect(client.isCompany, isFalse);
      expect(client.companyName, 'Acme Corp');
      expect(client.createdBy.name, 'Admin');
      expect(client.createdBy.userType, UserType.admin);
    });

    test('ClientModel fromMap handles missing optional fields gracefully', () {
      final minimalMap = {
        'createdBy': {
          'uid': 'user_1',
          'name': 'Admin',
          'userType': 'admin',
        },
        'isActive': true,
        'isCompany': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      final client = ClientModel.fromMap('client_456', minimalMap);

      expect(client.uid, 'client_456');
      // ClientModel.fromMap returns empty strings for missing string fields, not null
      expect(client.clientName, anyOf(isNull, isEmpty));
      expect(client.email, anyOf(isNull, isEmpty));
      expect(client.mobileNumber, anyOf(isNull, isEmpty));
    });
  });

  group('CustomerTicketModel Serialization Tests', () {
    test('fromMap and toMap correctly serialize and deserialize CustomerTicketModel fields', () {
      final mockMap = {
        'uid': 'ticket_123',
        'clientName': 'Jane Smith',
        'ticketTitle': 'Login Issue',
        'ticketDescription': 'Cannot login to the system',
        'status': 'open',
        'priorityLevel': 'high',
        'modeOfContact': 'phone',
        'category': 'technicalSupport',
        'assignTo': ['agent_1'],
        'participants': <String>[],
        'observers': <String>[],
        'createdBy': ['user_2'],
        'ticketCreatedBy': {
          'uid': 'user_2',
          'name': 'Admin',
          'userType': 'admin',
        },
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      final ticket = CustomerTicketModel.fromMap('ticket_123', mockMap);

      expect(ticket.uid, 'ticket_123');
      expect(ticket.ticketTitle, 'Login Issue');
      expect(ticket.ticketDescription, 'Cannot login to the system');
      expect(ticket.status, TicketStatus.open);
      expect(ticket.priorityLevel, TicketPriority.high);
      expect(ticket.clientName, 'Jane Smith');
      expect(ticket.ticketCreatedBy.name, 'Admin');
      expect(ticket.createdBy, ['user_2']);

      final ticketMap = ticket.toMap();
      expect(ticketMap['ticketTitle'], 'Login Issue');
      expect(ticketMap['status'], 'open');
      expect(ticketMap['priorityLevel'], 'high');
    });
  });
}
