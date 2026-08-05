// A small hand-rolled CSV parser (not a dependency) so quoting/escaping is
// handled explicitly and predictably for GTFS files, which can have quoted
// fields containing commas (e.g. long stop names/descriptions). Mirrors the
// Dart implementation in lib/data/providers/gtfs_schedule_parser.dart —
// keep the two in sync if either needs a fix.
export function parseCsv(input: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let quoted = false;

  for (let index = 0; index < input.length; index += 1) {
    const char = input[index];
    if (char === '"') {
      if (quoted && input[index + 1] === '"') {
        field += '"';
        index += 1;
      } else {
        quoted = !quoted;
      }
    } else if (char === "," && !quoted) {
      row.push(field);
      field = "";
    } else if ((char === "\n" || char === "\r") && !quoted) {
      if (char === "\r" && input[index + 1] === "\n") {
        index += 1;
      }
      row.push(field);
      field = "";
      if (row.some((value) => value.length > 0)) {
        rows.push(row);
      }
      row = [];
    } else {
      field += char;
    }
  }

  if (quoted) {
    throw new Error("CSV GTFS memiliki kutip yang tidak ditutup.");
  }
  row.push(field);
  if (row.some((value) => value.length > 0)) {
    rows.push(row);
  }
  return rows;
}

/** Rows keyed by header name — required columns are validated up front. */
export function mapRows(
  csvText: string,
  requiredColumns: string[]
): Record<string, string>[] {
  const rows = parseCsv(csvText);
  if (rows.length === 0) {
    return [];
  }
  const header = rows[0];
  const missing = requiredColumns.filter((column) => !header.includes(column));
  if (missing.length > 0) {
    throw new Error(`Kolom GTFS wajib hilang: ${missing.join(", ")}.`);
  }

  const results: Record<string, string>[] = [];
  for (let i = 1; i < rows.length; i += 1) {
    const row = rows[i];
    if (row.length < header.length) {
      continue;
    }
    const byColumn: Record<string, string> = {};
    for (let c = 0; c < header.length; c += 1) {
      byColumn[header[c]] = row[c];
    }
    results.push(byColumn);
  }
  return results;
}
