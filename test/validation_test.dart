import 'package:flutter_test/flutter_test.dart';
import 'package:leadcapture/utils/src/validation.dart';

void main() {
  // ─────────────────────────────────────────────
  // commonValidation
  // ─────────────────────────────────────────────
  group('commonValidation', () {
    test('returns error when required field is empty', () {
      final result = Validation.commonValidation(
        input: '',
        label: 'Name',
        isReq: true,
      );
      expect(result, 'Name is required');
    });

    test('returns null when field is not required and empty', () {
      final result = Validation.commonValidation(
        input: '',
        label: 'Notes',
        isReq: false,
      );
      expect(result, isNull);
    });

    test('returns null when required field has value', () {
      final result = Validation.commonValidation(
        input: 'John',
        label: 'Name',
        isReq: true,
      );
      expect(result, isNull);
    });

    test('returns error when value is shorter than required length', () {
      final result = Validation.commonValidation(
        input: 'abc',
        label: 'Code',
        length: 6,
        isReq: true,
      );
      expect(result, 'Code must be at least 6 characters long');
    });

    test('returns null when value meets required length', () {
      final result = Validation.commonValidation(
        input: 'abcdef',
        label: 'Code',
        length: 6,
        isReq: true,
      );
      expect(result, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // validEmail
  // ─────────────────────────────────────────────
  group('validEmail', () {
    test('returns error when required and empty', () {
      expect(Validation.validEmail(input: '', isReq: true), 'Email is required');
    });

    test('returns null when not required and empty', () {
      expect(Validation.validEmail(input: ''), isNull);
    });

    test('returns error when email contains spaces', () {
      expect(
        Validation.validEmail(input: 'user @example.com'),
        'Email should not contain spaces',
      );
    });

    test('returns error for invalid email format — missing @', () {
      expect(
        Validation.validEmail(input: 'userexample.com'),
        'Invalid email address',
      );
    });

    test('returns error for invalid email format — missing domain', () {
      expect(
        Validation.validEmail(input: 'user@'),
        'Invalid email address',
      );
    });

    test('returns error for invalid email format — missing TLD', () {
      expect(
        Validation.validEmail(input: 'user@example'),
        'Invalid email address',
      );
    });

    test('returns null for a valid standard email', () {
      expect(Validation.validEmail(input: 'user@example.com'), isNull);
    });

    test('returns null for a valid email with subdomain', () {
      expect(Validation.validEmail(input: 'user@mail.example.org'), isNull);
    });

    test('returns null for a valid email with plus addressing', () {
      expect(Validation.validEmail(input: 'user+tag@example.com'), isNull);
    });

    test('returns null for a valid email with dots in local part', () {
      expect(Validation.validEmail(input: 'first.last@example.co.in'), isNull);
    });

    test('returns error for email with leading space (trimmed)', () {
      // Trim happens inside validEmail, so leading space won't break format
      // but result depends on regex after trim
      final result = Validation.validEmail(input: '  user@example.com');
      expect(result, isNull); // trimmed, valid
    });
  });

  // ─────────────────────────────────────────────
  // passwordValidation
  // ─────────────────────────────────────────────
  group('passwordValidation', () {
    test('returns error when password is too short (< 8 chars)', () {
      expect(
        Validation.passwordValidation(input: 'Ab1!', isReq: true),
        'Must be at least 8 characters long',
      );
    });

    test('returns error when password has no uppercase letter', () {
      expect(
        Validation.passwordValidation(input: 'abcde1!x', isReq: true),
        'Must contain at least one uppercase letter',
      );
    });

    test('returns error when password has no lowercase letter', () {
      expect(
        Validation.passwordValidation(input: 'ABCDE1!X', isReq: true),
        'Must contain at least one lowercase letter',
      );
    });

    test('returns error when password has no special character', () {
      expect(
        Validation.passwordValidation(input: 'Abcde123', isReq: true),
        'Must contain at least one special character',
      );
    });

    test('returns error when password has no digit', () {
      expect(
        Validation.passwordValidation(input: 'Abcde!@#', isReq: true),
        'Must contain at least one number',
      );
    });

    test('returns null for a strong valid password', () {
      expect(
        Validation.passwordValidation(input: 'Strong@123', isReq: true),
        isNull,
      );
    });

    test('returns null for null input (no crash)', () {
      expect(
        Validation.passwordValidation(input: null, isReq: false),
        isNull,
      );
    });
  });

  // ─────────────────────────────────────────────
  // validMobileNumber
  // ─────────────────────────────────────────────
  group('validMobileNumber', () {
    test('returns error when required and empty', () {
      expect(
        Validation.validMobileNumber(input: '', isReq: true),
        'Mobile number is required',
      );
    });

    test('returns null when not required and empty', () {
      expect(Validation.validMobileNumber(input: ''), isNull);
    });

    test('returns error when mobile has spaces', () {
      expect(
        Validation.validMobileNumber(input: '98765 43210'),
        'Mobile number should not contain spaces',
      );
    });

    test('returns error when mobile contains letters', () {
      expect(
        Validation.validMobileNumber(input: '9876543abc'),
        'Mobile number must contain only digits',
      );
    });

    test('returns error when mobile is less than 10 digits', () {
      expect(
        Validation.validMobileNumber(input: '987654321'),
        'Mobile number must be 10 digits',
      );
    });

    test('returns error when mobile is more than 10 digits', () {
      expect(
        Validation.validMobileNumber(input: '98765432101'),
        'Mobile number must be 10 digits',
      );
    });

    test('returns error when mobile does not start with 6–9 (invalid Indian)', () {
      expect(
        Validation.validMobileNumber(input: '1234567890'),
        'Invalid mobile number',
      );
    });

    test('returns null for a valid Indian mobile number starting with 9', () {
      expect(Validation.validMobileNumber(input: '9876543210'), isNull);
    });

    test('returns null for a valid Indian mobile number starting with 6', () {
      expect(Validation.validMobileNumber(input: '6543219870'), isNull);
    });
  });

  // ─────────────────────────────────────────────
  // validName
  // ─────────────────────────────────────────────
  group('validName', () {
    test('returns error when required and empty', () {
      expect(Validation.validName(input: ''), 'Name is required');
    });

    test('returns null when not required and empty', () {
      expect(Validation.validName(input: '', isReq: false), isNull);
    });

    test('returns error when name contains digits', () {
      expect(
        Validation.validName(input: 'John123'),
        'Name must contain only alphabets',
      );
    });

    test('returns error when name contains special characters', () {
      expect(
        Validation.validName(input: 'John@Doe'),
        'Name must contain only alphabets',
      );
    });

    test('returns null for valid name with spaces', () {
      expect(Validation.validName(input: 'John Doe'), isNull);
    });

    test('uses custom label in error message', () {
      expect(
        Validation.validName(input: '', label: 'Full Name'),
        'Full Name is required',
      );
    });
  });

  // ─────────────────────────────────────────────
  // validUrl
  // ─────────────────────────────────────────────
  group('validUrl', () {
    test('returns error when required and empty', () {
      expect(Validation.validUrl(input: '', isReq: true), 'Url is required');
    });

    test('returns null when not required and empty', () {
      expect(Validation.validUrl(input: ''), isNull);
    });

    test('returns error for invalid URL — no protocol', () {
      expect(Validation.validUrl(input: 'example.com'), 'Invalid url');
    });

    test('returns error for invalid URL — ftp protocol', () {
      expect(Validation.validUrl(input: 'ftp://example.com'), 'Invalid url');
    });

    test('returns null for valid http URL', () {
      expect(Validation.validUrl(input: 'http://example.com'), isNull);
    });

    test('returns null for valid https URL', () {
      expect(Validation.validUrl(input: 'https://www.example.co.in'), isNull);
    });
  });

  // ─────────────────────────────────────────────
  // validAddress
  // ─────────────────────────────────────────────
  group('validAddress', () {
    test('returns error when required and empty', () {
      expect(Validation.validAddress(input: '', isReq: true), 'Address is required');
    });

    test('returns null when not required and empty', () {
      expect(Validation.validAddress(input: ''), isNull);
    });

    test('returns error when address exceeds 150 characters', () {
      final longAddress = 'A' * 151;
      expect(
        Validation.validAddress(input: longAddress),
        'Address is too long (max 150 characters)',
      );
    });

    test('returns error when address contains invalid characters', () {
      expect(
        Validation.validAddress(input: 'Main St @ Block*5'),
        'Invalid characters in address',
      );
    });

    test('returns null for valid address', () {
      expect(Validation.validAddress(input: '12, Main St, Block-5/A'), isNull);
    });
  });

  // ─────────────────────────────────────────────
  // validGstVat
  // ─────────────────────────────────────────────
  group('validGstVat', () {
    test('returns error when required and empty', () {
      expect(
        Validation.validGstVat(input: '', isReq: true),
        'GST/VAT number is required',
      );
    });

    test('returns null when not required and empty', () {
      expect(Validation.validGstVat(input: ''), isNull);
    });

    test('returns error when GST contains special characters', () {
      expect(
        Validation.validGstVat(input: '27AAPFU0939F1Z@'),
        'GST/VAT must contain only alphanumeric characters',
      );
    });

    test('returns null for a valid alphanumeric GST number', () {
      expect(Validation.validGstVat(input: '27AAPFU0939F1Z5'), isNull);
    });
  });

  // ─────────────────────────────────────────────
  // validPostalCode
  // ─────────────────────────────────────────────
  group('validPostalCode', () {
    test('returns error when required and empty', () {
      expect(
        Validation.validPostalCode(input: '', isReq: true),
        'Postal code is required',
      );
    });

    test('returns null when not required and empty', () {
      expect(Validation.validPostalCode(input: ''), isNull);
    });

    test('returns error when postal code is less than 6 digits', () {
      expect(
        Validation.validPostalCode(input: '40001'),
        'Invalid Indian postal code (must be 6 digits)',
      );
    });

    test('returns error when postal code is more than 6 digits', () {
      expect(
        Validation.validPostalCode(input: '4000011'),
        'Invalid Indian postal code (must be 6 digits)',
      );
    });

    test('returns error when postal code starts with 0', () {
      expect(
        Validation.validPostalCode(input: '012345'),
        'Invalid Indian postal code (must be 6 digits)',
      );
    });

    test('returns error when postal code contains letters', () {
      expect(
        Validation.validPostalCode(input: '4000AB'),
        'Invalid Indian postal code (must be 6 digits)',
      );
    });

    test('returns null for a valid Indian postal code', () {
      expect(Validation.validPostalCode(input: '400001'), isNull);
    });

    test('returns null for a valid postal code starting with 1', () {
      expect(Validation.validPostalCode(input: '110001'), isNull);
    });
  });
}
