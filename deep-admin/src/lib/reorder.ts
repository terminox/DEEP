// Returns a new ordering with the item at `index` moved by `dir` (-1 up, +1 down).
// Returns null when the move would go out of bounds.
export function moveItem(
  ids: string[],
  index: number,
  dir: -1 | 1
): string[] | null {
  const target = index + dir
  if (target < 0 || target >= ids.length) return null
  const next = [...ids]
  const [item] = next.splice(index, 1)
  next.splice(target, 0, item)
  return next
}
