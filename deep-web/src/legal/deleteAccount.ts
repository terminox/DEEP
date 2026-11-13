import { site, type Localized } from './document.ts'

// The page Google Play links as DEEP's account deletion URL. It must work for someone who no longer
// has the app, and must say exactly what goes and what stays.
export const deleteAccount: Localized = {
  en: {
    title: 'Delete your DEEP account',
    updated: 'Last updated: [date of publication]',
    intro: 'You can delete your DEEP account and its data at any time, with or without the app.',
    sections: [
      {
        heading: 'In the app',
        bullets: [
          'Open DEEP and go to the You tab.',
          'Open Settings.',
          'Choose Delete account, then confirm.',
        ],
      },
      {
        heading: 'Without the app',
        paragraphs: [
          `Email ${site.supportEmail} from the address on your account, with the subject "Delete my account". We will confirm the request is yours, then delete the account within 30 days.`,
        ],
      },
      {
        heading: 'What is deleted',
        bullets: [
          'Your account: email, display name, password and sessions.',
          'Your onboarding answers, practice history, mood and intention notes, playlists, Mind Garden, hearts and sunlight.',
          'Your peace messages.',
        ],
      },
      {
        heading: 'What is kept, and for how long',
        bullets: [
          `Copies in backups, which expire within ${site.backupDays} days.`,
          'Purchase and subscription records, kept for accounting, refunds and disputes for as long as the law requires.',
        ],
      },
      {
        heading: 'If you subscribe to DEEP Premium',
        paragraphs: [
          'Deleting your account does not cancel a subscription. Cancel it first in your Apple or Google account settings, or you may still be charged.',
        ],
      },
    ],
  },
  th: {
    title: 'ลบบัญชี DEEP ของคุณ',
    updated: 'ปรับปรุงล่าสุด: [วันที่เผยแพร่]',
    intro: 'คุณลบบัญชี DEEP และข้อมูลได้ทุกเมื่อ ไม่ว่าจะมีแอปอยู่หรือไม่',
    sections: [
      {
        heading: 'ลบในแอป',
        bullets: ['เปิด DEEP แล้วไปที่แท็บ ฉัน', 'เปิดหน้าการตั้งค่า', 'เลือก ลบบัญชี แล้วยืนยัน'],
      },
      {
        heading: 'ลบโดยไม่ใช้แอป',
        paragraphs: [
          `ส่งอีเมลถึง ${site.supportEmail} จากอีเมลที่ใช้กับบัญชี โดยใช้หัวข้อ "ลบบัญชีของฉัน" เราจะยืนยันว่าเป็นคำขอของคุณ แล้วลบบัญชีภายใน 30 วัน`,
        ],
      },
      {
        heading: 'ข้อมูลที่จะถูกลบ',
        bullets: [
          'บัญชีของคุณ: อีเมล ชื่อที่แสดง รหัสผ่าน และเซสชัน',
          'คำตอบตอนเริ่มใช้งาน ประวัติการฝึก บันทึกอารมณ์และความตั้งใจ เพลย์ลิสต์ Mind Garden หัวใจและแสงแดด',
          'ข้อความแห่งสันติของคุณ',
        ],
      },
      {
        heading: 'ข้อมูลที่ยังเก็บไว้ และระยะเวลา',
        bullets: [
          `สำเนาในข้อมูลสำรอง ซึ่งจะหมดอายุภายใน ${site.backupDays} วัน`,
          'บันทึกการซื้อและการสมัครสมาชิก เก็บไว้เพื่อการทำบัญชี การคืนเงิน และข้อพิพาท ตามระยะเวลาที่กฎหมายกำหนด',
        ],
      },
      {
        heading: 'หากคุณสมัคร DEEP Premium',
        paragraphs: ['การลบบัญชีไม่ได้ยกเลิกการสมัครสมาชิก โปรดยกเลิกในการตั้งค่าบัญชี Apple หรือ Google ก่อน มิฉะนั้นอาจยังถูกเรียกเก็บเงิน'],
      },
    ],
  },
}
