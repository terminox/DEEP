import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '../tokens.css'
import '../landing/components/shared.css'
import { deleteAccount } from './deleteAccount.ts'
import type { Localized } from './document.ts'
import LegalPage from './LegalPage.tsx'
import { privacy } from './privacy.ts'
import { terms } from './terms.ts'

const documents: Record<string, Localized> = { privacy, terms, deleteAccount }

const root = document.getElementById('root')!

createRoot(root).render(
  <StrictMode>
    <LegalPage content={documents[root.dataset.document ?? 'privacy']} />
  </StrictMode>,
)
