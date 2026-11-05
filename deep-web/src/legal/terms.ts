import { site, type Localized } from './document.ts'

// Hearts are never money, and nothing here says "donate" / บริจาค: the client's legal ask, under
// Thailand's Fundraising Act. Keep the send-and-vote language in any edit.
export const terms: Localized = {
  en: {
    title: 'Terms of Service',
    updated: 'Last updated: [date of publication]',
    intro: `These terms are an agreement between you and ${site.operator}, who runs DEEP. By creating an account or using DEEP, you accept them.`,
    sections: [
      {
        heading: 'DEEP is not medical care',
        paragraphs: [
          'DEEP offers meditation, breathing and sound for everyday calm. It is not medical or mental health care, and it does not diagnose, treat or prevent any condition. If you are unwell or in crisis, please contact a qualified professional or your local emergency service.',
        ],
      },
      {
        heading: 'Your account',
        paragraphs: [
          'You must be at least 13 to have an account. If you are under the age of majority where you live, you need a parent or guardian\'s permission. Keep your password safe. You are responsible for what happens under your account.',
        ],
      },
      {
        heading: 'What you share',
        paragraphs: [
          'Peace messages are seen by other members. You keep ownership of what you write, and you give us permission to show it in DEEP. You agree not to post anything that is hateful, harassing, sexual, violent, illegal, misleading or that shares someone\'s private information.',
          'You can report a message or block its author in the app. We may remove messages and suspend accounts that break these rules, with or without notice.',
        ],
      },
      {
        heading: 'Hearts and sunlight',
        paragraphs: [
          'Hearts and sunlight are part of the experience in DEEP. They have no cash value, cannot be bought, sold or exchanged, and are not money. Sending hearts to a cause is a vote for the causes you would like DEEP to support. It does not move money, and it is not a promise of any amount going to any cause.',
        ],
      },
      {
        heading: 'DEEP Premium',
        bullets: [
          'DEEP Premium is an optional subscription, where available on your platform. Price and billing period are shown before you confirm.',
          'A subscription renews automatically until you cancel. You are charged through your Apple or Google account within 24 hours before each period ends.',
          'A free trial, if offered, turns into a paid subscription when it ends unless you cancel at least 24 hours before.',
          'Cancel at any time in your Apple or Google account settings. You keep access until the paid period ends. Deleting your DEEP account does not cancel a subscription.',
          'Refunds are handled by Apple or Google under their own rules. This does not limit any right you have under consumer law.',
        ],
      },
      {
        heading: 'Our content',
        paragraphs: [
          'Sessions, sounds, images and the DEEP name belong to us or to those who license them to us. You may use them in DEEP for your own personal use. Please do not copy, resell or redistribute them.',
        ],
      },
      {
        heading: 'Fair use',
        paragraphs: [
          'Please do not break, overload, reverse engineer or get around any part of DEEP, or use it to harm others.',
        ],
      },
      {
        heading: 'Changes to DEEP',
        paragraphs: [
          'DEEP will change over time. We may add, change or remove features and content. If we plan to stop DEEP altogether we will give reasonable notice.',
        ],
      },
      {
        heading: 'Ending your use',
        paragraphs: [
          'You can stop using DEEP and delete your account at any time. We may suspend or close an account that seriously or repeatedly breaks these terms.',
        ],
      },
      {
        heading: 'Limits on our responsibility',
        paragraphs: [
          'We work hard on DEEP, but it is provided as it is, without a promise that it will always be available or error-free. To the extent the law allows, we are not liable for indirect or consequential loss. Nothing here limits any liability that the law does not allow us to limit.',
        ],
      },
      {
        heading: 'Law and changes to these terms',
        paragraphs: [
          `These terms are governed by the laws of Thailand. If they change in an important way, we will tell you in the app before the change takes effect. Questions: ${site.operator}, ${site.address}, ${site.supportEmail}.`,
        ],
      },
    ],
  },
  th: {
    title: 'ข้อกำหนดการใช้งาน',
    updated: 'ปรับปรุงล่าสุด: [วันที่เผยแพร่]',
    intro: `ข้อกำหนดนี้เป็นข้อตกลงระหว่างคุณกับ ${site.operator} ผู้ดำเนินการ DEEP เมื่อคุณสร้างบัญชีหรือใช้ DEEP ถือว่าคุณยอมรับข้อกำหนดนี้`,
    sections: [
      {
        heading: 'DEEP ไม่ใช่การรักษาทางการแพทย์',
        paragraphs: [
          'DEEP นำเสนอการทำสมาธิ การหายใจ และเสียงเพื่อความสงบในชีวิตประจำวัน ไม่ใช่บริการทางการแพทย์หรือสุขภาพจิต และไม่ได้วินิจฉัย รักษา หรือป้องกันโรคใด ๆ หากคุณไม่สบายหรืออยู่ในภาวะวิกฤต โปรดติดต่อผู้เชี่ยวชาญหรือหน่วยฉุกเฉินในพื้นที่ของคุณ',
        ],
      },
      {
        heading: 'บัญชีของคุณ',
        paragraphs: [
          'คุณต้องมีอายุอย่างน้อย 13 ปีจึงจะมีบัญชีได้ หากคุณยังไม่บรรลุนิติภาวะตามกฎหมายที่ใช้บังคับ คุณต้องได้รับอนุญาตจากผู้ปกครอง โปรดเก็บรหัสผ่านให้ปลอดภัย คุณเป็นผู้รับผิดชอบสิ่งที่เกิดขึ้นภายใต้บัญชีของคุณ',
        ],
      },
      {
        heading: 'สิ่งที่คุณแบ่งปัน',
        paragraphs: [
          'สมาชิกคนอื่นจะมองเห็นข้อความแห่งสันติ คุณยังคงเป็นเจ้าของสิ่งที่คุณเขียน และอนุญาตให้เราแสดงข้อความนั้นใน DEEP คุณตกลงว่าจะไม่โพสต์เนื้อหาที่แสดงความเกลียดชัง คุกคาม ทางเพศ รุนแรง ผิดกฎหมาย ทำให้เข้าใจผิด หรือเปิดเผยข้อมูลส่วนตัวของผู้อื่น',
          'คุณสามารถรายงานข้อความหรือบล็อกผู้เขียนได้ในแอป เราอาจลบข้อความและระงับบัญชีที่ฝ่าฝืนกติกานี้ โดยจะแจ้งล่วงหน้าหรือไม่ก็ได้',
        ],
      },
      {
        heading: 'หัวใจและแสงแดด',
        paragraphs: [
          'หัวใจและแสงแดดเป็นส่วนหนึ่งของประสบการณ์ใน DEEP ไม่มีมูลค่าเป็นเงิน ไม่สามารถซื้อ ขาย หรือแลกเปลี่ยนได้ และไม่ใช่เงิน การส่งหัวใจให้กับเรื่องที่คุณใส่ใจคือการโหวตว่าคุณอยากให้ DEEP สนับสนุนเรื่องใด ไม่ใช่การโอนเงิน และไม่ใช่คำสัญญาว่าจะมีจำนวนเงินใดไปถึงเรื่องนั้น',
        ],
      },
      {
        heading: 'DEEP Premium',
        bullets: [
          'DEEP Premium เป็นการสมัครสมาชิกที่เลือกได้ เมื่อเปิดให้บริการบนแพลตฟอร์มของคุณ ราคาและรอบการเรียกเก็บเงินจะแสดงก่อนที่คุณจะยืนยัน',
          'การสมัครสมาชิกจะต่ออายุอัตโนมัติจนกว่าคุณจะยกเลิก โดยเรียกเก็บผ่านบัญชี Apple หรือ Google ของคุณภายใน 24 ชั่วโมงก่อนสิ้นสุดแต่ละรอบ',
          'ช่วงทดลองใช้ฟรี หากมี จะเปลี่ยนเป็นการสมัครแบบชำระเงินเมื่อสิ้นสุด เว้นแต่คุณจะยกเลิกอย่างน้อย 24 ชั่วโมงก่อนหน้า',
          'ยกเลิกได้ทุกเมื่อในการตั้งค่าบัญชี Apple หรือ Google ของคุณ คุณยังใช้งานได้จนสิ้นสุดรอบที่ชำระแล้ว การลบบัญชี DEEP ไม่ได้ยกเลิกการสมัครสมาชิก',
          'การคืนเงินเป็นไปตามกฎของ Apple หรือ Google ทั้งนี้ไม่จำกัดสิทธิของคุณตามกฎหมายคุ้มครองผู้บริโภค',
        ],
      },
      {
        heading: 'เนื้อหาของเรา',
        paragraphs: [
          'เซสชัน เสียง รูปภาพ และชื่อ DEEP เป็นของเราหรือของผู้ที่อนุญาตให้เราใช้ คุณใช้สิ่งเหล่านี้ใน DEEP เพื่อการใช้งานส่วนตัวได้ โปรดอย่าคัดลอก ขายต่อ หรือเผยแพร่ซ้ำ',
        ],
      },
      {
        heading: 'การใช้งานอย่างเหมาะสม',
        paragraphs: ['โปรดอย่าทำให้ส่วนใดของ DEEP เสียหาย ทำงานหนักเกินไป ทำวิศวกรรมย้อนกลับ หรือหลบเลี่ยงการทำงาน และอย่าใช้เพื่อทำร้ายผู้อื่น'],
      },
      {
        heading: 'การเปลี่ยนแปลง DEEP',
        paragraphs: ['DEEP จะเปลี่ยนแปลงไปตามเวลา เราอาจเพิ่ม เปลี่ยน หรือนำคุณสมบัติและเนื้อหาออก หากเราวางแผนจะยุติ DEEP ทั้งหมด เราจะแจ้งล่วงหน้าตามสมควร'],
      },
      {
        heading: 'การสิ้นสุดการใช้งาน',
        paragraphs: ['คุณหยุดใช้ DEEP และลบบัญชีได้ทุกเมื่อ เราอาจระงับหรือปิดบัญชีที่ฝ่าฝืนข้อกำหนดนี้อย่างร้ายแรงหรือซ้ำ ๆ'],
      },
      {
        heading: 'ขอบเขตความรับผิดของเรา',
        paragraphs: [
          'เราตั้งใจพัฒนา DEEP อย่างเต็มที่ แต่ให้บริการตามสภาพที่เป็นอยู่ โดยไม่รับประกันว่าจะใช้งานได้ตลอดเวลาหรือไม่มีข้อผิดพลาด เท่าที่กฎหมายอนุญาต เราไม่รับผิดต่อความเสียหายทางอ้อมหรือความเสียหายสืบเนื่อง ข้อความนี้ไม่จำกัดความรับผิดที่กฎหมายไม่อนุญาตให้จำกัด',
        ],
      },
      {
        heading: 'กฎหมายที่ใช้บังคับและการเปลี่ยนแปลงข้อกำหนด',
        paragraphs: [
          `ข้อกำหนดนี้อยู่ภายใต้กฎหมายไทย หากมีการเปลี่ยนแปลงในส่วนสำคัญ เราจะแจ้งให้คุณทราบในแอปก่อนมีผล ติดต่อ: ${site.operator}, ${site.address}, ${site.supportEmail}`,
        ],
      },
    ],
  },
}
