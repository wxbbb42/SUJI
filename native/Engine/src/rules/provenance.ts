/** Provenance for deterministic rule output; not model-authored references. */
export interface RuleSource {
  id: string;
  version: string;
  title: string;
  editionStatus: 'electronic-transcription-not-print-collated' | 'pinned-engineering-reference' | 'product-policy';
  scope: string;
  references: { url: string; locator: string; sha256?: string; quote?: string }[];
  limitations: string[];
}
