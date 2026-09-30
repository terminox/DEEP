// The DEEP landing page. The story runs in a fixed order: pause with the world, then what stays
// with you inside the app (a breath, a garden, hearts given, sound). The closing Download section
// (sections/Download.tsx) is off the page until DEEP is on the stores.
import Nav from './sections/Nav.tsx'
import Hero from './sections/Hero.tsx'
import GlobalPause from './sections/GlobalPause.tsx'
import InsideDeep from './sections/InsideDeep.tsx'
import Footer from './sections/Footer.tsx'

export default function Landing() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <GlobalPause />
        <InsideDeep />
      </main>
      <Footer />
    </>
  )
}
