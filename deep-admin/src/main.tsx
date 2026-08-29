import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import {
  MutationCache,
  QueryClient,
  QueryClientProvider,
} from '@tanstack/react-query'
import './index.css'
import App from './App.tsx'
import { PENDING_KEY } from './lib/pending'

// Every content mutation in this app now stages a change instead of applying
// it, so every successful mutation moves the pending count. Refreshing it here
// rather than in each page's onSuccess means a new page cannot forget to, and
// the nav badge can never quietly under-report what is waiting to be published.
const mutationCache = new MutationCache({
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: PENDING_KEY })
  },
})

const queryClient = new QueryClient({
  mutationCache,
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
})

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  </StrictMode>
)
