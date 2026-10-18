import type { NotionBlock, NotionRichText } from "./types.js";

export function richTextToMarkdown(items: NotionRichText[] = []): string {
  return items
    .map((item) => {
      let text = item.plain_text ?? "";
      if (item.annotations?.code) text = `\`${text}\``;
      if (item.annotations?.bold) text = `**${text}**`;
      if (item.annotations?.italic) text = `*${text}*`;
      if (item.href) text = `[${text}](${item.href})`;
      return text;
    })
    .join("");
}

function blockText(block: NotionBlock): string {
  const data = block[block.type];
  if (!data || typeof data !== "object") return "";
  const rich = (data as { rich_text?: NotionRichText[] }).rich_text;
  return richTextToMarkdown(rich);
}

/** Canonical markdown the devotion parser expects. */
export function blocksToMarkdown(blocks: NotionBlock[]): string {
  const lines: string[] = [];
  for (const block of blocks) {
    const text = blockText(block);
    switch (block.type) {
      case "heading_1":
        lines.push(`# ${text}`, "");
        break;
      case "heading_2":
        lines.push(`## ${text}`, "");
        break;
      case "heading_3":
        lines.push(`### ${text}`, "");
        break;
      case "paragraph":
        lines.push(text, "");
        break;
      case "divider":
        lines.push("---", "");
        break;
      case "quote":
        lines.push(`> ${text}`);
        break;
      case "bulleted_list_item":
        lines.push(`- ${text}`);
        break;
      case "numbered_list_item":
        lines.push(`1. ${text}`);
        break;
      case "callout": {
        const inner = [text];
        if (block.children?.length) inner.push(blocksToMarkdown(block.children));
        lines.push(":::callout", inner.filter(Boolean).join("\n"), ":::", "");
        break;
      }
      default:
        if (block.children?.length) lines.push(blocksToMarkdown(block.children), "");
        break;
    }
  }
  return lines.join("\n").replace(/\n{3,}/g, "\n\n").trim();
}
