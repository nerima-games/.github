// Conformance exception: This adapter converts the provider's plain-string ID into a branded ID.
// ast-grep-ignore: no-raw-exported-function-parameter
export function fromProvider(raw: string): ProviderId {
  return makeProviderId(raw)
}
