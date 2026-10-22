export const parseView = (value: string): JSX.Element => <span>{value}</span>

export function countViews(): number {
  return 0
}

export interface ViewMetadata {
  score: number
}
