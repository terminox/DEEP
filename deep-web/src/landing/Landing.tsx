// The DEEP landing page. The story runs in a fixed order: pause with the world, be with yourself,
// grow alongside it, turn it outward, then somewhere to land.
import Nav from './sections/Nav.tsx'
import Hero from './sections/Hero.tsx'
import GlobalPause from './sections/GlobalPause.tsx'
import DeepSession from './sections/DeepSession.tsx'
import MindGarden from './sections/MindGarden.tsx'
import CompassionPortfolio from './sections/CompassionPortfolio.tsx'
import DeepSound from './sections/DeepSound.tsx'
import Download from './sections/Download.tsx'
import Footer from './sections/Footer.tsx'

export default function Landing() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <GlobalPause />
        <DeepSession />
        <MindGarden />
        <CompassionPortfolio />
        <DeepSound />
        <Download />
      </main>
      <Footer />
    </>
  )
}
