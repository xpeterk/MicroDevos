export type RichRun = {
  text: string;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strike?: boolean;
  code?: boolean;
  link?: string;
};

export type ContentBlock = {
  type: "paragraph" | "heading" | "bullet" | "number" | "quote" | "callout" | "divider";
  runs?: RichRun[];
  level?: number;
  index?: number;
};

export function encodeContent(markdown: string): string {
  return JSON.stringify({ v: 1, blocks: markdownToBlocks(markdown) });
}

export function markdownToBlocks(markdown: string): ContentBlock[] {
  const lines = markdown.replaceAll("\r\n", "\n").split("\n");
  const blocks: ContentBlock[] = [];
  let index = 0;
  let number = 0;
  while (index < lines.length) {
    const trimmed = lines[index].trim();
    if (!trimmed) {
      index += 1;
      number = 0;
      continue;
    }
    if (trimmed === "---") {
      blocks.push({ type: "divider" });
      index += 1;
      continue;
    }
    if (trimmed === ":::callout") {
      const body: string[] = [];
      index += 1;
      while (index < lines.length && lines[index].trim() !== ":::") {
        body.push(lines[index]);
        index += 1;
      }
      if (index < lines.length) index += 1;
      blocks.push({ type: "callout", runs: parseInlines(body.join(" ").trim()) });
      continue;
    }
    const heading = /^(#{1,3})\s+(.*)$/.exec(trimmed);
    if (heading) {
      blocks.push({
        type: "heading",
        level: heading[1].length,
        runs: parseInlines(heading[2].trim()),
      });
      index += 1;
      number = 0;
      continue;
    }
    if (trimmed.startsWith("> ")) {
      const quote = [trimmed.slice(2)];
      index += 1;
      while (index < lines.length && lines[index].trim().startsWith("> ")) {
        quote.push(lines[index].trim().slice(2));
        index += 1;
      }
      blocks.push({ type: "quote", runs: parseInlines(quote.join(" ")) });
      number = 0;
      continue;
    }
    const bullet = /^[-*]\s+(.*)$/.exec(trimmed);
    if (bullet) {
      blocks.push({ type: "bullet", runs: parseInlines(bullet[1].trim()) });
      index += 1;
      number = 0;
      continue;
    }
    const numbered = /^(\d+)\.\s+(.*)$/.exec(trimmed);
    if (numbered) {
      number += 1;
      blocks.push({
        type: "number",
        index: number,
        runs: parseInlines(numbered[2].trim()),
      });
      index += 1;
      continue;
    }
    const paragraph = [trimmed];
    index += 1;
    while (index < lines.length && !isBlockStart(lines[index])) {
      const next = lines[index].trim();
      if (!next) break;
      paragraph.push(next);
      index += 1;
    }
    blocks.push({ type: "paragraph", runs: parseInlines(paragraph.join(" ")) });
    number = 0;
  }
  return blocks;
}

function isBlockStart(line: string): boolean {
  const trimmed = line.trim();
  if (!trimmed) return true;
  if (trimmed === "---" || trimmed === ":::callout" || trimmed === ":::") return true;
  if (trimmed.startsWith("> ")) return true;
  if (/^#{1,3}\s+/.test(trimmed)) return true;
  if (/^[-*]\s+/.test(trimmed)) return true;
  if (/^\d+\.\s+/.test(trimmed)) return true;
  return false;
}

export function parseInlines(input: string): RichRun[] {
  const runs: RichRun[] = [];
  const add = (text: string, flags: Omit<RichRun, "text"> = {}) => {
    if (!text) return;
    const run: RichRun = { text };
    if (flags.bold) run.bold = true;
    if (flags.italic) run.italic = true;
    if (flags.underline) run.underline = true;
    if (flags.strike) run.strike = true;
    if (flags.code) run.code = true;
    if (flags.link) run.link = flags.link;
    runs.push(run);
  };
  let index = 0;
  let buffer = "";
  const flush = () => {
    add(buffer);
    buffer = "";
  };
  while (index < input.length) {
    const rest = input.slice(index);
    if (rest.startsWith("**")) {
      const end = input.indexOf("**", index + 2);
      if (end > index) {
        flush();
        for (const run of parseInlines(input.slice(index + 2, end))) {
          runs.push({ ...run, bold: true });
        }
        index = end + 2;
        continue;
      }
    }
    if (rest.startsWith("++")) {
      const end = input.indexOf("++", index + 2);
      if (end > index) {
        flush();
        for (const run of parseInlines(input.slice(index + 2, end))) {
          runs.push({ ...run, underline: true });
        }
        index = end + 2;
        continue;
      }
    }
    if (rest.startsWith("~~")) {
      const end = input.indexOf("~~", index + 2);
      if (end > index) {
        flush();
        for (const run of parseInlines(input.slice(index + 2, end))) {
          runs.push({ ...run, strike: true });
        }
        index = end + 2;
        continue;
      }
    }
    if (rest.startsWith("`")) {
      const end = input.indexOf("`", index + 1);
      if (end > index) {
        flush();
        add(input.slice(index + 1, end), { code: true });
        index = end + 1;
        continue;
      }
    }
    if (rest.startsWith("[")) {
      const close = input.indexOf("](", index + 1);
      if (close > index) {
        const urlEnd = input.indexOf(")", close + 2);
        if (urlEnd > close) {
          flush();
          const label = input.slice(index + 1, close);
          const url = input.slice(close + 2, urlEnd);
          for (const run of parseInlines(label)) {
            runs.push({ ...run, underline: true, link: url });
          }
          index = urlEnd + 1;
          continue;
        }
      }
    }
    if (rest.startsWith("*") && !rest.startsWith("**")) {
      const end = input.indexOf("*", index + 1);
      if (end > index) {
        flush();
        for (const run of parseInlines(input.slice(index + 1, end))) {
          runs.push({ ...run, italic: true });
        }
        index = end + 1;
        continue;
      }
    }
    buffer += input[index];
    index += 1;
  }
  flush();
  return runs;
}
