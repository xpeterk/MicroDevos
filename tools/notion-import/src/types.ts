export type ScriptureQuote = { reference: string; text: string };

export type CardMeta = {
  title?: string;
  status?: string | null;
  editionDate?: string | null;
  stars?: number | null;
  sourceUrl?: string | null;
  notionPageId?: string | null;
};

export type ParsedDevo = {
  title: string;
  hook: string;
  body_md: string;
  takeaway: string;
  verse_text: string;
  verse_ref: string;
  scriptures: ScriptureQuote[];
  source_url: string | null;
  edition_date: string | null;
  edition_url: string | null;
  position: number;
  stars: number | null;
  status: string | null;
  notion_page_id: string | null;
};

export type ImportDecision =
  | { shouldImport: true }
  | { shouldImport: false; reason: string };

export type NotionRichText = {
  plain_text?: string;
  href?: string | null;
  annotations?: {
    bold?: boolean;
    italic?: boolean;
    code?: boolean;
    underline?: boolean;
    strikethrough?: boolean;
  };
};

export type NotionBlock = {
  id?: string;
  type: string;
  has_children?: boolean;
  children?: NotionBlock[];
  [key: string]: unknown;
};
