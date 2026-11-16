// Emergency numbers from DEVELOPMENT_PLAN.md section 3.2.
// `confirmed` is false until an official page has been read for the number;
// release is blocked while any shown number is unconfirmed (plan 10.7).
class EmergencyNumber {
  const EmergencyNumber(this.number, this.service, {required this.confirmed});

  final String number;
  final String service;
  final bool confirmed;
}

abstract final class EmergencyNumbers {
  static const medical = EmergencyNumber(
    '1669',
    'Emergency medical',
    confirmed: true,
  );
  static const police = EmergencyNumber('191', 'Police', confirmed: false);
  static const ddpm = EmergencyNumber(
    '1784',
    'Disaster hotline (DDPM)',
    confirmed: true,
  );

  static const sos = [medical, police, ddpm];
}
