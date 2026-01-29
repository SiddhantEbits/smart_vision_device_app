import 'package:flutter_test/flutter_test.dart';
import '../lib/data/repositories/local_storage_service.dart';

void main() {
  group('WhatsApp Phone Number Storage Tests', () {
    late LocalStorageService storageService;

    setUpAll(() async {
      // Initialize GetStorage for testing
      storageService = LocalStorageService.instance;
      await storageService.init();
    });

    setUp(() async {
      // Clear WhatsApp config before each test
      await storageService.saveWhatsAppConfig(
        alertEnable: false,
        phoneNumbers: [],
      );
    });

    test('Should save and retrieve WhatsApp phone numbers', () async {
      // Arrange
      const testPhoneNumber = '+91 98765 43210';

      // Act
      await storageService.addWhatsAppPhoneNumber(testPhoneNumber);
      final retrievedNumbers = storageService.getWhatsAppPhoneNumbers();

      // Assert
      expect(retrievedNumbers, contains(testPhoneNumber));
      expect(retrievedNumbers.length, 1);
    });

    test('Should enable WhatsApp alerts', () async {
      // Act
      await storageService.setWhatsAppAlertsEnabled(true);
      final isEnabled = storageService.getWhatsAppAlertsEnabled();

      // Assert
      expect(isEnabled, isTrue);
    });

    test('Should handle multiple phone numbers', () async {
      // Arrange
      const phone1 = '+91 98765 43210';
      const phone2 = '+1 555 123 4567';

      // Act
      await storageService.addWhatsAppPhoneNumber(phone1);
      await storageService.addWhatsAppPhoneNumber(phone2);
      final retrievedNumbers = storageService.getWhatsAppPhoneNumbers();

      // Assert
      expect(retrievedNumbers.length, 2);
      expect(retrievedNumbers, contains(phone1));
      expect(retrievedNumbers, contains(phone2));
    });

    test('Should remove duplicate phone numbers', () async {
      // Arrange
      const phoneNumber = '+91 98765 43210';

      // Act
      await storageService.addWhatsAppPhoneNumber(phoneNumber);
      await storageService.addWhatsAppPhoneNumber(phoneNumber); // Add same number again
      final retrievedNumbers = storageService.getWhatsAppPhoneNumbers();

      // Assert
      expect(retrievedNumbers.length, 1);
      expect(retrievedNumbers.first, phoneNumber);
    });

    test('Should remove phone numbers', () async {
      // Arrange
      const phone1 = '+91 98765 43210';
      const phone2 = '+1 555 123 4567';
      await storageService.addWhatsAppPhoneNumber(phone1);
      await storageService.addWhatsAppPhoneNumber(phone2);

      // Act
      await storageService.removeWhatsAppPhoneNumber(phone1);
      final retrievedNumbers = storageService.getWhatsAppPhoneNumbers();

      // Assert
      expect(retrievedNumbers.length, 1);
      expect(retrievedNumbers.first, phone2);
      expect(retrievedNumbers, isNot(contains(phone1)));
    });
  });
}
