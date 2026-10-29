/// Language sample fixtures for testing ESC/POS rendering and encoding.
///
/// Each language includes:
/// - A simple common phrase (e.g. "Thank you")
/// - A complex or hard case (conjuncts, vowel signs, diacritics, bidirectional text)
/// - A long line that exercises line wrapping
class LanguageFixture {
  const LanguageFixture({
    required this.name,
    required this.code,
    required this.simple,
    required this.complex,
    required this.longLine,
    this.languageTag,
    this.isRtl = false,
  });

  final String name;
  final String code;
  final String simple;
  final String complex;
  final String longLine;
  final String? languageTag;
  final bool isRtl;
}

/// Collection of multi-language sample strings used across tests and preview.
class TestLanguages {
  TestLanguages._();

  static const english = LanguageFixture(
    name: 'English',
    code: 'en',
    simple: 'Thank you for your visit',
    complex: 'Burger x2 (w/ extra cheese & jalapeño) \$12.50',
    longLine: 'This is a very long receipt item description that must wrap properly within the printer paper width',
  );

  static const latinAccents = LanguageFixture(
    name: 'Latin with Accents',
    code: 'es_fr',
    simple: 'Café déjà vu & Niño',
    complex: 'Crème brûlée aux fraises fraîches - 8,50 €',
    longLine: 'Por favor revise su cuenta detallada antes de retirarse del establecimiento comercial',
  );

  static const cyrillic = LanguageFixture(
    name: 'Cyrillic',
    code: 'ru',
    simple: 'Спасибо за покупку',
    complex: 'Борщ с пампушками и чесноком 450 ₽',
    longLine: 'Добро пожаловать в наш уютный ресторан традиционной кухни в центре города',
  );

  static const greek = LanguageFixture(
    name: 'Greek',
    code: 'el',
    simple: 'Ευχαριστώ πολύ',
    complex: 'Χωριάτικη σαλάτα με φέτα και ελιές 7,80 €',
    longLine: 'Σας ευχαριστούμε για την προτίμησή σας και ελπίζουμε να σας ξαναδούμε σύντομα',
  );

  static const bangla = LanguageFixture(
    name: 'Bangla',
    code: 'bn',
    languageTag: 'bn',
    simple: 'ধন্যবাদ',
    complex: 'ক্ষুদ্র ও মিষ্টি দই (স্ত্রীর পছন্দ) ৳১২০.০০',
    longLine: 'আমাদের ঐতিহ্যবাহী রেস্তোরাঁয় আসার জন্য আপনাকে আন্তরিক ধন্যবাদ ও স্বাগতম জানাচ্ছি',
  );

  static const hindi = LanguageFixture(
    name: 'Hindi',
    code: 'hi',
    languageTag: 'hi',
    simple: 'धन्यवाद',
    complex: 'स्वादिष्ट मक्खन पनीर मसाला और नान ₹२८०.००',
    longLine: 'हमारे भोजनालय में पधारने के लिए हार्दिक धन्यवाद, हम आपके सुखद भविष्य की कामना करते हैं',
  );

  static const chineseSimplified = LanguageFixture(
    name: 'Chinese Simplified',
    code: 'zh-Hans',
    languageTag: 'zh-Hans',
    simple: '谢谢惠顾',
    complex: '招牌红烧牛肉面加溏心蛋 ¥38.00',
    longLine: '这是一个特别长而且包含各种食材说明的菜品名称需要自动换行打印',
  );

  static const chineseTraditional = LanguageFixture(
    name: 'Chinese Traditional',
    code: 'zh-Hant',
    languageTag: 'zh-Hant',
    simple: '謝謝惠顧',
    complex: '招牌紅燒牛肉麵加溫泉蛋 NT\$180.00',
    longLine: '這是一個非常長且詳細的商品訂購明細資訊必須在打印紙範圍內適當換行',
  );

  static const japanese = LanguageFixture(
    name: 'Japanese',
    code: 'ja',
    languageTag: 'ja',
    simple: 'ありがとうございます',
    complex: '特製チキン南蛮定食（ご飯大盛り） ¥1,180',
    longLine: '当店をご利用いただき誠にありがとうございますまたのお越しを心よりお待ちしております',
  );

  static const korean = LanguageFixture(
    name: 'Korean',
    code: 'ko',
    languageTag: 'ko',
    simple: '감사합니다',
    complex: '매콤달콤 궁중 떡볶이 세트 ₩14,000',
    longLine: '저희 매장을 방문해 주셔서 진심으로 감사드리며 항상 최고의 맛과 서비스로 모시겠습니다',
  );

  static const arabic = LanguageFixture(
    name: 'Arabic',
    code: 'ar',
    languageTag: 'ar',
    isRtl: true,
    simple: 'شكراً لزيارتكم',
    complex: 'وجبة شاورما دجاج مع بطاطس مقلية 25.50 ر.س',
    longLine: 'شكراً جزيلاً لزيارتكم الكريمة لمطعمنا ونتمنى لكم يوماً سعيداً وشهية طيبة دائماً',
  );

  static const thai = LanguageFixture(
    name: 'Thai',
    code: 'th',
    languageTag: 'th',
    simple: 'ขอบคุณครับ',
    complex: 'ต้มยำกุ้งน้ำข้นพิเศษยอดมะพร้าว ฿220.00',
    longLine: 'ขอขอบพระคุณลูกค้าทุกท่านที่ให้เกียรติมาอุดหนุนร้านอาหารของเราในโอกาสนี้',
  );

  /// All supported fixtures in a convenient list.
  static const List<LanguageFixture> all = [
    english,
    latinAccents,
    cyrillic,
    greek,
    bangla,
    hindi,
    chineseSimplified,
    chineseTraditional,
    japanese,
    korean,
    arabic,
    thai,
  ];
}
