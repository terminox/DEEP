import { site, type Localized } from './document.ts'

// Drawn from what the code actually does: deep-api/prisma/schema.prisma, deep-api/src/routes and the
// app clients. Change the code and this together; Google Play's Data safety form says the same.
export const privacy: Localized = {
  en: {
    title: 'Privacy Policy',
    updated: 'Last updated: 14 November 2026',
    intro: `DEEP is a meditation and calm app run by ${site.operator}. This policy explains what we collect, why, who handles it for us, and the choices you have. It follows Thailand's Personal Data Protection Act (PDPA).`,
    sections: [
      {
        heading: 'What we collect',
        bullets: [
          'Your account: email address, display name, a hashed password (we never store the password itself) and your time zone.',
          'Your onboarding answers, which shape what DEEP suggests.',
          'Your practice: sessions, Global Pause attendance, sounds you listen to, playlists, your Mind Garden, hearts and sunlight, and hearts you send to causes.',
          'Mood and intention notes you choose to record. These are personal, so we use them only to show them back to you and shape your experience.',
          'Peace messages you post in Global Pause, with your display name and country. These are public to other DEEP members.',
          'Your country, taken from your device region, and your approximate location at city level or wider, which may be worked out from your IP address to show where people are pausing around the world. We never use GPS or ask for your precise location.',
          'A random presence ID when you join a Global Pause without an account.',
          'Sign-in records: IP address and device type, kept with your session for security.',
          'Your membership status, if you subscribe to DEEP Premium. Payment details stay with Apple or Google. We never see your card.',
        ],
      },
      {
        heading: 'What we do not do',
        bullets: [
          'We do not sell your personal data.',
          'We do not show ads or use advertising IDs.',
          'We do not track you across other apps or websites.',
          'We do not put third-party analytics in the app.',
        ],
      },
      {
        heading: 'Why we use it, and our legal basis',
        bullets: [
          'To provide DEEP and keep your progress: performance of our contract with you.',
          'To keep DEEP safe, including reviewing reported messages and preventing abuse: our legitimate interests.',
          'To show mood and intention notes back to you: your consent, which you can withdraw by deleting your account.',
          'To meet legal, tax and accounting duties: legal obligation.',
        ],
      },
      {
        heading: 'Who handles data for us',
        paragraphs: ['We share data only with providers that run DEEP on our behalf:'],
        bullets: [
          'Google Cloud hosts our servers and database in Singapore.',
          'RevenueCat manages DEEP Premium subscriptions, using your DEEP account ID (never your email) and purchase records.',
          'Apple and Google process payments and deliver the apps.',
          'Vercel hosts our website.',
          'Unsplash supplies some images, so your device requests them directly, and Unsplash receives your IP address when it does.',
        ],
      },
      {
        heading: 'Transfers outside Thailand',
        paragraphs: [
          'Some providers work outside Thailand, including in Singapore and the United States. We rely on their contractual safeguards to protect your data to the standard the PDPA requires.',
        ],
      },
      {
        heading: 'How long we keep it',
        paragraphs: [
          `We keep your data while your account is open. When you delete your account we remove it from our live systems straight away, including your peace messages, and it leaves our backups within ${site.backupDays} days. Purchase and subscription records are kept after deletion, because we need them for accounting, refunds and disputes.`,
        ],
      },
      {
        heading: 'Your rights',
        paragraphs: [
          `Under the PDPA you can ask to access, correct, move or delete your data, object to or limit how we use it, and withdraw consent. Email ${site.supportEmail} and we will reply within 30 days. You can also complain to Thailand's Personal Data Protection Committee.`,
          'You can delete your account at any time in the app under Settings, or at deeppeace.space/delete-account.',
        ],
      },
      {
        heading: 'Children',
        paragraphs: [
          `DEEP is for people aged 13 and over. Some content is made for adults to enjoy with children, but children under 13 should not have their own account. If you believe a child under 13 has an account, email ${site.supportEmail} and we will delete it.`,
        ],
      },
      {
        heading: 'Security',
        paragraphs: [
          'Data travels over encrypted connections, passwords are hashed, and sign-in tokens are stored in your device\'s secure storage. No system is perfectly secure, so please use a strong, unique password.',
        ],
      },
      {
        heading: 'Changes and contact',
        paragraphs: [
          `If this policy changes in an important way, we will tell you in the app before it takes effect. Questions: ${site.operator}, ${site.address.en}, ${site.supportEmail}.`,
        ],
      },
    ],
  },
  th: {
    title: 'นโยบายความเป็นส่วนตัว',
    updated: 'ปรับปรุงล่าสุด: 14 พฤศจิกายน 2569',
    intro: `DEEP คือแอปการทำสมาธิและความสงบ ดำเนินการโดย ${site.operator} นโยบายนี้อธิบายว่าเราเก็บข้อมูลอะไร เพื่ออะไร ใครดูแลข้อมูลให้เรา และคุณมีทางเลือกอะไรบ้าง โดยเป็นไปตามพระราชบัญญัติคุ้มครองข้อมูลส่วนบุคคล (PDPA)`,
    sections: [
      {
        heading: 'ข้อมูลที่เราเก็บ',
        bullets: [
          'บัญชีของคุณ: อีเมล ชื่อที่แสดง รหัสผ่านที่ผ่านการแฮช (เราไม่เก็บรหัสผ่านจริง) และเขตเวลา',
          'คำตอบตอนเริ่มใช้งาน ซึ่งช่วยกำหนดสิ่งที่ DEEP แนะนำให้คุณ',
          'การฝึกของคุณ: ประวัติการฝึก การเข้าร่วม Global Pause เสียงที่ฟัง เพลย์ลิสต์ Mind Garden หัวใจและแสงแดด และหัวใจที่คุณส่งให้กับเรื่องที่คุณใส่ใจ',
          'บันทึกอารมณ์และความตั้งใจที่คุณเลือกบันทึกเอง ข้อมูลนี้เป็นเรื่องส่วนตัว เราจึงใช้เพื่อแสดงกลับให้คุณและปรับประสบการณ์ของคุณเท่านั้น',
          'ข้อความแห่งสันติที่คุณโพสต์ใน Global Pause พร้อมชื่อที่แสดงและประเทศ ซึ่งสมาชิก DEEP คนอื่นจะมองเห็นได้',
          'ประเทศของคุณจากการตั้งค่าภูมิภาคในอุปกรณ์ และตำแหน่งโดยประมาณระดับเมืองหรือกว้างกว่านั้น ซึ่งอาจคำนวณจากหมายเลข IP เพื่อแสดงว่าผู้คนทั่วโลกกำลังหยุดพักอยู่ที่ไหน เราไม่ใช้ GPS และไม่ขอตำแหน่งที่แม่นยำของคุณ',
          'รหัสสุ่มเมื่อคุณเข้าร่วม Global Pause โดยไม่มีบัญชี',
          'บันทึกการเข้าสู่ระบบ: หมายเลข IP และประเภทอุปกรณ์ เก็บไว้กับเซสชันเพื่อความปลอดภัย',
          'สถานะสมาชิก หากคุณสมัคร DEEP Premium ข้อมูลการชำระเงินอยู่กับ Apple หรือ Google เราไม่เห็นข้อมูลบัตรของคุณ',
        ],
      },
      {
        heading: 'สิ่งที่เราไม่ทำ',
        bullets: [
          'เราไม่ขายข้อมูลส่วนบุคคลของคุณ',
          'เราไม่แสดงโฆษณาและไม่ใช้รหัสโฆษณา',
          'เราไม่ติดตามคุณข้ามแอปหรือเว็บไซต์อื่น',
          'เราไม่ใส่เครื่องมือวิเคราะห์ของบุคคลที่สามไว้ในแอป',
        ],
      },
      {
        heading: 'เหตุผลที่เราใช้ข้อมูล และฐานทางกฎหมาย',
        bullets: [
          'เพื่อให้บริการ DEEP และเก็บความคืบหน้าของคุณ: การปฏิบัติตามสัญญากับคุณ',
          'เพื่อรักษาความปลอดภัยของ DEEP รวมถึงการตรวจสอบข้อความที่ถูกรายงานและการป้องกันการละเมิด: ประโยชน์โดยชอบด้วยกฎหมายของเรา',
          'เพื่อแสดงบันทึกอารมณ์และความตั้งใจกลับให้คุณ: ความยินยอมของคุณ ซึ่งถอนได้โดยลบบัญชี',
          'เพื่อปฏิบัติตามหน้าที่ทางกฎหมาย ภาษี และบัญชี: การปฏิบัติตามกฎหมาย',
        ],
      },
      {
        heading: 'ผู้ที่ดูแลข้อมูลให้เรา',
        paragraphs: ['เราแบ่งปันข้อมูลเฉพาะกับผู้ให้บริการที่ช่วยให้ DEEP ทำงานได้เท่านั้น:'],
        bullets: [
          'Google Cloud ดูแลเซิร์ฟเวอร์และฐานข้อมูลของเราในสิงคโปร์',
          'RevenueCat จัดการการสมัครสมาชิก DEEP Premium โดยใช้รหัสบัญชี DEEP ของคุณ (ไม่ใช่อีเมล) และบันทึกการซื้อ',
          'Apple และ Google ดำเนินการชำระเงินและส่งมอบแอป',
          'Vercel ดูแลเว็บไซต์ของเรา',
          'Unsplash ให้บริการรูปภาพบางส่วน อุปกรณ์ของคุณจึงขอรูปภาพจาก Unsplash โดยตรง และ Unsplash จะได้รับหมายเลข IP ของคุณเมื่อมีการขอรูปภาพ',
        ],
      },
      {
        heading: 'การส่งข้อมูลไปนอกประเทศไทย',
        paragraphs: [
          'ผู้ให้บริการบางรายทำงานนอกประเทศไทย รวมถึงในสิงคโปร์และสหรัฐอเมริกา เราอาศัยมาตรการคุ้มครองตามสัญญาเพื่อดูแลข้อมูลของคุณตามมาตรฐานที่ PDPA กำหนด',
        ],
      },
      {
        heading: 'ระยะเวลาการเก็บข้อมูล',
        paragraphs: [
          `เราเก็บข้อมูลของคุณตราบที่บัญชียังเปิดอยู่ เมื่อคุณลบบัญชี เราจะลบข้อมูลออกจากระบบที่ใช้งานทันที รวมถึงข้อความแห่งสันติของคุณ และข้อมูลจะหมดไปจากข้อมูลสำรองภายใน ${site.backupDays} วัน บันทึกการซื้อและการสมัครสมาชิกจะยังถูกเก็บไว้หลังการลบ เพราะจำเป็นต่อการทำบัญชี การคืนเงิน และการจัดการข้อพิพาท`,
        ],
      },
      {
        heading: 'สิทธิของคุณ',
        paragraphs: [
          `ตาม PDPA คุณสามารถขอเข้าถึง แก้ไข โอนย้าย หรือลบข้อมูลของคุณ คัดค้านหรือจำกัดการใช้ข้อมูล และถอนความยินยอมได้ ส่งอีเมลมาที่ ${site.supportEmail} แล้วเราจะตอบกลับภายใน 30 วัน คุณยังร้องเรียนต่อคณะกรรมการคุ้มครองข้อมูลส่วนบุคคลได้ด้วย`,
          'คุณลบบัญชีได้ทุกเมื่อในแอป ที่หน้าตั้งค่า หรือที่ deeppeace.space/delete-account',
        ],
      },
      {
        heading: 'เด็ก',
        paragraphs: [
          `DEEP มีไว้สำหรับผู้ที่มีอายุ 13 ปีขึ้นไป เนื้อหาบางส่วนทำขึ้นให้ผู้ใหญ่ฟังร่วมกับเด็ก แต่เด็กอายุต่ำกว่า 13 ปีไม่ควรมีบัญชีของตัวเอง หากคุณเชื่อว่ามีเด็กอายุต่ำกว่า 13 ปีมีบัญชี โปรดอีเมลมาที่ ${site.supportEmail} แล้วเราจะลบบัญชีนั้น`,
        ],
      },
      {
        heading: 'ความปลอดภัย',
        paragraphs: [
          'ข้อมูลถูกส่งผ่านการเชื่อมต่อที่เข้ารหัส รหัสผ่านถูกแฮช และโทเคนการเข้าสู่ระบบเก็บไว้ในพื้นที่ปลอดภัยของอุปกรณ์ ไม่มีระบบใดปลอดภัยสมบูรณ์ โปรดใช้รหัสผ่านที่รัดกุมและไม่ซ้ำกับที่อื่น',
        ],
      },
      {
        heading: 'การเปลี่ยนแปลงและการติดต่อ',
        paragraphs: [
          `หากนโยบายนี้เปลี่ยนแปลงในส่วนสำคัญ เราจะแจ้งให้คุณทราบในแอปก่อนมีผล ติดต่อ: ${site.operator}, ${site.address.th}, ${site.supportEmail}`,
        ],
      },
    ],
  },
}
