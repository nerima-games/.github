export function parseName(value: string): UserName {
  return makeUserName(value)
}

export function countUsers(): number {
  return 0
}

export interface UserMetadata {
  score: number
}
