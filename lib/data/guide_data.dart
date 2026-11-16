import 'package:flutter/material.dart';

import '../models/guide_topic.dart';

// Bundled offline guide content (not mock data; it ships inside the app).
// The Thai text still needs review by a Thai first-aid or DDPM reviewer before release.
class GuideData {
  GuideData._();

  static const List<GuideTopic> topics = [
    GuideTopic(
      title: 'Before a flood: get ready',
      titleTh: 'ก่อนน้ำท่วม: เตรียมตัว',
      icon: Icons.backpack,
      steps: [
        'Pack a go-bag: water, food, torch, radio, power bank, medicines, copies of ID.',
        'Know the nearest shelter and two routes to reach it.',
        'Agree on a family meeting point and save emergency numbers on paper.',
        'Move valuables and electronics to a high place.',
      ],
      stepsTh: [
        'เตรียมถุงยังชีพ: น้ำดื่ม อาหาร ไฟฉาย วิทยุ แบตสำรอง ยาประจำตัว และสำเนาบัตรประชาชน',
        'รู้ว่าศูนย์พักพิงที่ใกล้ที่สุดอยู่ที่ไหน และเดินทางไปได้อย่างน้อยสองเส้นทาง',
        'นัดจุดนัดพบของครอบครัว และจดเบอร์ฉุกเฉินไว้บนกระดาษ',
        'ย้ายของมีค่าและเครื่องใช้ไฟฟ้าขึ้นที่สูง',
      ],
    ),
    GuideTopic(
      title: 'During a flood',
      titleTh: 'ระหว่างน้ำท่วม',
      icon: Icons.flood,
      steps: [
        'Move to higher ground immediately. Do not wait for the water to reach you.',
        'Never walk or drive through flood water: 15 cm can knock you down, 30 cm can float a car.',
        'Turn off electricity at the main switch if it is safe to reach.',
        'Stay away from fallen power lines and fast-moving water.',
      ],
      stepsTh: [
        'ย้ายไปที่สูงทันที อย่ารอให้น้ำมาถึงตัว',
        'อย่าเดินหรือขับรถลุยน้ำท่วม: น้ำสูง 15 ซม. ก็ทำให้ล้มได้ และ 30 ซม. ก็พัดรถลอยได้',
        'ถ้าเข้าถึงได้อย่างปลอดภัย ให้ตัดไฟที่เบรกเกอร์หลัก',
        'อยู่ห่างจากสายไฟที่ขาดและกระแสน้ำเชี่ยว',
      ],
    ),
    GuideTopic(
      title: 'Evacuation checklist',
      titleTh: 'รายการเตรียมอพยพ',
      icon: Icons.directions_run,
      steps: [
        'Leave early, before roads are covered.',
        'Take your go-bag, phone, charger and any medicines.',
        'Lock the door, switch off gas and electricity.',
        'Help children, elderly and disabled neighbours.',
        'Tell someone where you are going and use the SOS button if you are stuck.',
      ],
      stepsTh: [
        'ออกจากบ้านแต่เนิ่น ๆ ก่อนที่ถนนจะถูกน้ำท่วม',
        'หยิบถุงยังชีพ โทรศัพท์ ที่ชาร์จ และยาที่ต้องใช้',
        'ล็อกประตู ปิดแก๊สและไฟฟ้า',
        'ช่วยเด็ก ผู้สูงอายุ และผู้พิการในละแวกบ้าน',
        'บอกคนอื่นว่าคุณจะไปที่ไหน และกดปุ่ม SOS ค้างไว้หากติดอยู่',
      ],
    ),
    GuideTopic(
      title: 'Earthquake safety',
      titleTh: 'แผ่นดินไหว',
      icon: Icons.crisis_alert,
      steps: [
        'Drop to the ground, cover your head and neck, hold on to sturdy furniture.',
        'Stay away from windows, shelves and heavy objects that can fall.',
        'If outside, move to an open area away from buildings and wires.',
        'After shaking stops, expect aftershocks and leave damaged buildings.',
      ],
      stepsTh: [
        'หมอบลง ป้องกันศีรษะและคอ แล้วจับเฟอร์นิเจอร์ที่แข็งแรงไว้',
        'อยู่ห่างจากหน้าต่าง ชั้นวางของ และของหนักที่อาจหล่นทับ',
        'ถ้าอยู่นอกอาคาร ให้ไปที่โล่งห่างจากอาคารและสายไฟ',
        'เมื่อหยุดสั่นแล้ว ให้ระวังอาฟเตอร์ช็อก และออกจากอาคารที่เสียหาย',
      ],
    ),
    GuideTopic(
      title: 'Severe bleeding',
      titleTh: 'เลือดออกมาก',
      icon: Icons.healing,
      steps: [
        'Press firmly on the wound with a clean cloth. Do not remove it if soaked; add more on top.',
        'Keep pressing for at least 10 minutes without checking.',
        'If possible, raise the injured limb above the heart.',
        'Call the local emergency number if bleeding does not stop.',
      ],
      stepsTh: [
        'กดแผลให้แน่นด้วยผ้าสะอาด ถ้าผ้าชุ่มเลือดไม่ต้องเอาออก ให้วางผ้าทับเพิ่ม',
        'กดต่อเนื่องอย่างน้อย 10 นาที โดยไม่เปิดดู',
        'ถ้าทำได้ ให้ยกแขนหรือขาที่บาดเจ็บให้สูงกว่าหัวใจ',
        'โทรเบอร์ฉุกเฉินถ้าเลือดไม่หยุด',
      ],
    ),
    GuideTopic(
      title: 'CPR basics (adult)',
      titleTh: 'CPR ผู้ใหญ่ (ปั๊มหัวใจ)',
      icon: Icons.favorite,
      steps: [
        'Check if the person responds and breathes. If not, call for help.',
        'Push hard and fast in the centre of the chest: about 100 to 120 times per minute, 5 to 6 cm deep.',
        'If you are trained, give 2 rescue breaths after every 30 compressions.',
        'Continue until help arrives or the person starts to breathe.',
      ],
      stepsTh: [
        'ตรวจว่าผู้ป่วยตอบสนองและหายใจหรือไม่ ถ้าไม่ ให้ขอความช่วยเหลือทันที',
        'กดกลางหน้าอกให้แรงและเร็ว ประมาณ 100–120 ครั้งต่อนาที ลึก 5–6 ซม.',
        'ถ้าผ่านการฝึกมา ให้เป่าปาก 2 ครั้งหลังกดทุก 30 ครั้ง',
        'ทำต่อจนกว่าความช่วยเหลือจะมาถึงหรือผู้ป่วยเริ่มหายใจ',
      ],
    ),
    GuideTopic(
      title: 'Burns',
      titleTh: 'แผลไหม้และน้ำร้อนลวก',
      icon: Icons.local_fire_department,
      steps: [
        'Cool the burn under cool running water for 20 minutes.',
        'Remove rings and tight clothing near the burn before it swells.',
        'Cover loosely with a clean non-fluffy cover such as cling film.',
        'Do not use ice, butter or toothpaste. Seek medical help for large or deep burns.',
      ],
      stepsTh: [
        'ล้างแผลด้วยน้ำสะอาดเย็นที่ไหลผ่านนาน 20 นาที',
        'ถอดแหวนและเสื้อผ้าที่รัดบริเวณแผลก่อนที่จะบวม',
        'คลุมหลวม ๆ ด้วยผ้าสะอาดที่ไม่เป็นขุย เช่น พลาสติกแรป',
        'ห้ามใช้น้ำแข็ง เนย หรือยาสีฟัน ถ้าแผลใหญ่หรือลึกให้ไปพบแพทย์',
      ],
    ),
    GuideTopic(
      title: 'Broken bones',
      titleTh: 'กระดูกหัก',
      icon: Icons.personal_injury,
      steps: [
        'Keep the person still and the injured part supported in the position found.',
        'Do not try to straighten the bone.',
        'Support the limb with padding or a splint, tied above and below the break.',
        'Get medical help; treat for shock by keeping the person warm.',
      ],
      stepsTh: [
        'ให้ผู้ป่วยอยู่นิ่ง ๆ และประคองส่วนที่บาดเจ็บไว้ในท่าที่พบ',
        'อย่าพยายามดัดกระดูกให้ตรง',
        'ดามแขนขาด้วยวัสดุรองและไม้ดาม มัดเหนือและใต้จุดที่หัก',
        'ไปพบแพทย์ และห่มผ้าให้ผู้ป่วยอบอุ่นเพื่อป้องกันอาการช็อก',
      ],
    ),
  ];
}
