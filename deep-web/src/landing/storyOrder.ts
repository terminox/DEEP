// The nav's stops in story order: Global Pause, then the four chapters of Inside DEEP (their ids
// live in InsideDeep.tsx). The nav and the page both read these ids, so they never disagree.
export const sections = [
  { id: 'global-pause', label: 'Global Pause' },
  { id: 'deep-session', label: 'DEEP Session' },
  { id: 'mind-garden', label: 'Mind Garden' },
  { id: 'compassion', label: 'Compassion' },
  { id: 'deep-sound', label: 'DEEP Sound' },
] as const
